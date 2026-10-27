import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/models/app_notification.dart';
import 'sqlite_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<AppNotification>> notificationsNotifier =
      ValueNotifier<List<AppNotification>>([]);

  OverlayEntry? _currentBannerEntry;
  Timer? _dismissTimer;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const LinuxInitializationSettings linuxSettings =
          LinuxInitializationSettings(defaultActionName: 'Open notification');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Request permission on Android 13+ (Tiramisu)
      final androidImplementation = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      // Load cached notifications from local SQLite
      await loadNotifications();

      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  Future<void> loadNotifications() async {
    try {
      var list = await SqliteService.instance.getNotifications();

      // Seed awal jika masih kosong agar menu notifikasi langsung terlihat estetik
      if (list.isEmpty) {
        final initialSeeds = [
          AppNotification(
            id: 'notif-seed-1',
            title: '🌱 Selamat Bergabung di TrashQuest!',
            body: 'Mulai petualangan pilah sampahmu hari ini. Dapatkan XP dan tukarkan dengan saldo serta sembako gratis!',
            type: NotificationType.system,
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            isRead: false,
          ),
          AppNotification(
            id: 'notif-seed-2',
            title: '🎯 Tantangan Harian Siap!',
            body: 'Pilah 5 sampah hari ini untuk mendapatkan bonus +50 XP ekstra.',
            type: NotificationType.mission,
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            isRead: false,
          ),
        ];

        for (final n in initialSeeds) {
          await SqliteService.instance.insertNotification(n);
        }
        list = await SqliteService.instance.getNotifications();
      }

      notificationsNotifier.value = list;
      unreadCountNotifier.value = list.where((n) => !n.isRead).length;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Menampilkan notifikasi ke HP (System Notification Tray) + Floating In-App Banner + SQLite Storage
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    NotificationType type = NotificationType.system,
    IconData? icon,
    Color? iconColor,
    bool showInAppBanner = false,
  }) async {
    // Tentukan icon & warna default sesuai kategori jika tidak dispesifikasikan
    final resolvedIcon = icon ?? type.icon;
    final resolvedColor = iconColor ?? type.color;

    // 1. Simpan ke database lokal permanen
    final notif = AppNotification(
      id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      isRead: false,
    );

    await SqliteService.instance.insertNotification(notif);
    final updatedList = [notif, ...notificationsNotifier.value];
    notificationsNotifier.value = updatedList;
    unreadCountNotifier.value = updatedList.where((n) => !n.isRead).length;

    // 2. Getar haptik halus
    HapticFeedback.lightImpact();

    // 3. Tampilkan di System Notification Shade (Status bar HP)
    if (_isInitialized) {
      try {
        final androidDetails = AndroidNotificationDetails(
          'trashquest_main_channel',
          'TrashQuest Notifikasi Real-Time',
          channelDescription: 'Pemberitahuan misi, poin, reward, dan aktivitas daur ulang',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF10B981),
        );

        const darwinDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        );

        final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await _localNotifications.show(
          id: notificationId,
          title: title,
          body: body,
          notificationDetails: notificationDetails,
          payload: payload,
        );
      } catch (e) {
        debugPrint('Error showing system notification: $e');
      }
    }

    // 4. Tampilkan Heads-Up Floating In-App Banner (Pop-up di atas layar tab)
    if (showInAppBanner) {
      _showInAppFloatingBanner(
        title: title,
        body: body,
        icon: resolvedIcon,
        iconColor: resolvedColor,
      );
    }
  }

  /// Tandai satu notifikasi sebagai sudah dibaca
  Future<void> markAsRead(String id) async {
    await SqliteService.instance.markNotificationAsRead(id);
    final updated = notificationsNotifier.value.map((n) {
      return n.id == id ? n.copyWith(isRead: true) : n;
    }).toList();
    notificationsNotifier.value = updated;
    unreadCountNotifier.value = updated.where((n) => !n.isRead).length;
  }

  /// Tandai semua notifikasi telah dibaca
  Future<void> markAllAsRead() async {
    await SqliteService.instance.markAllNotificationsAsRead();
    final updated = notificationsNotifier.value.map((n) => n.copyWith(isRead: true)).toList();
    notificationsNotifier.value = updated;
    unreadCountNotifier.value = 0;
  }

  /// Hapus satu notifikasi dari riwayat
  Future<void> deleteNotification(String id) async {
    await SqliteService.instance.deleteNotification(id);
    final updated = notificationsNotifier.value.where((n) => n.id != id).toList();
    notificationsNotifier.value = updated;
    unreadCountNotifier.value = updated.where((n) => !n.isRead).length;
  }

  /// Hapus seluruh riwayat notifikasi
  Future<void> clearAll() async {
    await SqliteService.instance.deleteAllNotifications();
    notificationsNotifier.value = [];
    unreadCountNotifier.value = 0;
  }

  /// Floating In-App Heads-up Notification Card (Meluncur dari atas layar)
  void _showInAppFloatingBanner({
    required String title,
    required String body,
    required IconData icon,
    required Color iconColor,
  }) {
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // Bersihkan banner sebelumnya jika masih muncul
    _currentBannerEntry?.remove();
    _currentBannerEntry = null;
    _dismissTimer?.cancel();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _InAppNotificationWidget(
        title: title,
        body: body,
        icon: icon,
        iconColor: iconColor,
        onDismiss: () {
          entry.remove();
          if (_currentBannerEntry == entry) _currentBannerEntry = null;
        },
      ),
    );

    _currentBannerEntry = entry;
    overlayState.insert(entry);

    // Auto dismiss dalam 4.2 detik
    _dismissTimer = Timer(const Duration(milliseconds: 4200), () {
      if (_currentBannerEntry == entry) {
        entry.remove();
        _currentBannerEntry = null;
      }
    });
  }
}

class _InAppNotificationWidget extends StatefulWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDismiss;

  const _InAppNotificationWidget({
    required this.title,
    required this.body,
    required this.icon,
    required this.iconColor,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationWidget> createState() => _InAppNotificationWidgetState();
}

class _InAppNotificationWidgetState extends State<_InAppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _animController.forward();
  }

  void _dismissWithAnim() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top > 0 ? mediaQuery.padding.top + 6 : 16.0;

    return Positioned(
      top: topPadding,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: _slideAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismissWithAnim,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.iconColor.withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Glow Icon Circle
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.iconColor.withValues(alpha: 0.2),
                          border: Border.all(
                            color: widget.iconColor.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            color: widget.iconColor,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Text Content
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Baru saja',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.45),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.body,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Close indicator
                      GestureDetector(
                        onTap: _dismissWithAnim,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
