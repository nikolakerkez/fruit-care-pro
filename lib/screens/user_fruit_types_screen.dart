import 'package:flutter/material.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';

class UserFruitTypes extends StatefulWidget {
  const UserFruitTypes({super.key});

  @override
  State<UserFruitTypes> createState() => UserFruitTypesState();
}

class UserFruitTypesState extends State<UserFruitTypes> {
  final FruitTypesService _firestoreService = FruitTypesService();

  List<String> fruitTypes = ['Apple', 'Orange', 'Grape', 'Peach'];
  String? selectedFruitType;
  final _numberOfTreesController = TextEditingController();
  List<Map<String, dynamic>> selectedFruits = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Vocne vrste"),
          backgroundColor: Colors.green[600],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: IntrinsicHeight(
            child: Row(
            children: [
              // Leva strana sa inputima i dropdownom
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown za voćnu vrstu
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12.0), 
                      child: DropdownButton<String>(
                        hint: Text("Vocna vrsta"),
                        value: selectedFruitType,
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() {
                            selectedFruitType = value;
                          });
                        },
                        items: fruitTypes.map((fruit) {
                          return DropdownMenuItem<String>(
                            value: fruit,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(fruit),
                            ),
                          );
                        }).toList(),
                        style: TextStyle(color: Colors.black),
                        dropdownColor: Colors.white,
                        alignment: Alignment.center,
                      ),
                    ),
                    SizedBox(height: 16),
                    // Input za broj stabala

                    //generateTextField("Br. stabala", _numberOfTreesController, Icons.nature),
                  ],
                ),
              ),
              SizedBox(width: 16),
              // Desna strana sa dugmetom
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0),
                  child: SizedBox(
                    height: 120,
                    child: ElevatedButton.icon(
                    onPressed: () {
                      // Tvoj kod za dugme
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserFruitTypes()));
                    },
                    label: Text(
                      "Dodaj",
                      style: TextStyle(color: Colors.green, fontSize: 16),
                    ),
                    
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        side: BorderSide(color: Colors.green, width: 2),
                      ),
                    ),
                  )),
                ),
              ),
            ],
          )
          )
        ));
  }
}
