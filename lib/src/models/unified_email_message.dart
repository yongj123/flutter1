import 'package:intl/intl.dart';

/// 统一的邮件消息模型
/// 适用于所有邮箱服务（Gmail, Outlook, Yahoo, QQ, iCloud 等）
class UnifiedEmailMessage {
  final String id;
  final String? subject;
  final String? from;
  final String? fromEmail;
  final DateTime? date;
  final String? snippet;
  final bool isRead;
  
  UnifiedEmailMessage({
    required this.id,
    this.subject,
    this.from,
    this.fromEmail,
    this.date,
    this.snippet,
    this.isRead = false,
  });

  /// 格式化显示发件人
  String get displayFrom {
    if (from != null && from!.isNotEmpty) {
      return from!;
    }
    if (fromEmail != null && fromEmail!.isNotEmpty) {
      return fromEmail!;
    }
    return 'Unknown';
  }

  /// 格式化显示主题
  String get displaySubject {
    if (subject != null && subject!.isNotEmpty) {
      return subject!;
    }
    return 'No Subject';
  }

  /// 格式化显示日期
  String get displayDate {
    if (date == null) {
      return 'Unknown date';
    }

    final now = DateTime.now();
    final difference = now.difference(date!);

    if (difference.inDays == 0) {
      return DateFormat.jm().format(date!);
    } else if (difference.inDays == 1) {
      return '昨天 ${DateFormat.jm().format(date!)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return DateFormat.yMd().add_jm().format(date!);
    }
  }

  /// 提取发件人名称（去除邮箱地址）
  static String extractName(String? fromString) {
    if (fromString == null || fromString.isEmpty) {
      return 'Unknown';
    }

    // 尝试提取名字（在 <> 之前）
    final match = RegExp(r'^(.+?)\s*<').firstMatch(fromString);
    if (match != null) {
      return match.group(1)?.trim() ?? fromString;
    }

    return fromString;
  }

  /// 提取邮箱地址
  static String? extractEmail(String? fromString) {
    if (fromString == null || fromString.isEmpty) {
      return null;
    }

    // 尝试提取邮箱地址（<> 中的内容）
    final match = RegExp(r'<([^>]+)>').firstMatch(fromString);
    if (match != null) {
      return match.group(1);
    }

    // 如果没有 <>，检查是否本身就是邮箱
    if (fromString.contains('@')) {
      return fromString;
    }

    return null;
  }
}

