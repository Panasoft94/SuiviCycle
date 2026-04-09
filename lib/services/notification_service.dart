import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_intent_plus/android_intent.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  bool _isReady = false;
  bool get isReady => _isReady;

  Future<void> init() async {
    try {
      tz.initializeTimeZones();

      // FlutterTimezone.getLocalTimezone() retourne TimezoneInfo en v5.x
      // On accède à .identifier pour obtenir le nom du fuseau horaire
      String locationName;
      try {
        final timezoneInfo = await FlutterTimezone.getLocalTimezone();
        locationName = timezoneInfo.identifier;
      } catch (_) {
        // Fallback si la détection du fuseau échoue
        locationName = 'Africa/Kinshasa';
      }

      tz.setLocalLocation(tz.getLocation(locationName));

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings =
      InitializationSettings(android: androidSettings, iOS: iosSettings);

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (kDebugMode) {
            print('Notification tap: ${response.payload}');
          }
        },
      );

      await _requestPermissions();
      await _checkExactAlarmPermission();

      _isReady = true;
      if (kDebugMode) print('✅ NotificationService prêt (timezone: $locationName)');
    } catch (e, stack) {
      debugPrint('❌ Erreur init NotificationService: $e');
      debugPrintStack(stackTrace: stack);
      // Tenter une initialisation minimale même en cas d'erreur
      await _tryMinimalInit();
    }
  }

  /// Initialisation de secours si l'init principale échoue
  Future<void> _tryMinimalInit() async {
    try {
      if (_isReady) return;

      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Africa/Kinshasa'));

      const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
      InitializationSettings(android: androidSettings);

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
      await _requestPermissions();

      _isReady = true;
      if (kDebugMode) print('⚠️ NotificationService initialisé en mode fallback');
    } catch (e) {
      debugPrint('❌ Échec total de l\'init NotificationService: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final androidImpl = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final iosImpl = flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
            alert: true, badge: true, sound: true);
      }
    } catch (e) {
      debugPrint('❌ Erreur permissions: $e');
    }
  }

  Future<void> _checkExactAlarmPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 31) {
          final androidImpl = flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
          final granted = await androidImpl?.canScheduleExactNotifications();
          if (granted != null && !granted) {
            const intent = AndroidIntent(
                action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM');
            await intent.launch();
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur exact alarm permission: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isReady) {
      if (kDebugMode) print('❌ Service non prêt. Notification #$id ignorée.');
      return;
    }

    // Programmer à 9h00 le matin du jour cible
    var scheduledTZDate = tz.TZDateTime(
      tz.local,
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9,
      0,
    );

    final now = tz.TZDateTime.now(tz.local);

    // Si la date est passée, ignorer silencieusement
    if (scheduledTZDate.isBefore(now)) {
      if (kDebugMode) print('⚠️ Notification #$id ignorée car la date est passée: $scheduledTZDate');
      return;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'cycle_channel_id',
        'Cycle Notifications',
        channelDescription: 'Notifications liées au suivi de cycle.',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      if (kDebugMode) {
        print('✅ Notification #$id planifiée pour $scheduledTZDate');
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur planification notification #$id: $e');
      debugPrintStack(stackTrace: stack);
    }
  }

  Future<void> cancelNotification(int id) async {
    if (!_isReady) {
      if (kDebugMode) print('❌ Service non prêt. Annulation ignorée.');
      return;
    }
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      if (kDebugMode) print('🔔 Notification #$id annulée.');
    } catch (e) {
      debugPrint('❌ Erreur annulation notification #$id: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_isReady) {
      if (kDebugMode) print('❌ Service non prêt. Annulation globale ignorée.');
      return;
    }

    try {
      await flutterLocalNotificationsPlugin.cancelAll();
      if (kDebugMode) print('🔔 Toutes les notifications annulées.');
    } catch (e, stack) {
      debugPrint('❌ Erreur cancelAllNotifications: $e');
      debugPrintStack(stackTrace: stack);
    }
  }
}