
import 'package:fruit_care_pro/models/advertisement_category.dart';
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:flutter/material.dart';

class AddUpdateCategory extends StatefulWidget {
  final AdvertisementCategory? category;

  const AddUpdateCategory({super.key, this.category});

  @override
  _AddUpdateCategoryState createState() => _AddUpdateCategoryState();
}

class _AddUpdateCategoryState extends State<AddUpdateCategory> {

  //---Text controllers---
  final TextEditingController _nameController = TextEditingController();
  //---Text controllers---

  //---Services for db operations---
  final AdvertisementService _categorysService = AdvertisementService();
  //---Services for db operations---

  bool isAddNew = false;
  String _CategoryID = "999";
  String adminId = "";
  @override
  void initState() {
    super.initState();
    isAddNew = widget.category == null;

    if (widget.category != null) {
      _CategoryID = widget.category!.id;
      _nameController.text = widget.category!.name;
    }
  }



  void _saveCategory() async {
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

    final category = AdvertisementCategory(
      id: isAddNew ? "11" : _CategoryID,
      name: _nameController.text.trim(),
    );

    if (isAddNew) {
       await _categorysService.AddCategory(category);
    } else {
      await _categorysService.UpdateCategory(category);
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
                centerTitle: true,
                backgroundColor: Colors.transparent,
                title: Text(
                  widget.category == null
                      ? 'Dodaj novu kategoriju'
                      : 'Izmeni kategoriju',
                  style: TextStyle(
                    color: Colors.white,
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
              widget.category == null
                  ? 'Unesite podatke o novoj kategoriji'
                  : 'Izmenite podatke o kategoriji',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(
              label: 'Naziv kategorije',
              controller: _nameController,
              hintText: 'Unesite naziv',
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
            onPressed: _saveCategory,
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
