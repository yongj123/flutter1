import 'package:msal_flutter/msal_flutter.dart';

class AuthService {
  // 单例模式
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _authority =
      'https://login.microsoftonline.com/consumers';
  static const String _clientId = '86007572-eeff-49fb-88b9-8dd0f65ce0e7';
  static const List<String> _scopes = ['Mail.ReadWrite', 'User.Read'];

  PublicClientApplication? _pca;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    
    try {
      _pca = await PublicClientApplication.createPublicClientApplication(
        _clientId,
        authority: _authority,
        iosRedirectUri: 'msauth.com.example.iosAiCleaner://auth',
      );
      _initialized = true;
      // ignore: avoid_print
      print('AuthService initialized successfully');
    } catch (e) {
      // ignore: avoid_print
      print('Error initializing AuthService: $e');
      rethrow;
    }
  }

  Future<bool> hasAccount() async {
    if (_pca == null) {
      await init();
    }
    try {
      // 尝试静默获取token，如果成功说明有账户
      final token = await _pca!.acquireTokenSilent(_scopes);
      return token.isNotEmpty;
    } catch (e) {
      // ignore: avoid_print
      print('No cached account found: $e');
      return false;
    }
  }

  Future<String?> acquireToken() async {
    if (_pca == null) {
      await init();
    }
    try {
      final result = await _pca!.acquireToken(_scopes);
      // ignore: avoid_print
      print('Token acquired successfully');
      return result;
    } catch (e) {
      // ignore: avoid_print
      print('Error acquiring token: $e');
      return null;
    }
  }

  Future<String?> acquireTokenSilently() async {
    if (_pca == null) {
      await init();
    }
    try {
      final token = await _pca!.acquireTokenSilent(_scopes);
      if (token.isNotEmpty) {
        // ignore: avoid_print
        print('Token acquired silently');
        return token;
      }
      // ignore: avoid_print
      print('Silent token acquisition returned empty token');
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('Silent token acquisition failed: $e');
      return null;
    }
  }

  Future<void> logout() async {
    if (_pca == null) {
      return;
    }
    try {
      await _pca!.logout();
      // ignore: avoid_print
      print('Logged out successfully');
    } catch (e) {
      // ignore: avoid_print
      print('Error during logout: $e');
    }
  }
}