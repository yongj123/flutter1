import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mail_classifier_service.dart';

class ImapService {
  // 单例模式
  static final ImapService _instance = ImapService._internal();
  factory ImapService() => _instance;
  ImapService._internal();

  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  String _key(String provider, String name) => '${provider.toLowerCase()}_imap_$name';

  Future<bool> login(String provider, String email, String password, String host, int port, bool isSecure) async {
    // ignore: avoid_print
    print('[$provider] 尝试登录: $email @ $host:$port (SSL: $isSecure)');
    
    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: email,
      password: password,
      incomingHost: host,
      outgoingHost: host, // Assuming outgoing host is the same as incoming
      incomingPort: port,
      incomingSocketType: isSecure ? SocketType.ssl : SocketType.starttls,
    );
    final client = MailClient(account, isLogEnabled: true);
    try {
      await client.connect();
      
      // 存储凭证到安全存储
      await _secureStorage.write(key: _key(provider, 'email'), value: email);
      await _secureStorage.write(key: _key(provider, 'password'), value: password);
      await _secureStorage.write(key: _key(provider, 'host'), value: host);
      await _secureStorage.write(key: _key(provider, 'port'), value: port.toString());
      await _secureStorage.write(key: _key(provider, 'isSecure'), value: isSecure.toString());
      
      await client.disconnect();
      
      // ignore: avoid_print
      print('[$provider] 登录成功，凭证已安全存储');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] 登录失败: $e');
      return false;
    }
  }

  Future<Map<MailCategory, List<MimeMessage>>> fetchAndClassifyEmails(String provider) async {
    final credentials = await _getCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }
    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: credentials['email']!,
      password: credentials['password']!,
      incomingHost: credentials['host']!,
      outgoingHost: credentials['host']!, // Assuming outgoing host is the same as incoming
      incomingPort: int.parse(credentials['port']!),
      incomingSocketType: credentials['isSecure'] == 'true' ? SocketType.ssl : SocketType.starttls,
    );
    final client = MailClient(account, isLogEnabled: true);
    try {
      await client.connect();
      await client.selectInbox();
      final messages = await client.fetchMessages(count: 100);

      final classifier = MailClassifierService();
      final classifiedEmails = <MailCategory, List<MimeMessage>>{
        MailCategory.socialMedia: [],
        MailCategory.promotions: [],
        MailCategory.other: [],
      };

      for (final email in messages) {
        final category = classifier.classify(email);
        classifiedEmails[category]!.add(email);
      }

      await client.disconnect();
      return classifiedEmails;
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] 获取邮件失败: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> getStoredCredentials(String provider) async {
    return _getCredentials(provider);
  }

  Future<Map<String, String>?> _getCredentials(String provider) async {
    final email = await _secureStorage.read(key: _key(provider, 'email'));
    final password = await _secureStorage.read(key: _key(provider, 'password'));
    final host = await _secureStorage.read(key: _key(provider, 'host'));
    final port = await _secureStorage.read(key: _key(provider, 'port'));
    final isSecure = await _secureStorage.read(key: _key(provider, 'isSecure'));

    if (email != null && password != null && host != null && port != null && isSecure != null) {
      // ignore: avoid_print
      print('[$provider] 找到已存储的凭证: $email');
      return {
        'email': email,
        'password': password,
        'host': host,
        'port': port,
        'isSecure': isSecure,
      };
    }
    
    // ignore: avoid_print
    print('[$provider] 未找到存储的凭证');
    return null;
  }

  Future<void> logout(String provider) async {
    await _secureStorage.delete(key: _key(provider, 'email'));
    await _secureStorage.delete(key: _key(provider, 'password'));
    await _secureStorage.delete(key: _key(provider, 'host'));
    await _secureStorage.delete(key: _key(provider, 'port'));
    await _secureStorage.delete(key: _key(provider, 'isSecure'));
    
    // ignore: avoid_print
    print('[$provider] 已退出登录，凭证已清除');
  }

  Future<void> moveEmailsToTrash(String provider, List<MimeMessage> emails) async {
    if (emails.isEmpty) {
      return;
    }

    final credentials = await _getCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }

    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: credentials['email']!,
      password: credentials['password']!,
      incomingHost: credentials['host']!,
      outgoingHost: credentials['host']!, // Assuming outgoing host is the same as incoming
      incomingPort: int.parse(credentials['port']!),
      incomingSocketType: credentials['isSecure'] == 'true' ? SocketType.ssl : SocketType.starttls,
    );
    final client = MailClient(account, isLogEnabled: true);

    try {
      await client.connect();
      await client.selectInbox();

      final uids = emails.map((e) => e.uid!).toList();
      final sequence = MessageSequence.fromIds(uids, isUid: true);

      final mailboxes = await client.listMailboxes();
      final trashMailbox = mailboxes.firstWhere(
        (m) => m.isTrash,
        orElse: () => mailboxes.firstWhere(
          (m) => m.name.toLowerCase().contains('deleted') || m.name.toLowerCase().contains('trash'),
          orElse: () => throw Exception('Could not find a suitable "Deleted Items" folder.'),
        ),
      );

      await (client.lowLevelIncomingMailClient as ImapClient)
          .uidMove(sequence, targetMailboxPath: trashMailbox.path);

      await client.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] 移动邮件到回收站失败: $e');
      rethrow;
    }
  }

  Future<void> permanentlyDeleteEmails(String provider, List<MimeMessage> emails) async {
    if (emails.isEmpty) {
      return;
    }

    final credentials = await _getCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }

    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: credentials['email']!,
      password: credentials['password']!,
      incomingHost: credentials['host']!,
      outgoingHost: credentials['host']!, // Assuming outgoing host is the same as incoming
      incomingPort: int.parse(credentials['port']!),
      incomingSocketType: credentials['isSecure'] == 'true' ? SocketType.ssl : SocketType.starttls,
    );
    final client = MailClient(account, isLogEnabled: true);

    try {
      await client.connect();
      await client.selectInbox();

      final uids = emails.map((e) => e.uid!).toList();
      final sequence = MessageSequence.fromIds(uids, isUid: true);

      await (client.lowLevelIncomingMailClient as ImapClient).uidMarkDeleted(sequence);
      await (client.lowLevelIncomingMailClient as ImapClient).expunge();

      await client.disconnect();
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] 永久删除邮件失败: $e');
      rethrow;
    }
  }
}
