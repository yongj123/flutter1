import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/unified_email_service.dart';
import 'package:flutter1/src/services/mail_classifier_service.dart';
import 'package:flutter1/src/services/auth_service.dart';

/// Outlook 服务适配器
/// 将 Outlook/Microsoft Graph API 适配到统一的邮件服务接口
class OutlookEmailServiceAdapter implements UnifiedEmailService {
  final AuthService _authService = AuthService();
  String? _cachedAccessToken;

  @override
  String get providerName => 'Outlook';

  @override
  Future<Map<MailCategory, List<UnifiedEmailMessage>>> fetchAndClassifyEmails() async {
    final accessToken = await _getAccessToken();
    
    // 获取邮件
    final emails = await _fetchMails(accessToken);
    
    // 分类
    return _classifyEmails(emails);
  }

  @override
  Future<void> moveEmailsToDeleted(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) return;

    final accessToken = await _getAccessToken();
    
    for (final email in emails) {
      await _moveMailToDeletedItems(accessToken, email.id);
    }
  }

  @override
  Future<void> permanentlyDeleteEmails(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) return;

    final accessToken = await _getAccessToken();
    
    for (final email in emails) {
      await _deleteMail(accessToken, email.id);
    }
  }

  @override
  Future<void> logout() async {
    await _authService.logout();
    _cachedAccessToken = null;
  }

  @override
  Future<Map<String, String>?> getStoredCredentials() async {
    try {
      final token = await _authService.acquireTokenSilently();
      if (token != null) {
        return {'access_token': token};
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Outlook] Failed to get stored credentials: $e');
    }
    return null;
  }

  /// 获取访问令牌
  Future<String> _getAccessToken() async {
    if (_cachedAccessToken != null) {
      return _cachedAccessToken!;
    }

    // 尝试静默获取
    String? token = await _authService.acquireTokenSilently();
    
    // 如果失败，交互式获取
    if (token == null) {
      token = await _authService.acquireToken();
    }

    if (token == null) {
      throw Exception('Failed to acquire access token');
    }

    _cachedAccessToken = token;
    return token;
  }

  /// 获取邮件列表
  Future<List<Map<String, dynamic>>> _fetchMails(String accessToken) async {
    final response = await http.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/mailFolders/inbox/messages?\$top=30'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['value']);
    } else {
      throw Exception('Failed to load mails: ${response.statusCode}');
    }
  }

  /// 移动邮件到已删除文件夹
  Future<void> _moveMailToDeletedItems(String accessToken, String mailId) async {
    final response = await http.post(
      Uri.parse('https://graph.microsoft.com/v1.0/me/messages/$mailId/move'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({'destinationId': 'deleteditems'}),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to move mail: ${response.statusCode}');
    }
  }

  /// 永久删除邮件
  Future<void> _deleteMail(String accessToken, String mailId) async {
    final response = await http.delete(
      Uri.parse('https://graph.microsoft.com/v1.0/me/messages/$mailId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete mail: ${response.statusCode}');
    }
  }

  /// 分类邮件
  Map<MailCategory, List<UnifiedEmailMessage>> _classifyEmails(
      List<Map<String, dynamic>> mails) {
    final result = <MailCategory, List<UnifiedEmailMessage>>{
      MailCategory.socialMedia: [],
      MailCategory.promotions: [],
      MailCategory.other: [],
    };

    for (final mail in mails) {
      final unifiedMsg = _convertToUnifiedMessage(mail);
      final category = _classifyMessage(unifiedMsg);
      result[category]!.add(unifiedMsg);
    }

    return result;
  }

  /// 转换 Graph API JSON 数据为 UnifiedEmailMessage
  UnifiedEmailMessage _convertToUnifiedMessage(Map<String, dynamic> mail) {
    // 提取发件人信息
    String? fromName;
    String? fromEmail;
    
    if (mail['sender'] != null && mail['sender']['emailAddress'] != null) {
      final sender = mail['sender']['emailAddress'];
      fromName = sender['name'];
      fromEmail = sender['address'];
    } else if (mail['from'] != null && mail['from']['emailAddress'] != null) {
      final from = mail['from']['emailAddress'];
      fromName = from['name'];
      fromEmail = from['address'];
    }

    // 提取日期
    DateTime? date;
    if (mail['receivedDateTime'] != null) {
      try {
        date = DateTime.parse(mail['receivedDateTime']);
      } catch (e) {
        // ignore: avoid_print
        print('[Outlook] Failed to parse date: $e');
      }
    }

    return UnifiedEmailMessage(
      id: mail['id'] ?? '',
      subject: mail['subject'],
      from: fromName,
      fromEmail: fromEmail,
      date: date,
      snippet: mail['bodyPreview'],
      isRead: mail['isRead'] ?? false,
    );
  }

  /// 分类邮件
  MailCategory _classifyMessage(UnifiedEmailMessage message) {
    final from = (message.fromEmail ?? message.from ?? '').toLowerCase();
    final subject = (message.subject ?? '').toLowerCase();

    // 社交媒体关键词
    if (from.contains('facebook') || from.contains('twitter') || 
        from.contains('instagram') || from.contains('linkedin') ||
        from.contains('tiktok') || from.contains('snapchat')) {
      return MailCategory.socialMedia;
    }

    // 促销邮件关键词
    if (subject.contains('promotion') || subject.contains('sale') || 
        subject.contains('discount') || subject.contains('offer') ||
        subject.contains('deal') || from.contains('noreply') || 
        from.contains('newsletter')) {
      return MailCategory.promotions;
    }

    return MailCategory.other;
  }
}

