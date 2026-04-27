import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/remote_data_source.dart';
import '../../data/models/user_model.dart';

/// Key names for secure storage
const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kExpiresAt = 'expires_at'; // Unix timestamp in seconds

/// Centralized auth state manager.
///
/// Responsibilities:
/// - Persist access / refresh tokens in secure storage
/// - Expose reactive [isLoggedIn] / [currentUser] state via [ChangeNotifier]
/// - Auto-refresh access token before it expires
/// - Provide [login], [register], [logout] one-liners for UI
class AuthService extends ChangeNotifier {
  final RemoteDataSource _remote;
  final FlutterSecureStorage _storage;

  Timer? _refreshTimer;
  bool _loggedIn = false;
  UserModel? _currentUser;
  String? _currentUserId;

  bool get isLoggedIn => _loggedIn;
  UserModel? get currentUser => _currentUser;
  String? get currentUserId => _currentUserId ?? _currentUser?.id;

  AuthService({
    required RemoteDataSource remoteDataSource,
    FlutterSecureStorage? storage,
  }) : _remote = remoteDataSource,
       _storage = storage ?? const FlutterSecureStorage();

  // ==================== Bootstrap ====================

  /// Called once from main.dart at startup.
  /// Reads stored tokens and restores the session silently.
  Future<void> init() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    final expiresAtStr = await _storage.read(key: _kExpiresAt);

    if (accessToken == null || refreshToken == null) {
      // No saved session
      return;
    }

    // Check if the access token is still valid
    final expiresAt = int.tryParse(expiresAtStr ?? '') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (expiresAt > now + 60) {
      // Token still valid (with 60s margin) — use it directly
      _remote.setAuthToken(accessToken);
      _loggedIn = true;
      _currentUserId = _userIdFromAccessToken(accessToken);
      _scheduleRefresh(expiresAt - now);
      notifyListeners();
      // Fetch user profile in background (non-blocking)
      _fetchCurrentUser();
    } else {
      // Token expired or about to expire — try refresh
      try {
        await _doRefresh(refreshToken);
      } catch (_) {
        // Refresh failed — clear everything, user will see login page
        await _clearStorage();
      }
    }
  }

  // ==================== Public API ====================

  /// Login with username/email + password.
  /// Returns the current user on success.
  Future<UserModel> login(String identifier, String password) async {
    final data = await _remote.login(identifier, password);
    await _handleTokenResponse(data);

    // Fetch user profile
    _currentUser = await _remote.getCurrentUser();
    _currentUserId = _currentUser?.id ?? _currentUserId;
    notifyListeners();
    return _currentUser!;
  }

  /// Register a new account.
  ///
  /// If the backend returns tokens (new /register contract: `RegisterResponse`
  /// with `access_token`, `refresh_token`, and nested `user`), the session is
  /// started immediately — `isLoggedIn` becomes true and listeners are notified
  /// so the UI can transition to the home page without a second /login call.
  ///
  /// If the backend still returns a bare user object (legacy contract), the
  /// call succeeds silently and the caller is expected to navigate to the
  /// login page as before.
  Future<void> register(
    String username,
    String password, {
    String? email,
  }) async {
    final data = await _remote.register(username, password, email: email);

    // New contract: tokens present → auto-login
    if (data.containsKey('access_token')) {
      await _handleTokenResponse(data);
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        _currentUser = UserModel.fromJson(userJson);
        _currentUserId = _currentUser?.id ?? _currentUserId;
      }
      notifyListeners();
    }
  }

  /// Send email verification code.
  Future<void> sendCode(String email) async {
    await _remote.sendCode(email);
  }

  /// Verify email code.
  Future<void> verifyCode(String email, String code) async {
    await _remote.verifyCode(email, code);
  }

  /// Replace the cached current user after profile edits.
  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    _currentUserId = user.id;
    notifyListeners();
  }

  /// Logout — clear tokens, reset state.
  Future<void> logout() async {
    try {
      await _remote.logout();
    } catch (_) {
      // Ignore server error; we clear locally anyway
    }
    _remote.clearAuthToken();
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _loggedIn = false;
    _currentUser = null;
    _currentUserId = null;
    await _clearStorage();
    notifyListeners();
  }

  // ==================== Token Handling ====================

  Future<void> _handleTokenResponse(Map<String, dynamic> data) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final expiresIn = data['expires_in'] as int; // seconds

    final expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + expiresIn;

    // Persist
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kExpiresAt, value: expiresAt.toString());

    // Apply to HTTP client
    _remote.setAuthToken(accessToken);
    _loggedIn = true;
    _currentUserId =
        _userIdFromTokenResponse(data) ??
        _userIdFromAccessToken(accessToken) ??
        _currentUserId;

    // Schedule auto-refresh
    _scheduleRefresh(expiresIn);
  }

  void _scheduleRefresh(int secondsUntilExpiry) {
    _refreshTimer?.cancel();
    // Refresh 2 minutes before expiry (or immediately if < 2 min left)
    final delay = (secondsUntilExpiry - 120).clamp(0, secondsUntilExpiry);
    _refreshTimer = Timer(Duration(seconds: delay), _onRefreshTimer);
  }

  Future<void> _onRefreshTimer() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return;
    try {
      await _doRefresh(refreshToken);
    } catch (_) {
      // Refresh failed — session expired
      await logout();
    }
  }

  Future<void> _doRefresh(String refreshToken) async {
    final data = await _remote.refreshToken(refreshToken);
    await _handleTokenResponse(data);
    notifyListeners();
  }

  Future<void> _clearStorage() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiresAt);
  }

  Future<void> _fetchCurrentUser() async {
    try {
      _currentUser = await _remote.getCurrentUser();
      _currentUserId = _currentUser?.id ?? _currentUserId;
      notifyListeners();
    } catch (_) {
      // Non-critical — user info will be fetched later
    }
  }

  String? _userIdFromTokenResponse(Map<String, dynamic> data) {
    final userJson = data['user'];
    if (userJson is Map<String, dynamic>) {
      return userJson['id']?.toString();
    }
    return null;
  }

  String? _userIdFromAccessToken(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final payloadJson = jsonDecode(payload);
      if (payloadJson is Map<String, dynamic>) {
        return payloadJson['sub']?.toString();
      }
    } catch (_) {
      // Invalid or non-JWT token. Keep the hydrated user fallback.
    }
    return null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
