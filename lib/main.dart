import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fruit_care_pro/firebase_options.dart';
import 'package:fruit_care_pro/screens/change_password_screen.dart';
import 'package:fruit_care_pro/screens/change_user_data_screen.dart';
import 'package:fruit_care_pro/screens/message_info.dart';
import 'package:fruit_care_pro/screens/group_chat_screen.dart';
import 'package:fruit_care_pro/screens/private_chat_screen.dart';
import 'package:fruit_care_pro/current_user_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:fruit_care_pro/screens/login_screen.dart';
import 'package:fruit_care_pro/screens/splash_screen.dart';
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

final RouteObserver<ModalRoute> routeObserver = RouteObserver<ModalRoute>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  debugPrint('📩 Background message (main.dart): ${message.data}');
  await NotificationService.handleIncomingMessage(message);
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
    NotificationService.onNotificationTap = (chatId, senderId) {
      debugPrint('🔔 Navigating to chat: $chatId, senderId: $senderId');

      if (chatId.startsWith('chat_')) {
        // Privatni chat
        final currentUser = CurrentUserService.instance.currentUser;
        final role = currentUser?.isAdmin == true
            ? ChatUserRole.admin
            : ChatUserRole.user;

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => PrivateChatScreen(
              chatId: chatId,
              userId: senderId,
              role: role,
            ),
          ),
        );
      } else {
        // Grupni chat
        navigatorKey.currentState?.pushNamed(
          '/group-chat',
          arguments: {'chatId': chatId},
        );
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF1B3A2D),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF2E7D52).withValues(alpha: 0.6),
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          iconTheme: const IconThemeData(color: Colors.white, size: 20),
          actionsIconTheme: const IconThemeData(color: Colors.white, size: 20),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF388E3C),
          unselectedItemColor: Colors.grey[400],
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFEEEEEE),
          thickness: 1,
          space: 0,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF388E3C),
          brightness: Brightness.light,
        ),
        useMaterial3: false,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
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