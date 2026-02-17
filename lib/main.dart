import 'package:firebase_messaging/firebase_messaging.dart';
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
import 'package:fruit_care_pro/services/advertisement_service.dart';
import 'package:fruit_care_pro/services/chat_service.dart';
import 'package:fruit_care_pro/services/fruit_types_service.dart';
import 'package:fruit_care_pro/services/notification_service.dart';
import 'package:fruit_care_pro/services/user_service.dart';
import 'package:provider/provider.dart';
import 'package:fruit_care_pro/user_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Future.delayed(Duration(milliseconds: 500));
  
  // Omogući Crashlytics slanje podataka
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize notifications
  await NotificationService.initialize();
  
  runApp(MultiProvider(
    providers: [
      // User state
      ChangeNotifierProvider(create: (_) => UserNotifier()),

      // Services (singletons)
      Provider(create: (_) => UserService()),
      Provider(create: (_) => ChatService()),
      Provider(create: (_) => FruitTypesService()),
      Provider(create: (_) => AdvertisementService()),
    ],
    child: const MyApp(),
  ));
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('📩 Background message (main.dart): ${message.notification?.title}');
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Global key za navigaciju
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    // Setup callback za notification tap
    NotificationService.onNotificationTap = (chatId) {
      debugPrint('🔔 Navigating to chat: $chatId');
      
      // Navigiraj do group chat screen-a
      // Pretpostavljam da trebaš chatId, možeš dodati ostale argumente ako treba
      navigatorKey.currentState?.pushNamed(
        '/group-chat',
        arguments: {
          'chatId': chatId,
          // Dodaj ostale argumente ako su potrebni
          // 'fruitTypeId': ...,
          // 'fruitTypeName': ...,
        },
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Dodaj navigatorKey
      initialRoute: '/',
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