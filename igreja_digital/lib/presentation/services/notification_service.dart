import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  urgentAnnouncement,
  newSermon,
  prayerRequest,
  event,
  generic,
}

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final service = NotificationService();
  await service._showBackgroundNotification(message);
}

class NotificationPayload {
  final NotificationType type;
  final String entityId;
  final String? congregationId;
  final String? title;
  final String? body;
  final String? route;
  final String? createdAt;

  NotificationPayload({
    required this.type,
    required this.entityId,
    this.congregationId,
    this.title,
    this.body,
    this.route,
    this.createdAt,
  });

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    final typeValue = json['type']?.toString();
    return NotificationPayload(
      type: NotificationType.values.firstWhere(
        (e) =>
            e.name == typeValue || _legacyNotificationTypeName(e) == typeValue,
        orElse: () => NotificationType.generic,
      ),
      entityId: json['entityId'] ?? '',
      congregationId: json['congregationId'],
      title: json['title'],
      body: json['body'],
      route: json['route'],
      createdAt: json['createdAt'],
    );
  }

  static String _legacyNotificationTypeName(NotificationType type) {
    switch (type) {
      case NotificationType.urgentAnnouncement:
        return 'urgent_announcement';
      case NotificationType.newSermon:
        return 'new_sermon';
      case NotificationType.prayerRequest:
        return 'prayer_request';
      case NotificationType.event:
        return 'future_event';
      case NotificationType.generic:
        return 'generic';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'entityId': entityId,
      'congregationId': congregationId,
      'title': title,
      'body': body,
      'route': route,
      'createdAt': createdAt,
    };
  }
}

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  final Set<String> _subscribedTopics = <String>{};
  String? _initializedUserId;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final StreamController<NotificationPayload> _notificationController =
      StreamController<NotificationPayload>.broadcast();

  Stream<NotificationPayload> get notificationStream =>
      _notificationController.stream;

  bool get isInitialized => _initializedUserId != null;

  Future<void> initialize(
    String userId, {
    VoidCallback? onNotificationTap,
  }) async {
    if (_initializedUserId == userId) {
      return;
    }

    await _clearListeners();

    // 1. Solicitar permissões
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Obter Token e guardar no Firestore
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(userId, token);
      }

      // 3. Configurar Local Notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            final payload = NotificationPayload.fromJson(
              jsonDecode(response.payload!),
            );
            _notificationController.add(payload);
            onNotificationTap?.call();
          }
        },
      );

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Ouvir mensagens em foreground
      _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showLocalNotification(message);
      });

      // 5. Ouvir mensagens em background
      _onMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = _extractPayload(message);
        if (payload != null) {
          _notificationController.add(payload);
          onNotificationTap?.call();
        }
      });

      // 6. Verificar se a app foi aberta por notificação (terminated)
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        final payload = _extractPayload(initialMessage);
        if (payload != null) {
          _notificationController.add(payload);
          onNotificationTap?.call();
        }
      }

      // 7. Subscrever a tópicos
      await _fcm.subscribeToTopic('global');
      await _fcm.subscribeToTopic('urgent_announcements');
      _subscribedTopics.add('global');
      _subscribedTopics.add('urgent_announcements');

      // 8. Ouvir mudanças de token
      _onTokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) {
        _saveTokenToDatabase(userId, newToken);
      });

      _initializedUserId = userId;
    }
  }

  Future<void> _clearListeners() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _onTokenRefreshSub?.cancel();
    _onMessageSub = null;
    _onMessageOpenedAppSub = null;
    _onTokenRefreshSub = null;
    _initializedUserId = null;
  }

  NotificationPayload? _extractPayload(RemoteMessage message) {
    if (message.data.isNotEmpty) {
      try {
        return NotificationPayload.fromJson(message.data);
      } catch (e) {
        debugPrint('Erro ao parsear payload: $e');
      }
    }
    return null;
  }

  Future<void> _saveTokenToDatabase(String userId, String token) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
    final snapshot = await userRef.get();
    final data = snapshot.data();

    final currentToken = data?['fcmToken'] as String?;
    final currentTokens = (data?['fcmTokens'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    final tokenChanged = currentToken != token;
    final tokenMissingInList = !currentTokens.contains(token);

    // Evita writes desnecessários: só atualiza quando existe mudança real.
    if (!tokenChanged && !tokenMissingInList) {
      return;
    }

    final payload = <String, dynamic>{};

    if (tokenChanged) {
      payload['fcmToken'] = token;
      payload['lastTokenUpdateAt'] = FieldValue.serverTimestamp();
    }

    if (tokenMissingInList) {
      payload['fcmTokens'] = FieldValue.arrayUnion([token]);
    }

    if (payload.isNotEmpty) {
      await userRef.set(payload, SetOptions(merge: true));
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final payload = _extractPayload(message);
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Notificações Importantes',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? payload?.title ?? 'Notificação',
      message.notification?.body ?? payload?.body ?? '',
      details,
      payload: payload != null ? jsonEncode(payload.toJson()) : null,
    );
  }

  Future<void> subscribeToCongregation(String congregationId) async {
    final topic = 'congregation_$congregationId';
    if (_subscribedTopics.contains(topic)) {
      return;
    }
    await _fcm.subscribeToTopic(topic);
    _subscribedTopics.add(topic);
  }

  Future<void> unsubscribeFromCongregation(String congregationId) async {
    final topic = 'congregation_$congregationId';
    if (!_subscribedTopics.contains(topic)) {
      return;
    }
    await _fcm.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
  }

  Future<void> subscribeToRole(String role) async {
    final topic = 'role_$role';
    if (_subscribedTopics.contains(topic)) {
      return;
    }
    await _fcm.subscribeToTopic(topic);
    _subscribedTopics.add(topic);
  }

  Future<void> unsubscribeFromRole(String role) async {
    final topic = 'role_$role';
    if (!_subscribedTopics.contains(topic)) {
      return;
    }
    await _fcm.unsubscribeFromTopic(topic);
    _subscribedTopics.remove(topic);
  }

  Future<void> _showBackgroundNotification(RemoteMessage message) async {
    final payload = _extractPayload(message);
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Notificações Importantes',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? payload?.title ?? 'Notificação',
      message.notification?.body ?? payload?.body ?? '',
      details,
      payload: payload != null ? jsonEncode(payload.toJson()) : null,
    );
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _notificationController.close();
  }
}
