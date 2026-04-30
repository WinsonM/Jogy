import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/datasources/remote_data_source.dart';
import '../../data/models/activity_notification_model.dart';

class NotificationProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const int pageSize = 20;
  static const Duration pollInterval = Duration(seconds: 60);

  final RemoteDataSource _remote;

  NotificationProvider({required RemoteDataSource remoteDataSource})
    : _remote = remoteDataSource;

  final List<ActivityNotificationModel> _notifications = [];
  List<ActivityNotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isRefreshing = false;
  bool get isRefreshing => _isRefreshing;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  Timer? _pollTimer;
  bool _pollingStarted = false;
  int _offset = 0;

  void startPolling() {
    if (_pollingStarted) return;
    _pollingStarted = true;
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshUnreadCount());
    _pollTimer = Timer.periodic(
      pollInterval,
      (_) => unawaited(refreshUnreadCount()),
    );
  }

  void stopPolling() {
    if (!_pollingStarted) return;
    _pollingStarted = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshUnreadCount());
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final unread = await _remote.fetchNotificationUnreadCount();
      if (_unreadCount != unread || _error != null) {
        _unreadCount = unread;
        _error = null;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    if (_isLoading || _isRefreshing) return;

    _isLoading = _notifications.isEmpty;
    _isRefreshing = _notifications.isNotEmpty;
    _error = null;
    notifyListeners();

    try {
      final page = await _remote.fetchNotifications(limit: pageSize, offset: 0);
      _notifications
        ..clear()
        ..addAll(page.notifications);
      _offset = _notifications.length;
      _hasMore = page.notifications.length == pageSize;
      _unreadCount = page.unreadCount;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _remote.fetchNotifications(
        limit: pageSize,
        offset: _offset,
      );
      final seen = _notifications.map((item) => item.id).toSet();
      _notifications.addAll(
        page.notifications.where((item) => seen.add(item.id)),
      );
      _offset += page.notifications.length;
      _hasMore = page.notifications.length == pageSize;
      _unreadCount = page.unreadCount;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> markRead(ActivityNotificationModel item) async {
    if (item.isRead) return;

    final index = _notifications.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    final original = _notifications[index];
    _notifications[index] = original.copyWith(readAt: DateTime.now());
    _unreadCount = math.max(0, _unreadCount - 1);
    notifyListeners();

    try {
      await _remote.markNotificationRead(item.id);
    } catch (e) {
      _notifications[index] = original;
      _unreadCount++;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0) return;

    final originals = List<ActivityNotificationModel>.from(_notifications);
    final readAt = DateTime.now();
    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(readAt: readAt);
      }
    }
    final previousUnread = _unreadCount;
    _unreadCount = 0;
    notifyListeners();

    try {
      await _remote.markAllNotificationsRead();
    } catch (e) {
      _notifications
        ..clear()
        ..addAll(originals);
      _unreadCount = previousUnread;
      _error = e.toString();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
