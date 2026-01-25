import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fruit_care_pro/exceptions/advertisement_exception.dart';
import 'package:fruit_care_pro/screens/advertisements_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:fruit_care_pro/models/advertisement.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/services/documents_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:fruit_care_pro/shared_ui_components.dart';

class CreateUpdateAdvertisementScreen extends StatefulWidget {
  final AdvertisementCategory category;
  final Advertisement? advertisement; // null = create, non-null = edit

  const CreateUpdateAdvertisementScreen({
    super.key,
    required this.category,
    this.advertisement,
  });

  @override
  State<CreateUpdateAdvertisementScreen> createState() =>
      _CreateUpdateAdvertisementScreenState();
}

class _CreateUpdateAdvertisementScreenState
    extends State<CreateUpdateAdvertisementScreen> {
  // Services
  late final AdvertisementService _advertisementService;

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _nameFocusNode = FocusNode();

  // Image state
  File? _localProfileImage;
  String? _thumbUrl;
  String? _imageUrl;
  String? _thumbPath;
  String? _imagePath;
  String? _localImagePath;

  // Loading state
  bool _isLoading = false;
  bool _isUploadingImage = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Computed properties
  bool get _isEdit => widget.advertisement != null;
  String get _title => _isEdit ? 'Izmena reklame' : 'Dodavanje nove reklame';
  String get _buttonText => _isEdit ? 'Sačuvaj izmene' : 'Završi dodavanje';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  /// Initialize screen with services and existing data
  Future<void> _initializeScreen() async {
    try {
      _advertisementService = context.read<AdvertisementService>();

      // Load existing advertisement data if editing
      if (_isEdit && widget.advertisement != null) {
        final ad = widget.advertisement!;
        _nameController.text = ad.name;
        _descriptionController.text = ad.description;
        _urlController.text = ad.url;
        _thumbUrl = ad.thumbUrl;
        _imageUrl = ad.imageUrl;
        _thumbPath = ad.thumbPath;
        _imagePath = ad.imagePath;
        _localImagePath = ad.localImagePath;
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to initialize CreateUpdateAdvertisementScreen',
        screen: 'CreateUpdateAdvertisementScreen',
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Greška pri učitavanju podataka';
          _isInitializing = false;
        });
      }
    }
  }

  /// Validates name input
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Naziv reklame je obavezan';
    }
    if (value.trim().length < 2) {
      return 'Naziv mora imati najmanje 2 karaktera';
    }
    if (value.trim().length > 100) {
      return 'Naziv može imati maksimalno 100 karaktera';
    }
    return null;
  }

  /// Validates URL input (optional field)
  String? _validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // URL is optional
    }

    // Basic URL validation
    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );

    if (!urlPattern.hasMatch(value.trim())) {
      return 'Unesite validan URL (npr. https://example.com)';
    }

    return null;
  }

  /// Picks image from gallery and uploads it
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        return; // User cancelled
      }

      setState(() {
        _isUploadingImage = true;
      });

      final imageFile = File(pickedFile.path);

      // Update local preview immediately
      setState(() {
        _localProfileImage = imageFile;
      });

      // Upload image to Firebase Storage
      final uploadResult = await uploadImage(imageFile, "reklama.jpg");

      if (uploadResult == null) {
        throw Exception('Upload image returned null');
      }

      setState(() {
        _imagePath = uploadResult["fullPath"];
        _thumbPath = uploadResult['thumbPath'];
        _imageUrl = uploadResult["fullUrl"];
        _thumbUrl = uploadResult['thumbUrl'];
        _localImagePath = imageFile.path;
        _isUploadingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slika je uspešno otpremljena'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to pick and upload image',
        screen: 'CreateUpdateAdvertisementScreen',
      );

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _localProfileImage = null; // Reset on error
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Greška pri otpremanju slike'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Saves or updates advertisement
  Future<void> _saveAdvertisement() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final advertisement = Advertisement(
        id: _isEdit ? widget.advertisement!.id : '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        url: _urlController.text.trim(),
        categoryRefId: widget.category.id,
        imageUrl: _imageUrl ?? '', // Empty string if no image
        thumbUrl: _thumbUrl ?? '',
        imagePath: _imagePath ?? '',
        thumbPath: _thumbPath ?? '',
        localImagePath: _localImagePath ?? '',
      );
      
      String advertisementId = advertisement.id;
      if (_isEdit) {
        await _advertisementService.updateAdvertisement(advertisement);
        debugPrint('✅ Updated advertisement: ${advertisement.id}');

        if (mounted) {
          _showSuccessSnackBar('Reklama "${advertisement.name}" je uspešno ažurirana');
        }
      } else {
        final adId = await _advertisementService.addNewAdvertisement(advertisement);

        advertisementId = adId;

        debugPrint('✅ Created advertisement with ID: $adId');

        if (mounted) {
          _showSuccessSnackBar('Reklama "${advertisement.name}" je uspešno dodata');
        }
      }

      // Navigate back after success
      if (mounted) {
         Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdvertisementsScreen(category: widget.category, initialAdvertisementId: advertisementId,)));
      }
    } on AddAdvertisementException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } on UpdateAdvertisementException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Unexpected error in _saveAdvertisement',
        screen: 'CreateUpdateAdvertisementScreen',
        additionalData: {
          'is_edit': _isEdit,
          'advertisement_name': _nameController.text.trim(),
          'category_id': widget.category.id,
        },
      );

      if (mounted) {
        _showErrorSnackBar('Neočekivana greška. Pokušajte ponovo.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Shows success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Builds app bar with title
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 3),
      child: Container(
        color: Colors.green[800],
        child: Column(
          children: [
            AppBar(
              elevation: 0,
              backgroundColor: Colors.transparent,
              title: Text(
                _title,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Container(
              height: 3,
              color: Colors.brown[500],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds main body content
  Widget _buildBody() {
    // Show loading while initializing
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show error if initialization failed
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isInitializing = true;
                });
                _initializeScreen();
              },
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildImageSection(),
            const SizedBox(height: 10),
            _buildNameField(),
            _buildUrlField(),
            _buildDescriptionField(),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  /// Builds image preview and picker section
  Widget _buildImageSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: Colors.brown[500] ?? Colors.brown,
                  width: 2,
                ),
              ),
              child: ClipRect(
                child: _buildImagePreview(),
              ),
            ),
            // Loading indicator overlay during upload
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isUploadingImage || _isLoading ? null : _pickImage,
          icon: Icon(Icons.edit, size: 20, color: Colors.green[800]),
          label: Text(
            _thumbUrl == null && _localProfileImage == null
                ? "Dodaj sliku (opciono)"
                : "Izmeni sliku",
            style: TextStyle(color: Colors.green[800], fontSize: 16),
          ),
        ),
      ],
    );
  }

  /// Builds image preview widget
  Widget _buildImagePreview() {
    // Show local image if picked
    if (_localProfileImage != null) {
      return Image.file(
        _localProfileImage!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
      );
    }

    // Show network image if available
    if (_thumbUrl != null && _thumbUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _thumbUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 120,
          height: 120,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: 120,
          height: 120,
          color: Colors.grey[300],
          child: const Icon(Icons.error, color: Colors.red),
        ),
      );
    }

    // Show placeholder if no image
    return Container(
      width: 120,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 60, color: Colors.white),
    );
  }

  /// Builds name input field
  Widget _buildNameField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: generateTextField(
        labelText: "Naziv",
        controller: _nameController,
        iconData: Icons.campaign,
        focusNode: _nameFocusNode,
        validator: _validateName,
        enabled: !_isLoading,
      ),
    );
  }

  /// Builds URL input field
  Widget _buildUrlField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: generateTextField(
        labelText: "Link ka sajtu (opciono)",
        controller: _urlController,
        iconData: Icons.link,
        validator: _validateUrl,
        enabled: !_isLoading,
      ),
    );
  }

  /// Builds description input field
  Widget _buildDescriptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: generateTextField(
        labelText: "Opis (opciono)",
        controller: _descriptionController,
        iconData: Icons.description,
        minLines: 1,
        maxLines: 10,
        enabled: !_isLoading,
      ),
    );
  }

  /// Builds save button
  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : generateButton(
              text: _buttonText,
              onPressed: _saveAdvertisement,
            ),
    );
  }
}