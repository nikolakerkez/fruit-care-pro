
import 'package:firebase_auth/firebase_auth.dart';


Future<User?> createAccount(String name, String email, String password, String repeatedPassword) async
{
  FirebaseAuth auth =  FirebaseAuth.instance;

  try {
    User? user = (await auth.createUserWithEmailAndPassword(
      email: email, password: password))
      .user;

      if (user != null)
      {
        print("Succeded");
      }
      else
      {
        print("Failed");
      }
      return user;
  } catch (e) {
    print(e);
    return null;
  }
}

Future<User?> logIn(String email, String password) async
{
  FirebaseAuth auth =  FirebaseAuth.instance;

  try {
    User? user = (await auth.signInWithEmailAndPassword(
      email: email, password: password))
      .user;

      if (user != null)
      {
        print("Succeded");
      }
      else
      {
        print("Failed");
      }
      return user;
  } catch (e) {
    print(e);
    return null;
  }
}

Future signOut() async
{
  FirebaseAuth auth =  FirebaseAuth.instance;

  try {
    auth.signOut();
  } catch (e) {
    print(e);
  }
}