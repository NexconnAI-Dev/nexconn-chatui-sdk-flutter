import 'dart:async';

import 'package:ai_nexconn_chatui_plugin/ai_nexconn_chatui_plugin.dart';
import 'package:flutter/foundation.dart';

import '../utils/constants.dart';
import '../utils/http_util.dart';

class LoginProvider extends ChangeNotifier {
  final EngineProvider engineProvider;

  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _enableLocalNotification = true;
  String _currentUserId = '';
  String? _currentNickname;
  String? _errorMessage;
  int? _errorCode;

  LoginProvider({required this.engineProvider});

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get enableLocalNotification => _enableLocalNotification;
  String get currentUserId => _currentUserId;
  String? get currentNickname => _currentNickname;
  String? get errorMessage => _errorMessage;
  int? get errorCode => _errorCode;

  set enableLocalNotification(bool value) {
    if (_enableLocalNotification == value) return;
    _enableLocalNotification = value;
    notifyListeners();
  }

  void updateEnvironment(bool isTestEnv) {
    if (ExampleConstants.isTestEnv == isTestEnv) return;
    ExampleConstants.isTestEnv = isTestEnv;
    ExampleHTTPUtility().updateEnvironment();
    notifyListeners();
  }

  Future<void> sendVerificationCode({
    required String region,
    required String phone,
    String? pictureCode,
    String? pictureCodeId,
    required Future<void> Function(bool success) onSuccess,
    required Future<void> Function(String errorCode, String message) onError,
  }) async {
    try {
      final params = <String, String>{
        'region': region,
        'phone': phone,
        'picCodeId': pictureCodeId ?? '',
        'picCode': pictureCode ?? '',
      };
      final response = await ExampleHTTPUtility().request<Map<String, dynamic>>(
        HTTPMethod.post,
        'user/send_code_yp',
        data: params,
      );
      if (response.isSuccess) {
        await onSuccess(true);
        return;
      }
      final data = response.data;
      var message = response.message ?? 'Unknown Error';
      if (data is Map<String, dynamic> && data['msg'] is String) {
        message = data['msg'] as String;
      }
      await onError((response.httpCode ?? -1).toString(), message);
    } catch (error) {
      await onError('-1', error.toString());
    }
  }

  Future<void> loginWithPhone({
    required String phone,
    required String verificationCode,
    required String region,
  }) async {
    _isLoading = true;
    _isLoggedIn = false;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      final response = await ExampleHTTPUtility().request<Map<String, dynamic>>(
        HTTPMethod.post,
        'user/verify_code_register',
        data: <String, String>{
          'region': region,
          'phone': phone,
          'code': verificationCode,
        },
      );
      final responseData = response.data;
      final isSuccess =
          response.isSuccess &&
          responseData != null &&
          responseData['code'] == 200 &&
          responseData['result'] is Map<String, dynamic>;
      if (!isSuccess) {
        _errorMessage = _loginErrorMessage(response);
        _errorCode = response.httpCode;
        return;
      }
      final result = responseData['result'] as Map<String, dynamic>;
      await _connect(
        token: (result['token'] ?? '').toString(),
        fallbackUserId: (result['id'] ?? '').toString(),
        nickname: (result['nickName'] ?? result['nickname'] ?? '').toString(),
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithTokenShortcut(String tokenShortcut) async {
    final token = ExampleConstants.tokenByShortcut(tokenShortcut);
    if (token.isEmpty) {
      _errorCode = -1;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    _isLoading = true;
    _isLoggedIn = false;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      await _connect(
        token: token,
        fallbackUserId: _userIdForShortcut(tokenShortcut),
        nickname: null,
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loginWithCredentials({
    required String appKey,
    required String token,
    String? naviServer,
    String? fileServer,
    String? statisticServer,
    String fallbackUserId = 'connected_user',
  }) async {
    if (appKey.trim().isEmpty || token.trim().isEmpty) {
      _errorCode = -1;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isLoggedIn = false;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();

    try {
      await _connectWithInitParams(
        InitParams(
          appKey: appKey.trim(),
          naviServer: _emptyToNull(naviServer),
          fileServer: _emptyToNull(fileServer),
          statisticServer: _emptyToNull(statisticServer),
          enablePush: _enableLocalNotification,
        ),
        token: token.trim(),
        fallbackUserId: fallbackUserId,
        nickname: null,
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await engineProvider.disconnect();
    _isLoggedIn = false;
    _currentUserId = '';
    _currentNickname = null;
    notifyListeners();
  }

  Future<void> _connect({
    required String token,
    required String fallbackUserId,
    required String? nickname,
  }) async {
    if (token.isEmpty) {
      _errorMessage = 'Token is empty';
      _errorCode = -1;
      return;
    }
    await _connectWithInitParams(
      InitParams(
        appKey: ExampleConstants.appKey,
        naviServer: ExampleConstants.navServer,
        fileServer: ExampleConstants.fileServer,
        statisticServer: ExampleConstants.statsServer,
        enablePush: _enableLocalNotification,
      ),
      token: token,
      fallbackUserId: fallbackUserId,
      nickname: nickname,
    );
  }

  Future<void> _connectWithInitParams(
    InitParams initParams, {
    required String token,
    required String fallbackUserId,
    required String? nickname,
  }) async {
    await engineProvider.initialize(initParams);
    await NCEngine.registerCustomMessage(
      'ST:GrpNtf',
      CustomMessagePersistentFlag.persisted,
    );
    await engineProvider.setupLocalNotification(
      enable: _enableLocalNotification,
    );

    NCError? connectError;
    var connectedUserId = '';
    final completer = Completer<void>();
    final code = await engineProvider.connect(
      ConnectParams(token: token, timeout: 100),
      handler: (userId, error) {
        connectedUserId = userId ?? '';
        connectError = error;
        if (!completer.isCompleted) completer.complete();
      },
    );
    if (code != 0 && code != 34001) {
      _errorCode = code;
      _errorMessage = connectError?.message ?? '登录失败: $code';
      return;
    }
    await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    final errorCode = connectError?.code ?? 0;
    if (errorCode != 0 && errorCode != 34001) {
      _errorCode = errorCode;
      _errorMessage = connectError?.message ?? '登录失败: $errorCode';
      return;
    }
    _isLoggedIn = true;
    _currentUserId = connectedUserId.isEmpty ? fallbackUserId : connectedUserId;
    _currentNickname = nickname;
    engineProvider.updateCurrentUserId(_currentUserId);
  }

  String _loginErrorMessage(ExampleHTTPResult<Map<String, dynamic>> response) {
    final data = response.data;
    if (data != null && data['message'] is String) {
      return '错误码${data['code']} ${data['message']}';
    }
    return response.message ?? 'Unknown Error';
  }

  String _userIdForShortcut(String shortcut) {
    switch (shortcut.trim()) {
      case '1':
        return 'user1';
      case '2':
        return 'user2';
      case '3':
        return 'user3';
      default:
        return 'connected_user';
    }
  }

  String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
