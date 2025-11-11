import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/mail_classifier_service.dart';

/// 统一的邮件服务接口
/// 所有邮箱服务（Gmail, Outlook, IMAP 等）都需要实现这个接口
abstract class UnifiedEmailService {
  /// 邮箱提供商名称（如 "Gmail", "Outlook", "Yahoo" 等）
  String get providerName;

  /// 获取并分类邮件
  Future<Map<MailCategory, List<UnifiedEmailMessage>>> fetchAndClassifyEmails();

  /// 移动邮件到已删除目录
  Future<void> moveEmailsToDeleted(List<UnifiedEmailMessage> emails);

  /// 永久删除邮件
  Future<void> permanentlyDeleteEmails(List<UnifiedEmailMessage> emails);

  /// 退出登录
  Future<void> logout();

  /// 获取存储的凭证（用于检查是否已登录）
  Future<Map<String, String>?> getStoredCredentials();
}

