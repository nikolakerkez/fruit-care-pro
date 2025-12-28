import 'package:flutter/material.dart';
import 'package:fruit_care_pro/auth_service.dart';

final TextEditingController _name = TextEditingController();
final TextEditingController _email = TextEditingController();
final TextEditingController _password = TextEditingController();
final TextEditingController _repeatedPassword = TextEditingController();

class CreateAccount extends StatefulWidget {
  const CreateAccount({super.key});

  @override
  State<CreateAccount> createState() => _CreateAccountState();
}

class _CreateAccountState extends State<CreateAccount> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: size.height / 20,
          ),
          Container(
            alignment: Alignment.centerLeft,
            width: size.width / 1.2,
            child:
                IconButton(onPressed: () {}, icon: Icon(Icons.arrow_back_ios)),
          ),
          SizedBox(
            height: size.height / 50,
          ),
          Container(
            alignment: Alignment.center,
            width: size.width / 1.2,
            child: Text("Portal B-Bogdanovic",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                )),
          ),
          Container(
              alignment: Alignment.center,
              width: size.width / 1.3,
              child: Text("Dobrodosli",
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 25,
                      fontWeight: FontWeight.w500))),
          SizedBox(
            height: size.height / 20,
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Container(
                width: size.width,
                alignment: Alignment.center,
                child: field(size, "Ime firme / fizickog lica",
                    Icons.account_box, _name),
              )),
          Container(
            width: size.width,
            alignment: Alignment.center,
            child: field(size, "E-mail", Icons.account_box, _email),
          ),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: Container(
                width: size.width,
                alignment: Alignment.center,
                child: field(size, "Sifra", Icons.lock, _password),
              )),
          Container(
            width: size.width,
            alignment: Alignment.center,
            child: field(
                size, "Ponovo unesi sifru", Icons.lock, _repeatedPassword),
          ),
          SizedBox(
            height: size.height / 20,
          ),
          customButton(size),
          SizedBox(
            height: size.height / 40,
          ),
        ],
      ),
    );
  }

  Widget customButton(Size size) {
    return GestureDetector(
        onTap: () {
          print('Clicked');
          createAccount(_name.text, _email.text, _password.text,
                  _repeatedPassword.text)
              .then((user) {
            if (user != null) {}
          });
        },
        child: Container(
          height: size.height / 14,
          width: size.width / 1.2,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), color: Colors.blue),
          alignment: Alignment.center,
          child: Text(
            "Napravi nalog",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ));
  }

  Widget field(
      Size size, String hintText, IconData icon, TextEditingController cont) {
    return SizedBox(
      height: size.height / 15,
      width: size.width / 1.2,
      child: TextField(
        controller: cont,
        decoration: InputDecoration(
            prefixIcon: Icon(icon),
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
      ),
    );
  }
}
