import 'package:flutter/material.dart';
import 'package:fruit_care_pro/exceptions/advertisement_exception.dart';
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:provider/provider.dart';

class AddUpdateCategory extends StatefulWidget {
  final AdvertisementCategory? category;

  const AddUpdateCategory({super.key, this.category});

  @override
  _AddUpdateCategoryState createState() => _AddUpdateCategoryState();
}

class _AddUpdateCategoryState extends State<AddUpdateCategory> {
  // Services
  late final AdvertisementService _advertisementService;

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  // Computed properties
  bool get _isAddNew => widget.category == null;
  String get _title => _isAddNew ? 'Dodaj novu kategoriju' : 'Izmeni kategoriju';
  String get _subtitle => _isAddNew
      ? 'Unesite podatke o novoj kategoriji'
      : 'Izmenite podatke o kategoriji';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Initialize screen with services and existing data
  Future<void> _initializeScreen() async {
    try {
      _advertisementService = context.read<AdvertisementService>();

      // Load existing category data if editing
      if (!_isAddNew && widget.category != null) {
        _nameController.text = widget.category!.name;
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
        reason: 'Failed to initialize AddUpdateCategory screen',
        screen: 'AddUpdateCategory',
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Greška pri učitavanju podataka';
          _isInitializing = false;
        });
      }
    }
  }

  /// Validates category name input
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Naziv kategorije je obavezan';
    }
    if (value.trim().length < 2) {
      return 'Naziv mora imati najmanje 2 karaktera';
    }
    if (value.trim().length > 50) {
      return 'Naziv može imati maksimalno 50 karaktera';
    }
    return null;
  }

  /// Saves or updates category
  Future<void> _saveCategory() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final category = AdvertisementCategory(
        id: _isAddNew ? '' : widget.category!.id,
        name: _nameController.text.trim(),
      );

      if (_isAddNew) {
        final categoryId = await _advertisementService.addCategory(category);
        debugPrint('✅ Created category with ID: $categoryId');

        if (mounted) {
          _showSuccessSnackBar('Kategorija "${category.name}" je uspešno dodata');
        }
      } else {
        await _advertisementService.updateCategory(category);
        debugPrint('✅ Updated category: ${category.id}');

        if (mounted) {
          _showSuccessSnackBar('Kategorija "${category.name}" je uspešno ažurirana');
        }
      }

      // Navigate back after success
      if (mounted) {
        Navigator.pop(context);
      }
    } on AddCategoryException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } on UpdateCategoryException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Unexpected error in _saveCategory',
        screen: 'AddUpdateCategory',
        additionalData: {
          'is_add_new': _isAddNew,
          'category_name': _nameController.text.trim(),
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
      backgroundColor: Colors.white,
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
              centerTitle: true,
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
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _buildNameField(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Builds name input field
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      enabled: !_isLoading,
      decoration: InputDecoration(
        labelText: 'Naziv kategorije',
        hintText: 'Unesite naziv',
        labelStyle: TextStyle(color: Colors.green[800]),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
      validator: _validateName,
      textCapitalization: TextCapitalization.words,
    );
  }

  /// Builds cancel and save buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.green),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "Odustani",
              style: TextStyle(color: Colors.green),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveCategory,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text("Sačuvaj"),
          ),
        ),
      ],
    );
  }
}