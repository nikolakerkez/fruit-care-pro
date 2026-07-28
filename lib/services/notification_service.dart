import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static RemoteMessage? _pendingInitialMessage;

  // Prati koji chatovi imaju aktivne notifikacije → badge = broj takvih chatova
  static final Set<String> _activeNotificationChats = {};

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kanal ka native (Swift) strani za brisanje grupisanih iOS notifikacija
  static const MethodChannel _iosChannel =
      MethodChannel('com.fruitcarepro/notifications');

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

      // Obriši activeChatId pri svakom pokretanju app-a
      // (može ostati ako je app ubijen dok je korisnik bio u chatu)
      await clearActiveChat();

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
    debugPrint('📩 Foreground message data: ${message.data}');
    handleIncomingMessage(message);
  }

  /// Obradi dolaznu poruku (foreground ili background isolate).
  /// iOS: OS sam prikazuje/grupiše native notifikaciju (aps.alert + thread-id).
  /// Android: poruka je data-only, pa mi sami pravimo grupisanu notifikaciju.
  static Future<void> handleIncomingMessage(RemoteMessage message) async {
    if (Platform.isAndroid) {
      // Osiguraj da kanal postoji i u ovoj (možda tek pokrenutoj) izolati
      await _initializeLocalNotifications();
      await _showLocalNotification(message);
    }
  }

  /// Prikaži grupisanu Android notifikaciju: pojedinačna poruka + summary
  /// ("N novih poruka") sa istim groupKey (chatId) - isto kao WhatsApp.
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final String? chatId = message.data['chatId'] as String?;
    final String? messageId = message.data['messageId'] as String?;
    final String title = message.data['title'] as String? ?? 'Nova poruka';
    final String body = message.data['body'] as String? ?? '';

    if (chatId == null) return;

    _activeNotificationChats.add(chatId);

    final prefs = await SharedPreferences.getInstance();
    final String storageKey = 'chat_notifications_$chatId';
    final List<String> storedLines =
        prefs.getStringList('${storageKey}_lines') ?? [];
    final List<String> storedIds =
        prefs.getStringList('${storageKey}_ids') ?? [];

    final int messageNotificationId =
        (messageId ?? DateTime.now().millisecondsSinceEpoch.toString())
                .hashCode &
            0x7fffffff;
    final int summaryNotificationId =
        ('summary_$chatId').hashCode & 0x7fffffff;

    storedLines.add(body);
    if (storedLines.length > 10) storedLines.removeAt(0);
    storedIds.add(messageNotificationId.toString());

    await prefs.setStringList('${storageKey}_lines', storedLines);
    await prefs.setStringList('${storageKey}_ids', storedIds);
    await prefs.setInt('${storageKey}_summary_id', summaryNotificationId);

    final AndroidNotificationDetails messageDetails = AndroidNotificationDetails(
      'chat_messages',
      'Poruke',
      channelDescription: 'Notifikacije za nove poruke',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
      groupKey: chatId,
    );

    await _localNotifications.show(
      messageNotificationId,
      title,
      body,
      NotificationDetails(android: messageDetails),
      payload: chatId,
    );

    final int count = storedLines.length;
    final AndroidNotificationDetails summaryDetails = AndroidNotificationDetails(
      'chat_messages',
      'Poruke',
      channelDescription: 'Notifikacije za nove poruke',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      icon: '@mipmap/ic_launcher',
      groupKey: chatId,
      setAsGroupSummary: true,
      styleInformation: InboxStyleInformation(
        storedLines,
        contentTitle: '$count ${count == 1 ? 'nova poruka' : 'nove poruke'}',
        summaryText: title,
      ),
    );

    await _localNotifications.show(
      summaryNotificationId,
      title,
      body,
      NotificationDetails(android: summaryDetails),
      payload: chatId,
    );

    debugPrint('✅ Grouped notification shown for chat: $chatId (count: $count)');
  }

  /// Obriši notifikacije za određeni chat (pozovi kada se otvori chat screen)
  static Future<void> cancelNotificationsForChat(String chatId) async {
    try {
      _activeNotificationChats.remove(chatId);

      if (Platform.isAndroid) {
        // Obriši sve pojedinačne notifikacije + summary za ovaj chat
        final prefs = await SharedPreferences.getInstance();
        final String storageKey = 'chat_notifications_$chatId';
        final List<String> storedIds =
            prefs.getStringList('${storageKey}_ids') ?? [];
        for (final idStr in storedIds) {
          final id = int.tryParse(idStr);
          if (id != null) await _localNotifications.cancel(id);
        }
        final int? summaryId = prefs.getInt('${storageKey}_summary_id');
        if (summaryId != null) await _localNotifications.cancel(summaryId);

        await prefs.remove('${storageKey}_ids');
        await prefs.remove('${storageKey}_lines');
        await prefs.remove('${storageKey}_summary_id');
      }

      if (Platform.isIOS) {
        // Obriši sve OS-native (APNs) notifikacije sa istim thread-id (chatId)
        try {
          await _iosChannel.invokeMethod(
            'clearNotificationsForThread',
            {'chatId': chatId},
          );
        } catch (e) {
          debugPrint('⚠️ Failed to clear iOS notifications for thread: $e');
        }
      }

      // Oduzmi notifikacije ovog chata od ukupnog badge countera
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = _firestore.collection('users').doc(user.uid);
        int newCount = 0;
        await _firestore.runTransaction((t) async {
          final userDoc = await t.get(userRef);
          final data = userDoc.data() ?? {};
          final chatCounts = Map<String, dynamic>.from(
            (data['chatBadgeCounts'] as Map<String, dynamic>?) ?? {},
          );
          // Ukloni ovaj chat i saberi preostale
          chatCounts.remove(chatId);
          newCount = chatCounts.values
              .fold(0, (acc, v) => acc + ((v as num?)?.toInt() ?? 0));
          t.update(userRef, {
            'badgeCount': newCount,
            'chatBadgeCounts.$chatId': FieldValue.delete(),
          });
        });

        // Osvoji badge na ikoni sa novim brojem
        if (Platform.isIOS) {
          await _updateBadge(newCount);
        }
      }

      debugPrint('✅ Notifications cancelled for chat: $chatId');
    } catch (e) {
      debugPrint('❌ Failed to cancel notifications for chat: $e');
    }
  }

  /// Postavi badge broj na app ikoni (samo iOS)
  static Future<void> _updateBadge(int count) async {
    try {
      const int badgeUpdateId = 99999;
      await _localNotifications.show(
        badgeUpdateId,
        null,
        null,
        NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: false,
            presentSound: false,
            presentBadge: true,
            badgeNumber: count,
          ),
        ),
      );
      await _localNotifications.cancel(badgeUpdateId);
    } catch (e) {
      debugPrint('❌ Failed to update badge: $e');
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