import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'mail_classifier_service.dart';
import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/unified_email_service.dart';

// Gmail 邮件数据模型
class GmailMessage {
  final String id;
  final String? subject;
  final String? from;
  final DateTime? date;
  final String? snippet;
  final List<String> labelIds;

  GmailMessage({
    required this.id,
    this.subject,
    this.from,
    this.date,
    this.snippet,
    required this.labelIds,
  });

  factory GmailMessage.fromGmailApi(gmail.Message message) {
    String? subject;
    String? from;
    DateTime? date;

    if (message.payload?.headers != null) {
      for (final header in message.payload!.headers!) {
        if (header.name?.toLowerCase() == 'subject') {
          subject = header.value;
        } else if (header.name?.toLowerCase() == 'from') {
          from = header.value;
        } else if (header.name?.toLowerCase() == 'date') {
          try {
            date = DateTime.parse(header.value ?? '');
          } catch (e) {
            // 解析失败，使用当前时间
            date = DateTime.now();
          }
        }
      }
    }

    return GmailMessage(
      id: message.id ?? '',
      subject: subject,
      from: from,
      date: date,
      snippet: message.snippet,
      labelIds: message.labelIds ?? [],
    );
  }
}

class GmailService implements UnifiedEmailService {
  // 单例模式
  static final GmailService _instance = GmailService._internal();
  factory GmailService() => _instance;
  GmailService._internal();

  @override
  String get providerName => 'Gmail';

  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Gmail OAuth 配置
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '882147439216-jggb6lt25lhfea1lci9e0h6qgnadda4j.apps.googleusercontent.com',
    scopes: [
      'email',
      'https://www.googleapis.com/auth/gmail.modify',
    ],
  );

  String _key(String name) => 'gmail_$name';

  // 登录并获取授权
  Future<bool> login() async {
    try {
      // ignore: avoid_print
      print('[Gmail] 开始 OAuth 2.0 授权流程');

      // 尝试静默登录
      GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      
      // 如果静默登录失败，进行交互式登录
      if (account == null) {
        account = await _googleSignIn.signIn();
      }

      if (account == null) {
        // ignore: avoid_print
        print('[Gmail] 用户取消登录');
        return false;
      }

      // 获取认证信息
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;
      final String email = account.email;

      if (accessToken == null) {
        // ignore: avoid_print
        print('[Gmail] 无法获取访问令牌');
        return false;
      }

      // ignore: avoid_print
      print('[Gmail] 登录成功: $email');
      print('[Gmail] Access Token: ${accessToken.substring(0, 20)}...');

      // 存储凭证
      await _secureStorage.write(key: _key('email'), value: email);
      await _secureStorage.write(key: _key('access_token'), value: accessToken);
      await _secureStorage.write(key: _key('id_token'), value: auth.idToken);

      // 测试 Gmail API 访问
      final testSuccess = await _testGmailApi(accessToken);
      if (!testSuccess) {
        // ignore: avoid_print
        print('[Gmail] Gmail API 访问测试失败');
        return false;
      }

      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 登录失败: $e');
      return false;
    }
  }

  // 测试 Gmail API 访问
  Future<bool> _testGmailApi(String accessToken) async {
    try {
      // ignore: avoid_print
      print('[Gmail] 测试 Gmail API 访问...');

      final client = _createAuthenticatedClient(accessToken);
      final gmailApi = gmail.GmailApi(client);

      // 测试获取用户信息
      final profile = await gmailApi.users.getProfile('me');
      
      // ignore: avoid_print
      print('[Gmail] API 测试成功，邮箱: ${profile.emailAddress}');
      
      client.close();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] API 测试失败: $e');
      return false;
    }
  }

  // 创建已认证的 HTTP 客户端
  http.Client _createAuthenticatedClient(String accessToken) {
    return _AuthenticatedClient(accessToken);
  }

  // 获取存储的凭证 - 实现统一接口
  @override
  Future<Map<String, String>?> getStoredCredentials() async {
    final email = await _secureStorage.read(key: _key('email'));
    final accessToken = await _secureStorage.read(key: _key('access_token'));

    if (email != null && accessToken != null) {
      // ignore: avoid_print
      print('[Gmail] 找到已存储的凭证: $email');
      return {
        'email': email,
        'access_token': accessToken,
      };
    }

    // ignore: avoid_print
    print('[Gmail] 未找到存储的凭证');
    return null;
  }

  // 刷新访问令牌
  Future<String?> refreshAccessToken() async {
    try {
      final account = _googleSignIn.currentUser ?? await _googleSignIn.signInSilently();
      if (account == null) {
        // ignore: avoid_print
        print('[Gmail] 需要重新登录');
        return null;
      }

      final auth = await account.authentication;
      final accessToken = auth.accessToken;

      if (accessToken != null) {
        await _secureStorage.write(key: _key('access_token'), value: accessToken);
        // ignore: avoid_print
        print('[Gmail] 访问令牌已刷新');
      }

      return accessToken;
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 刷新访问令牌失败: $e');
      return null;
    }
  }

  // 获取并分类邮件 - 实现统一接口
  @override
  Future<Map<MailCategory, List<UnifiedEmailMessage>>> fetchAndClassifyEmails() async {
    final credentials = await getStoredCredentials();
    if (credentials == null) {
      throw Exception('No stored credentials found for Gmail');
    }

    String accessToken = credentials['access_token']!;
    
    try {
      return await _fetchEmailsWithToken(accessToken);
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 使用当前令牌获取邮件失败，尝试刷新令牌: $e');
      
      // 尝试刷新令牌
      final newToken = await refreshAccessToken();
      if (newToken == null) {
        throw Exception('Failed to refresh access token');
      }
      
      return await _fetchEmailsWithToken(newToken);
    }
  }

  Future<Map<MailCategory, List<UnifiedEmailMessage>>> _fetchEmailsWithToken(String accessToken) async {
    try {
      // ignore: avoid_print
      print('[Gmail] 开始获取邮件...');

      final client = _createAuthenticatedClient(accessToken);
      final gmailApi = gmail.GmailApi(client);

      final startTime = DateTime.now();

      // 获取最近 30 封邮件（不包括垃圾邮件和已删除）- 减少数量以提高速度
      final listResponse = await gmailApi.users.messages.list(
        'me',
        maxResults: 30,
        q: '-in:spam -in:trash', // 排除垃圾邮件和已删除
      );

      // ignore: avoid_print
      print('[Gmail] List API 耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms');

      final messages = <UnifiedEmailMessage>[];

      if (listResponse.messages != null && listResponse.messages!.isNotEmpty) {
        final batchStartTime = DateTime.now();
        
        // 使用并发请求批量获取邮件详情（每批 10 封）
        final batchSize = 10;
        for (var i = 0; i < listResponse.messages!.length; i += batchSize) {
          final end = (i + batchSize < listResponse.messages!.length) 
              ? i + batchSize 
              : listResponse.messages!.length;
          final batch = listResponse.messages!.sublist(i, end);

          // 并发获取这一批邮件
          final futures = batch.map((message) async {
            try {
              final fullMessage = await gmailApi.users.messages.get(
                'me',
                message.id!,
                format: 'metadata',
                metadataHeaders: ['Subject', 'From', 'Date'],
              );
              return _convertToUnifiedMessage(fullMessage);
            } catch (e) {
              // ignore: avoid_print
              print('[Gmail] 获取邮件 ${message.id} 失败: $e');
              return null;
            }
          }).toList();

          final batchResults = await Future.wait(futures);
          messages.addAll(batchResults.whereType<UnifiedEmailMessage>());
          
          // ignore: avoid_print
          print('[Gmail] 批次 ${i ~/ batchSize + 1} 完成，已获取 ${messages.length} 封邮件');
        }

        // ignore: avoid_print
        print('[Gmail] 批量获取耗时: ${DateTime.now().difference(batchStartTime).inMilliseconds}ms');
      }

      // ignore: avoid_print
      print('[Gmail] 成功获取 ${messages.length} 封邮件，总耗时: ${DateTime.now().difference(startTime).inMilliseconds}ms');

      client.close();

      // 分类邮件
      final classifier = MailClassifierService();
      final classifiedEmails = <MailCategory, List<UnifiedEmailMessage>>{
        MailCategory.socialMedia: [],
        MailCategory.promotions: [],
        MailCategory.other: [],
      };

      for (final message in messages) {
        final category = _classifyMessage(classifier, message);
        classifiedEmails[category]!.add(message);
      }

      return classifiedEmails;
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 获取邮件失败: $e');
      rethrow;
    }
  }

  // 转换 Gmail API 消息为统一消息模型
  UnifiedEmailMessage _convertToUnifiedMessage(gmail.Message gmailMessage) {
    String? subject;
    String? from;
    DateTime? date;

    if (gmailMessage.payload?.headers != null) {
      for (final header in gmailMessage.payload!.headers!) {
        if (header.name?.toLowerCase() == 'subject') {
          subject = header.value;
        } else if (header.name?.toLowerCase() == 'from') {
          from = header.value;
        } else if (header.name?.toLowerCase() == 'date') {
          try {
            date = DateTime.parse(header.value ?? '');
          } catch (e) {
            date = DateTime.now();
          }
        }
      }
    }

    return UnifiedEmailMessage(
      id: gmailMessage.id ?? '',
      subject: subject,
      from: UnifiedEmailMessage.extractName(from),
      fromEmail: UnifiedEmailMessage.extractEmail(from),
      date: date,
      snippet: gmailMessage.snippet,
      isRead: !(gmailMessage.labelIds?.contains('UNREAD') ?? false),
    );
  }

  // 分类邮件
  MailCategory _classifyMessage(MailClassifierService classifier, UnifiedEmailMessage message) {
    // 基于发件人和主题进行简单分类
    final from = (message.fromEmail ?? message.from ?? '').toLowerCase();
    final subject = (message.subject ?? '').toLowerCase();

    // 社交媒体关键词
    if (from.contains('facebook') || from.contains('twitter') || 
        from.contains('instagram') || from.contains('linkedin') ||
        from.contains('tiktok') || from.contains('snapchat')) {
      return MailCategory.socialMedia;
    }

    // 促销邮件关键词
    if (subject.contains('促销') || subject.contains('优惠') || 
        subject.contains('sale') || subject.contains('discount') ||
        subject.contains('offer') || subject.contains('deal') ||
        from.contains('noreply') || from.contains('newsletter')) {
      return MailCategory.promotions;
    }

    return MailCategory.other;
  }

  // 移动邮件到已删除目录 - 实现统一接口
  @override
  Future<void> moveEmailsToDeleted(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) {
      return;
    }

    final credentials = await getStoredCredentials();
    if (credentials == null) {
      throw Exception('No stored credentials found for Gmail');
    }

    String accessToken = credentials['access_token']!;
    
    try {
      await _moveEmailsToTrashWithToken(accessToken, emails);
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 使用当前令牌移动邮件失败，尝试刷新令牌: $e');
      
      final newToken = await refreshAccessToken();
      if (newToken == null) {
        throw Exception('Failed to refresh access token');
      }
      
      await _moveEmailsToTrashWithToken(newToken, emails);
    }
  }

  Future<void> _moveEmailsToTrashWithToken(String accessToken, List<UnifiedEmailMessage> emails) async {
    try {
      // ignore: avoid_print
      print('[Gmail] 移动 ${emails.length} 封邮件到垃圾箱...');

      final client = _createAuthenticatedClient(accessToken);
      final gmailApi = gmail.GmailApi(client);

      for (final email in emails) {
        await gmailApi.users.messages.trash('me', email.id);
      }

      // ignore: avoid_print
      print('[Gmail] 成功移动邮件到垃圾箱');
      
      client.close();
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 移动邮件到垃圾箱失败: $e');
      rethrow;
    }
  }

  // 永久删除邮件 - 实现统一接口
  @override
  Future<void> permanentlyDeleteEmails(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) {
      return;
    }

    final credentials = await getStoredCredentials();
    if (credentials == null) {
      throw Exception('No stored credentials found for Gmail');
    }

    String accessToken = credentials['access_token']!;
    
    try {
      await _permanentlyDeleteEmailsWithToken(accessToken, emails);
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 使用当前令牌删除邮件失败，尝试刷新令牌: $e');
      
      final newToken = await refreshAccessToken();
      if (newToken == null) {
        throw Exception('Failed to refresh access token');
      }
      
      await _permanentlyDeleteEmailsWithToken(newToken, emails);
    }
  }

  Future<void> _permanentlyDeleteEmailsWithToken(String accessToken, List<UnifiedEmailMessage> emails) async {
    try {
      // ignore: avoid_print
      print('[Gmail] 永久删除 ${emails.length} 封邮件...');

      final client = _createAuthenticatedClient(accessToken);
      final gmailApi = gmail.GmailApi(client);

      for (final email in emails) {
        await gmailApi.users.messages.delete('me', email.id);
      }

      // ignore: avoid_print
      print('[Gmail] 成功永久删除邮件');
      
      client.close();
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 永久删除邮件失败: $e');
      rethrow;
    }
  }

  // 退出登录 - 实现统一接口
  @override
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
      await _secureStorage.delete(key: _key('email'));
      await _secureStorage.delete(key: _key('access_token'));
      await _secureStorage.delete(key: _key('id_token'));
      
      // ignore: avoid_print
      print('[Gmail] 已退出登录，凭证已清除');
    } catch (e) {
      // ignore: avoid_print
      print('[Gmail] 退出登录失败: $e');
      rethrow;
    }
  }
}

// 自定义认证客户端
class _AuthenticatedClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._accessToken);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
