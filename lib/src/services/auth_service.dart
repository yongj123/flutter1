import 'package:msal_flutter/msal_flutter.dart';

class AuthService {
  static const String _authority =
      'https://login.microsoftonline.com/consumers';
  static const String _clientId = '86007572-eeff-49fb-88b9-8dd0f65ce0e7';
  static const List<String> _scopes = ['Mail.ReadWrite'];

  PublicClientApplication? _pca;

  Future<void> init() async {
    _pca = await PublicClientApplication.createPublicClientApplication(
      _clientId,
      authority: _authority,
      iosRedirectUri: 'msauth.com.example.iosAiCleaner://auth',
    );
  }

  Future<String?> acquireToken() async {
    if (_pca == null) {
      return null;
    }
    try {
      final result = await _pca!.acquireToken(_scopes);
      return result;
    } catch (e) {
      print('Error acquiring token: $e');
      return null;
    }
  }

  Future<void> logout() async {
    if (_pca == null) {
      return;
    }
    await _pca!.logout();
  }
}