import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static RemoteMessage? _pendingInitialMessage;

  // Prati koji chatovi imaju aktivne notifikacije → badge = broj takvih chatova
  static final Set<String> _activeNotificationChats = {};

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Callback za navigaciju kada se tapne notifikacija
  static Function(String chatId, String? senderId)? onNotificationTap;

  /// Inicijalizacija notification service-a
  static Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing NotificationService...');

      // Request permissions (iOS)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ User granted notification permission');
      } else {
        debugPrint('⚠️ User declined notification permission, continuing without notifications');
      }

      // Listen to token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed');
        _saveTokenToFirestore(newToken);
      });

      // iOS foreground — neka iOS sam prikazuje notifikacije
      // flutter_local_notifications koristimo samo za Android
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Initialize local notifications (potrebno za Android foreground)
      await _initializeLocalNotifications();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification taps (background/terminated)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _pendingInitialMessage = initialMessage;
          debugPrint('📩 Initial message saved, waiting for app to be ready');
        }

      debugPrint('✅ NotificationService initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize NotificationService: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Pozovi ovu metodu NAKON što se korisnik uloguje
  static Future<void> saveTokenAfterLogin() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ User not logged in');
        return;
      }
      
      debugPrint('🔔 Saving FCM token after login...');
      await _saveFCMToken();
      debugPrint('✅ FCM token saved after login');
    } catch (e) {
      debugPrint('❌ Error saving token after login: $e');
    }
  }

static void handlePendingNotification() {
  debugPrint('🔔 handlePendingNotification - pending: $_pendingInitialMessage');
  debugPrint('🔔 onNotificationTap callback set: ${onNotificationTap != null}');
  
  if (_pendingInitialMessage != null) {
    _handleNotificationTap(_pendingInitialMessage!);
    _pendingInitialMessage = null;
  }
}

  /// Sačuvaj FCM token
  static Future<void> _saveFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('🔑 FCM Token: $token');
        await _saveTokenToFirestore(token);
      } else {
        debugPrint('❌ FCM Token is NULL');
      }
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
    }
  }

  /// Snimi token u Firestore
  static Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot save FCM token - user not authenticated');
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ FCM Token saved to Firestore for user: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token to Firestore: $e');
    }
  }

  /// Inicijalizuj local notifications
  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false, // iOS koristi Firebase permission
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,  // prikaži notifikaciju dok je app u foregroundu
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          debugPrint('📱 Local notification tapped: ${response.payload}');
          onNotificationTap?.call(response.payload!, null);
        }
      },
    );
    
    // Android notification channel
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'chat_messages',
        'Poruke',
        description: 'Notifikacije za nove poruke',
        importance: Importance.high,
        playSound: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation
              <AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('✅ Android notification channel created');
      }
    }

    debugPrint('✅ Local notifications initialized');
  }

  /// Handle foreground messages
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground message: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Na iOS-u, sistem sam prikazuje notifikacije (alert: true gore)
    // Na Android-u prikazujemo lokalnu notifikaciju jer sistem ne prikazuje automatski
    if (Platform.isAndroid && message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Prikaži local notification (Android i iOS foreground)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final String? chatId = message.data['chatId'] as String?;
    final int notificationId = chatId?.hashCode ?? message.hashCode;

    // Ažuriraj tracker i izračunaj novi badge broj
    if (chatId != null) _activeNotificationChats.add(chatId);
    final int badgeCount = _activeNotificationChats.length;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Poruke',
      channelDescription: 'Notifikacije za nove poruke',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: chatId,
      badgeNumber: badgeCount, // badge = broj chatova sa aktivnim notifikacijama
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notificationId,
      message.notification?.title ?? 'Nova poruka',
      message.notification?.body ?? '',
      details,
      payload: chatId,
    );

    debugPrint('✅ Local notification shown (id: $notificationId)');
  }

  /// Obriši notifikacije za određeni chat (pozovi kada se otvori chat screen)
  static Future<void> cancelNotificationsForChat(String chatId) async {
    try {
      _activeNotificationChats.remove(chatId);
      await _localNotifications.cancel(chatId.hashCode);

      if (Platform.isIOS) {
        await _localNotifications.cancelAll();
        await _resetBadge();
      }

      // Resetuj badge counter u Firestore-u
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'badgeCount': 0,
        });
      }

      debugPrint('✅ Notifications cancelled for chat: $chatId');
    } catch (e) {
      debugPrint('❌ Failed to cancel notifications for chat: $e');
    }
  }

  /// Resetuje badge broj na app ikoni na 0 (samo iOS)
  static Future<void> _resetBadge() async {
    try {
      const int badgeResetId = 99999;
      await _localNotifications.show(
        badgeResetId,
        null,
        null,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: 0,
          ),
        ),
      );
      await _localNotifications.cancel(badgeResetId);
    } catch (e) {
      debugPrint('❌ Failed to reset badge: $e');
    }
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    final String? chatId = message.data['chatId'] as String?;
    final String? senderId = message.data['senderId'] as String?;

    debugPrint('👆 Notification tapped - chatId: $chatId, senderId: $senderId');

    if (chatId != null) {
      onNotificationTap?.call(chatId, senderId);
    }
  }

  /// Označi da je korisnik aktivan u određenom chatu
  /// Cloud Function neće slati notifikacije za taj chat dok je aktivan
  static Future<void> setActiveChat(String chatId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _firestore.collection('users').doc(user.uid).update({
        'activeChatId': chatId,
      });
    } catch (e) {
      debugPrint('❌ Failed to set activeChatId: $e');
    }
  }

  /// Obriši aktivni chat (pozovi kad korisnik napusti chat)
  static Future<void> clearActiveChat() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _firestore.collection('users').doc(user.uid).update({
        'activeChatId': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('❌ Failed to clear activeChatId: $e');
    }
  }

  /// Obriši FCM token na logout
  static Future<void> clearToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
        debugPrint('✅ FCM token removed from Firestore');
      }
      await _messaging.deleteToken();
      debugPrint('✅ FCM token deleted from device');
    } catch (e) {
      debugPrint('❌ Failed to clear FCM token: $e');
    }
  }
}