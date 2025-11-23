import 'package:bb_agro_portal/firebase_options.dart';
import 'package:bb_agro_portal/screens/admin_private_chat_screen.dart';
import 'package:bb_agro_portal/screens/change_password_screen.dart';
import 'package:bb_agro_portal/screens/change_user_data_screen.dart';
import 'package:bb_agro_portal/screens/message_info.dart';
import 'package:bb_agro_portal/screens/user_private_chat_screen.dart';
import 'package:bb_agro_portal/screens/group_chat_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:bb_agro_portal/screens/login_screen.dart';
import 'package:bb_agro_portal/screens/admin_main_screen.dart';
import 'package:bb_agro_portal/screens/user_main_screen.dart';
import 'package:bb_agro_portal/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:bb_agro_portal/user_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(ChangeNotifierProvider(
      create: (_) => UserNotifier(),  // instanca UserNotifier-a
      child: MyApp(),                 // root widget aplikacije
    ),);
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
        '/admin': (context) => AdminMainScreen(adminUser: ModalRoute.of(context)?.settings.arguments as AppUser?),
        '/user': (context) => UserMainScreen(appUser: ModalRoute.of(context)?.settings.arguments as AppUser?),
        '/change-password': (context) => ChangePasswordScreen(appUser: ModalRoute.of(context)?.settings.arguments as AppUser?),
        '/admin-private-chat': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

            return AdminPrivateChatScreen(
              chatId: args?['chatId'],
              userId: args?['userId'],
            );
          },
          '/person-private-chat': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

            return UserPrivateChatScreen(
              chatId: args?['chatId'],
              userId: args?['userId'],
            );
          },
          '/group-chat': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

            return GroupChatScreen(
              chatId: args?['chatId'],
              fruitTypeId: args?['fruitTypeId'],
              fruitTypeName: args?['fruitTypeName'],
            );
          },
          '/message-info-screen': (context) {
            final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

            return MessageDetailsScreen(
              chatId: args?['chatId'],
              messageId: args?['messageId'],
            );
          },
          '/change-user-data': (context) => ChangeUserDataScreen(appUser: ModalRoute.of(context)?.settings.arguments as AppUser?),
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