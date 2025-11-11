import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/unified_email_service.dart';
import 'package:flutter1/src/services/imap_service.dart';
import 'package:flutter1/src/services/mail_classifier_service.dart';
import 'package:enough_mail/enough_mail.dart';

/// IMAP 服务适配器
/// 将 IMAP 服务适配到统一的邮件服务接口
class ImapEmailServiceAdapter implements UnifiedEmailService {
  final String provider;
  final ImapService _imapService = ImapService();

  ImapEmailServiceAdapter(this.provider);

  @override
  String get providerName => provider;

  @override
  Future<Map<MailCategory, List<UnifiedEmailMessage>>> fetchAndClassifyEmails() async {
    // 获取 IMAP 邮件
    final mimeMessages = await _imapService.fetchAndClassifyEmails(provider);

    // 转换为统一格式
    final result = <MailCategory, List<UnifiedEmailMessage>>{
      MailCategory.socialMedia: [],
      MailCategory.promotions: [],
      MailCategory.other: [],
    };

    for (final entry in mimeMessages.entries) {
      final category = entry.key;
      final messages = entry.value;

      for (final mimeMsg in messages) {
        result[category]!.add(_convertToUnifiedMessage(mimeMsg));
      }
    }

    return result;
  }

  @override
  Future<void> moveEmailsToDeleted(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) return;

    // 需要获取原始的 MimeMessage 对象才能删除
    // 由于我们只有 ID，需要重新连接并移动
    final credentials = await _imapService.getStoredCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }

    // 使用 IMAP 服务的移动方法
    // 注意：这里需要 MimeMessage 对象，我们需要根据 ID 重建或使用不同的方法
    await _moveToDeletedByIds(emails.map((e) => e.id).toList());
  }

  @override
  Future<void> permanentlyDeleteEmails(List<UnifiedEmailMessage> emails) async {
    if (emails.isEmpty) return;

    await _permanentlyDeleteByIds(emails.map((e) => e.id).toList());
  }

  @override
  Future<void> logout() async {
    await _imapService.logout(provider);
  }

  @override
  Future<Map<String, String>?> getStoredCredentials() async {
    return await _imapService.getStoredCredentials(provider);
  }

  /// 转换 MimeMessage 到 UnifiedEmailMessage
  UnifiedEmailMessage _convertToUnifiedMessage(MimeMessage mimeMsg) {
    // 提取发件人信息
    String? fromName;
    String? fromEmail;
    
    if (mimeMsg.from != null && mimeMsg.from!.isNotEmpty) {
      final from = mimeMsg.from!.first;
      fromName = from.personalName ?? from.email;
      fromEmail = from.email;
    }

    // 安全地截取摘要（最多 100 个字符）
    String? snippet;
    final plainText = mimeMsg.decodeTextPlainPart();
    if (plainText != null && plainText.isNotEmpty) {
      snippet = plainText.length > 100 
          ? plainText.substring(0, 100) 
          : plainText;
    }

    return UnifiedEmailMessage(
      id: mimeMsg.uid?.toString() ?? mimeMsg.sequenceId?.toString() ?? '',
      subject: mimeMsg.decodeSubject(),
      from: fromName,
      fromEmail: fromEmail,
      date: mimeMsg.decodeDate(),
      snippet: snippet,
      isRead: mimeMsg.isSeen,
    );
  }

  /// 根据 ID 移动邮件到已删除文件夹
  Future<void> _moveToDeletedByIds(List<String> ids) async {
    final credentials = await _imapService.getStoredCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }

    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: credentials['email']!,
      password: credentials['password']!,
      incomingHost: credentials['host']!,
      outgoingHost: credentials['host']!,
      incomingPort: int.parse(credentials['port']!),
      incomingSocketType: credentials['isSecure'] == 'true' ? SocketType.ssl : SocketType.starttls,
    );

    final client = MailClient(account, isLogEnabled: true);

    try {
      await client.connect();
      await client.selectInbox();

      // 转换 ID 为 UID
      final uids = ids.map((id) => int.tryParse(id) ?? 0).where((uid) => uid > 0).toList();
      if (uids.isEmpty) return;

      final sequence = MessageSequence.fromIds(uids, isUid: true);

      // 查找删除文件夹
      final mailboxes = await client.listMailboxes();
      final trashMailbox = mailboxes.firstWhere(
        (m) => m.isTrash,
        orElse: () => mailboxes.firstWhere(
          (m) => m.name.toLowerCase().contains('deleted') || 
                 m.name.toLowerCase().contains('trash') ||
                 m.name.toLowerCase().contains('已删除'),
          orElse: () => throw Exception('Could not find trash folder'),
        ),
      );

      await (client.lowLevelIncomingMailClient as ImapClient)
          .uidMove(sequence, targetMailboxPath: trashMailbox.path);

      await client.disconnect();
      
      // ignore: avoid_print
      print('[$provider] Successfully moved ${uids.length} emails to trash');
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] Failed to move emails to trash: $e');
      rethrow;
    }
  }

  /// 根据 ID 永久删除邮件
  Future<void> _permanentlyDeleteByIds(List<String> ids) async {
    final credentials = await _imapService.getStoredCredentials(provider);
    if (credentials == null) {
      throw Exception('No stored credentials found for $provider');
    }

    final account = MailAccount.fromManualSettings(
      name: 'my-account',
      email: credentials['email']!,
      password: credentials['password']!,
      incomingHost: credentials['host']!,
      outgoingHost: credentials['host']!,
      incomingPort: int.parse(credentials['port']!),
      incomingSocketType: credentials['isSecure'] == 'true' ? SocketType.ssl : SocketType.starttls,
    );

    final client = MailClient(account, isLogEnabled: true);

    try {
      await client.connect();
      await client.selectInbox();

      // 转换 ID 为 UID
      final uids = ids.map((id) => int.tryParse(id) ?? 0).where((uid) => uid > 0).toList();
      if (uids.isEmpty) return;

      final sequence = MessageSequence.fromIds(uids, isUid: true);

      await (client.lowLevelIncomingMailClient as ImapClient).uidMarkDeleted(sequence);
      await (client.lowLevelIncomingMailClient as ImapClient).expunge();

      await client.disconnect();
      
      // ignore: avoid_print
      print('[$provider] Successfully permanently deleted ${uids.length} emails');
    } catch (e) {
      // ignore: avoid_print
      print('[$provider] Failed to permanently delete emails: $e');
      rethrow;
    }
  }
}

