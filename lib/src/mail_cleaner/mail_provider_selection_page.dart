
import 'package:flutter1/src/mail_cleaner/unified_mail_clean_page.dart';
import 'package:flutter1/src/services/gmail_service.dart';
import 'package:flutter1/src/services/imap_email_service_adapter.dart';
import 'package:flutter1/src/services/outlook_email_service_adapter.dart';
import 'package:flutter1/src/mail_cleaner/imap_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter1/src/services/auth_service.dart';
import 'package:flutter1/src/account_management_page.dart';

class MailProviderSelectionPage extends StatefulWidget {
  const MailProviderSelectionPage({super.key});

  @override
  State<MailProviderSelectionPage> createState() =>
      _MailProviderSelectionPageState();
}

class _MailProviderSelectionPageState extends State<MailProviderSelectionPage> {
  final AuthService _authService = AuthService();
  final GmailService _gmailService = GmailService();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initAuthService();
  }

  Future<void> _initAuthService() async {
    try {
      await _authService.init();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Failed to initialize auth service: $e');
    }
  }

  Future<void> _loginToOutlook() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在初始化，请稍候...')),
      );
      return;
    }

    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final outlookService = OutlookEmailServiceAdapter();
      
      // 检查是否已有存储的凭证
      final credentials = await outlookService.getStoredCredentials();
      
      if (credentials != null && mounted) {
        // 已登录，直接进入统一的邮件清理主页
        Navigator.pop(context); // 关闭加载对话框
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedMailCleanPage(
              emailService: outlookService,
              providerName: 'Outlook',
            ),
          ),
        );
      } else {
        // 需要登录
        final token = await _authService.acquireToken();
        
        if (mounted) {
          Navigator.pop(context); // 关闭加载对话框
          
          if (token != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnifiedMailCleanPage(
                  emailService: outlookService,
                  providerName: 'Outlook',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Outlook 登录失败，请重试')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Outlook 登录失败: $e')),
        );
      }
    }
  }

  Future<void> _loginToGmail() async {
    // 显示加载提示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // 检查是否已有存储的凭证
      final credentials = await _gmailService.getStoredCredentials();
      
      if (credentials != null && mounted) {
        // 已登录，直接进入统一的邮件清理主页
        Navigator.pop(context); // 关闭加载对话框
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnifiedMailCleanPage(
              emailService: _gmailService,
              providerName: 'Gmail',
            ),
          ),
        );
      } else {
        // 需要登录
        final success = await _gmailService.login();
        
        if (mounted) {
          Navigator.pop(context); // 关闭加载对话框
          
          if (success) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UnifiedMailCleanPage(
                  emailService: _gmailService,
                  providerName: 'Gmail',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gmail 登录失败，请重试')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 关闭加载对话框
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gmail 登录失败: $e')),
        );
      }
    }
  }

  Future<void> _navigateToImap(String provider) async {
    final imapService = ImapEmailServiceAdapter(provider);
    final credentials = await imapService.getStoredCredentials();
    
    if (credentials != null && mounted) {
      // 已有凭证，直接进入统一的邮件清理主页
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UnifiedMailCleanPage(
            emailService: imapService,
            providerName: provider,
          ),
        ),
      );
    } else if (mounted) {
      // 没有凭证，跳转到登录页面
      final (host, port, isSecure) = switch (provider) {
        'Yahoo' => ('imap.mail.yahoo.com', 993, true),
        'QQ' => ('imap.qq.com', 993, true),
        'iCloud' => ('imap.mail.me.com', 993, true),
        _ => (null, null, null),
      };

      if (host != null) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImapLoginPage(
              provider: provider,
              initialHost: host,
              initialPort: port,
              initialIsSecure: isSecure,
            ),
          ),
        );
        
        // 如果登录成功，进入统一的邮件清理主页
        if (result == true && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UnifiedMailCleanPage(
                emailService: imapService,
                providerName: provider,
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择邮箱服务商'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '配置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AccountManagementPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _loginToGmail,
              child: const Text('Gmail'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loginToOutlook,
              child: const Text('Outlook'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToImap('Yahoo'),
              child: const Text('Yahoo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToImap('QQ'),
              child: const Text('QQ'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _navigateToImap('iCloud'),
              child: const Text('iCloud'),
            ),
          ],
        ),
      ),
    );
  }
}
