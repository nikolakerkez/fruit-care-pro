import 'package:flutter/material.dart';
import 'package:fruit_care_pro/exceptions/fruit_types_exception.dart';
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:fruit_care_pro/utils/error_logger.dart';
import 'package:provider/provider.dart';

class AddUpdateFruitType extends StatefulWidget {
  final FruitType? fruitType;

  const AddUpdateFruitType({super.key, this.fruitType});

  @override
  _AddUpdateFruitTypeState createState() => _AddUpdateFruitTypeState();
}

class _AddUpdateFruitTypeState extends State<AddUpdateFruitType> {
  // Services
  late final FruitTypesService _fruitTypesService;
  late final UserService _userService;

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _treesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // State
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _adminId;
  String? _errorMessage;

  // Computed properties
  bool get _isAddNew => widget.fruitType == null;
  String get _title => _isAddNew ? 'Dodaj voćnu vrstu' : 'Izmeni voćnu vrstu';
  String get _subtitle => _isAddNew
      ? 'Unesite podatke o novoj voćnoj vrsti'
      : 'Izmenite podatke o voćnoj vrsti';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _treesController.dispose();
    super.dispose();
  }

  /// Initialize screen with services and existing data
  Future<void> _initializeScreen() async {
    try {
      _fruitTypesService = context.read<FruitTypesService>();
      _userService = context.read<UserService>();

      // Load existing fruit type data if editing
      if (!_isAddNew && widget.fruitType != null) {
        _nameController.text = widget.fruitType!.name;
        _treesController.text = widget.fruitType!.numberOfTreesPerAre.toString();
      }

      // Get admin ID for creating new fruit types
      if (_isAddNew) {
        final adminId = await _userService.getAdminId();
        
        if (adminId == null || adminId.isEmpty) {
          throw Exception('Admin ID nije pronađen');
        }

        if (mounted) {
          setState(() {
            _adminId = adminId;
            _isInitializing = false;
          });
        }
      } else {
        // No need to fetch admin ID for updates
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Failed to initialize AddUpdateFruitType screen',
        screen: 'AddUpdateFruitType',
      );

      if (mounted) {
        setState(() {
          _errorMessage = 'Greška pri učitavanju podataka';
          _isInitializing = false;
        });
      }
    }
  }

  /// Validates input fields
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Naziv voćne vrste je obavezan';
    }
    if (value.trim().length < 2) {
      return 'Naziv mora imati najmanje 2 karaktera';
    }
    if (value.trim().length > 50) {
      return 'Naziv može imati maksimalno 50 karaktera';
    }
    return null;
  }

  /// Validates number of trees input
  String? _validateTreesCount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Broj stabala je obavezan';
    }

    final number = int.tryParse(value.trim());
    if (number == null) {
      return 'Unesite validan broj';
    }

    if (number <= 0) {
      return 'Broj stabala mora biti veći od 0';
    }

    return null;
  }

  /// Saves or updates fruit type
  Future<void> _saveFruit() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check admin ID for new fruit types
    if (_isAddNew && (_adminId == null || _adminId!.isEmpty)) {
      _showErrorSnackBar('Admin ID nije dostupan. Pokušajte ponovo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fruit = FruitType(
        id: _isAddNew ? '' : widget.fruitType!.id,
        name: _nameController.text.trim(),
        numberOfTreesPerAre: int.parse(_treesController.text.trim()),
      );

      if (_isAddNew) {
        final fruitTypeId = await _fruitTypesService.addFruitType(fruit, _adminId!);
        debugPrint('✅ Created fruit type with ID: $fruitTypeId');
        
        if (mounted) {
          _showSuccessSnackBar('Voćna vrsta "${fruit.name}" je uspešno dodata');
        }
      } else {
        await _fruitTypesService.updateFruitType(fruit);
        debugPrint('✅ Updated fruit type: ${fruit.id}');
        
        if (mounted) {
          _showSuccessSnackBar('Voćna vrsta "${fruit.name}" je uspešno ažurirana');
        }
      }

      // Navigate back after success
      if (mounted) {
        Navigator.pop(context);
      }
    } on AddFruitTypeException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } on UpdateFruitTypeException catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e, stackTrace) {
      await ErrorLogger.logError(
        e,
        stackTrace,
        reason: 'Unexpected error in _saveFruit',
        screen: 'AddUpdateFruitType',
        additionalData: {
          'is_add_new': _isAddNew,
          'fruit_name': _nameController.text.trim(),
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
            const SizedBox(height: 16),
            _buildTreesCountField(),
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
        labelText: 'Naziv voćne vrste',
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

  /// Builds trees count input field
  Widget _buildTreesCountField() {
    return TextFormField(
      controller: _treesController,
      enabled: !_isLoading,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Broj stabala po hektaru',
        hintText: 'Unesite broj stabala',
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
      validator: _validateTreesCount,
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
            onPressed: _isLoading ? null : _saveFruit,
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