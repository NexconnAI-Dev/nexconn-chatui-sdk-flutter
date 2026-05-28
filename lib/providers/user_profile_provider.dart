import 'dart:async';

import 'package:ai_nexconn_chat_plugin/ai_nexconn_chat_plugin.dart';
import 'package:flutter/foundation.dart';

import '../models/nexconn_user_profile.dart';

/// Loads a NexconnUserProfile for the requested user id.
typedef NexconnUserProfileResolver =
    FutureOr<NexconnUserProfile?> Function(String? userId);

/// Lightweight state manager for Nexconn user profiles.
///
/// By default, it falls back to the real `NCEngine.user` APIs when no resolver is provided:
/// current user uses `getMyUserProfile`; other users use `getUserProfiles`.
class NexconnUserProfileProvider with ChangeNotifier {
  String? _userId;
  NexconnUserProfile? _profile;
  bool _isLoading = false;
  String? _lastErrorMessage;
  int _requestVersion = 0;
  bool _disposed = false;

  /// Resolver used for target users other than the current user.
  final NexconnUserProfileResolver? profileResolver;

  /// Resolver used for the current user's profile.
  final NexconnUserProfileResolver? currentUserProfileResolver;

  NexconnUserProfileProvider({
    String? userId,
    NexconnUserProfile? initialProfile,
    this.profileResolver,
    this.currentUserProfileResolver,
    bool autoLoad = false,
  }) : _userId = userId,
       _profile = initialProfile {
    if (autoLoad) {
      unawaited(refresh());
    }
  }

  /// Target user id; null or empty means current user.
  String? get userId => _userId;

  /// Loaded profile data.
  NexconnUserProfile? get profile => _profile;

  /// Whether profile loading is in progress.
  bool get isLoading => _isLoading;

  /// Last profile loading error message.
  String? get lastErrorMessage => _lastErrorMessage;

  /// Whether profile data is available.
  bool get hasProfile => _profile != null;

  /// Whether [userId] points to the current user.
  bool get isCurrentUser => _isCurrentUser(_userId);

  /// Loads a profile without replacing provider state.
  Future<NexconnUserProfile?> getUserProfile({String? userId}) {
    return _fetchProfile(userId ?? _userId);
  }

  /// Refreshes state and returns the loaded profile.
  Future<NexconnUserProfile?> fetch({String? userId}) async {
    await refresh(userId: userId);
    return _profile;
  }

  /// Reloads profile data for [userId] or the current target.
  Future<void> refresh({String? userId}) async {
    if (_disposed) {
      return;
    }
    if (userId != null) {
      _userId = userId;
    }
    final effectiveUserId = _userId;
    final version = ++_requestVersion;

    _isLoading = true;
    _lastErrorMessage = null;
    _safeNotifyListeners();

    var shouldNotify = false;
    try {
      final profile = await _fetchProfile(effectiveUserId);
      if (_disposed || version != _requestVersion) {
        return;
      }
      _profile = profile;
      _lastErrorMessage = null;
    } catch (error) {
      if (_disposed || version != _requestVersion) {
        return;
      }
      _lastErrorMessage = error.toString();
    } finally {
      shouldNotify = !_disposed && version == _requestVersion;
    }

    if (shouldNotify) {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Updates the target user id without loading immediately.
  void updateUserId(String? userId) {
    if (_disposed) {
      return;
    }
    if (_userId == userId) {
      return;
    }
    _userId = userId;
    _safeNotifyListeners();
  }

  Future<NexconnUserProfile?> _fetchProfile(String? userId) {
    if (_isCurrentUser(userId)) {
      final resolver = currentUserProfileResolver;
      if (resolver != null) {
        return Future.sync(() => resolver(null));
      }
      return _defaultCurrentUserProfileResolver();
    }

    final resolver = profileResolver;
    if (resolver != null) {
      return Future.sync(() => resolver(userId));
    }
    return _defaultUserProfileResolver(userId);
  }

  Future<NexconnUserProfile?> _defaultCurrentUserProfileResolver() async {
    final completer = Completer<NexconnUserProfile?>();
    await NCEngine.user.getMyUserProfile((profile, error) {
      if (error != null && error.code != 0) {
        completer.completeError(
          error.message ?? 'Failed to load user profile',
          StackTrace.current,
        );
        return;
      }
      completer.complete(
        profile == null ? null : NexconnUserProfile.fromSdk(profile),
      );
    });
    return completer.future;
  }

  Future<NexconnUserProfile?> _defaultUserProfileResolver(
    String? userId,
  ) async {
    if (userId == null || userId.trim().isEmpty) {
      return null;
    }
    final completer = Completer<NexconnUserProfile?>();
    await NCEngine.user.getUserProfiles([userId], (profiles, error) {
      if (error != null && error.code != 0) {
        completer.completeError(
          error.message ?? 'Failed to load user profile',
          StackTrace.current,
        );
        return;
      }
      final profile = profiles?.isNotEmpty == true ? profiles!.first : null;
      completer.complete(
        profile == null ? null : NexconnUserProfile.fromSdk(profile),
      );
    });
    return completer.future;
  }

  bool _isCurrentUser(String? userId) {
    return userId == null || userId.trim().isEmpty;
  }

  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
