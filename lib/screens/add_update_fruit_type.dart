
import 'package:fruit_care_pro/models/fruit_type.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';

class AddUpdateFruitType extends StatefulWidget {
  final FruitType? fruitType;

  const AddUpdateFruitType({super.key, this.fruitType});

  @override
  _AddUpdateFruitTypeState createState() => _AddUpdateFruitTypeState();
}

class _AddUpdateFruitTypeState extends State<AddUpdateFruitType> {

  //---Text controllers---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _treesController = TextEditingController();
  //---Text controllers---

  //---Services for db operations---
  final FruitTypesService _fruitTypesService = FruitTypesService();
  final UserService _userService = UserService();
  //---Services for db operations---

  bool isAddNew = false;
  String _fruitTypeID = "999";
  String adminId = "";
  @override
  void initState() {
    super.initState();
    isAddNew = widget.fruitType == null;

    if (widget.fruitType != null) {
      _nameController.text = widget.fruitType!.name;
      _treesController.text = widget.fruitType!.numberOfTreesPerAre.toString();
      _fruitTypeID = widget.fruitType!.id;
    }

    initialize();
  }

  void initialize() async
  {
    String? adminIdValue = await _userService.getAdminId();

    setState(() {
      adminId = adminIdValue!;
    });
  }

  void _saveFruit() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20)
          ],
        ),
      ),
    );

    final fruit = FruitType(
      id: isAddNew ? "11" : _fruitTypeID,
      name: _nameController.text.trim(),
      numberOfTreesPerAre: int.tryParse(_treesController.text.trim()) ?? 0,
    );

    if (isAddNew) {
       String fruitTypeId = await _fruitTypesService.addFruitType(fruit, adminId);
    } else {
      await _fruitTypesService.updateFruitType(fruit);
    }

    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // bolji kontrast
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 3),
        child: Container(
          color: Colors.green[800],
          child: Column(
            children: [
              AppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Text(
                  widget.fruitType == null
                      ? 'Dodaj voćnu vrstu'
                      : 'Izmeni voćnu vrstu',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                height: 3,
                color: Colors.brown[500],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fruitType == null
                  ? 'Unesite podatke o novoj voćnoj vrsti'
                  : 'Izmenite podatke o voćnoj vrsti',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(
              label: 'Naziv voćne vrste',
              controller: _nameController,
              hintText: 'Unesite naziv',
            ),
            SizedBox(height: 16),
            _buildTextField(
              label: 'Broj stabala po hektaru',
              controller: _treesController,
              hintText: 'Unesite broj stabala',
              inputType: TextInputType.number,
            ),
            SizedBox(height: 32),
            _buildCancelAndSaveButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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
      ),
    );
  }

  Widget _buildCancelAndSaveButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.green),
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text("Odustani", style: TextStyle(color: Colors.green)),
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveFruit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text("Sačuvaj"),
          ),
        ),
      ],
    );
  }
}
