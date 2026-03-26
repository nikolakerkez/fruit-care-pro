import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static RemoteMessage? _pendingInitialMessage;

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

      // Foreground notifications (iOS prikazuje automatski)
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

    // Prikaži lokalnu notifikaciju SAMO na Android-u
    // iOS automatski prikazuje zbog setForegroundNotificationPresentationOptions
    if (Platform.isAndroid && message.notification != null) {
      _showLocalNotification(message);
    }
  }

  /// Prikaži local notification (samo Android)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final String? chatId = message.data['chatId'] as String?;

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

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Nova poruka',
      message.notification?.body ?? '',
      details,
      payload: chatId,
    );

    debugPrint('✅ Local notification shown');
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