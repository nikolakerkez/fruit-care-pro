import 'package:fruit_care_pro/firebase_options.dart';
import 'package:fruit_care_pro/screens/change_password_screen.dart';
import 'package:fruit_care_pro/screens/change_user_data_screen.dart';
import 'package:fruit_care_pro/screens/message_info.dart';
import 'package:fruit_care_pro/screens/group_chat_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/screens/login_screen.dart';
import 'package:fruit_care_pro/screens/admin_main_screen.dart';
import 'package:fruit_care_pro/screens/user_main_screen.dart';
import 'package:fruit_care_pro/models/user.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:fruit_care_pro/user_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Future.delayed(Duration(milliseconds: 500));
  // Omogući Crashlytics slanje podataka
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  runApp(MultiProvider(
    providers: [
      // User state
      ChangeNotifierProvider(create: (_) => UserNotifier()),

      // Services (singletons)
      Provider(create: (_) => UserService()),

      Provider(create: (_) => ChatService()),

    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/', // Početna ruta
      routes: {
        '/': (context) => LoginScreen(),
        '/login': (context) => LoginScreen(),
        '/admin': (context) => AdminMainScreen(),
        '/user': (context) => UserMainScreen(),
        '/change-password': (context) => ChangePasswordScreen(),
        '/group-chat': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;

          return GroupChatScreen(
            chatId: args?['chatId'],
            fruitTypeId: args?['fruitTypeId'],
            fruitTypeName: args?['fruitTypeName'],
          );
        },
        '/message-info-screen': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;

          return MessageDetailsScreen(
            chatId: args?['chatId'],
            messageId: args?['messageId'],
          );
        },
        '/change-user-data': (context) => ChangeUserDataScreen(
            appUser: ModalRoute.of(context)?.settings.arguments as AppUser?),
      },
    );
  }
}
// class SplashScreen extends StatelessWidget {
//   const SplashScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<User?>(
//       future: _getCurrentUser(),
//       builder: (context, snapshot) {
//         // Dok se podaci učitavaju
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }

//         // Ako dođe do greške
//         if (snapshot.hasError) {
//           return Scaffold(
//             body: Center(
//               child: Text('Greška prilikom učitavanja korisnika: ${snapshot.error}'),
//             ),
//           );
//         }

//         // Ako nema podataka
//         if (!snapshot.hasData || snapshot.data == null) {
//           return LoginScreen();
//         }

//         // Ako su podaci uspešno učitani
//         final user = snapshot.data!;
//         final isAdmin = user.email == 'admin@example.com'; // Primer logike za admina
//         final route = isAdmin ? '/admin' : '/user';
        
//         // Navigacija ka odgovarajućem ekranu
//         Future.delayed(
//           const Duration(seconds: 2),
//           () => Navigator.pushReplacementNamed(context, route, arguments: AppUser(email: user.email)),
//         );

//         // Prikazivanje praznog ekrana dok se navigacija izvršava
//         return const Scaffold(
//           body: Center(child: CircularProgressIndicator()),
//         );
//       },
//     );
//   }

//   Future<User?> _getCurrentUser() async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user != null) {
//       await user.reload();
//       return FirebaseAuth.instance.currentUser;
//     }
//     return null;
//   }
// }