import 'package:flutter/material.dart';
import 'package:flutter1/src/services/auth_service.dart';
import 'package:flutter1/src/services/imap_service.dart';
import 'package:flutter1/src/services/gmail_service.dart';

class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final AuthService _authService = AuthService();
  final ImapService _imapService = ImapService();
  final GmailService _gmailService = GmailService();

  String? _outlookUser;
  String? _gmailUser;
  final Map<String, String> _imapUsers = {};

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    // 加载 Gmail 账户
    final gmailCredentials = await _gmailService.getStoredCredentials();
    if (gmailCredentials != null) {
      setState(() {
        _gmailUser = gmailCredentials['email'] ?? 'Gmail User';
      });
    }

    // 加载Outlook账户
    await _authService.init();
    final outlookToken = await _authService.acquireTokenSilently();
    if (outlookToken != null) {
      // In a real app, you'd get the user's email from the token or a graph API call
      setState(() {
        _outlookUser = 'Outlook User'; // Placeholder
      });
    }

    // 加载IMAP账户（Yahoo, QQ, iCloud）
    for (final provider in ['Yahoo', 'QQ', 'iCloud']) {
      final imapCredentials = await _imapService.getStoredCredentials(provider);
      if (imapCredentials != null) {
        setState(() {
          _imapUsers[provider] = imapCredentials['email']!;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('账户管理'),
      ),
      body: ListView(
        children: [
          if (_gmailUser != null)
            ListTile(
              leading: const Icon(Icons.email, color: Colors.red),
              title: Text(_gmailUser!),
              subtitle: const Text('Gmail'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await _gmailService.logout();
                  setState(() {
                    _gmailUser = null;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已退出 Gmail 账户')),
                    );
                  }
                },
                child: const Text('退出登录'),
              ),
            ),
          if (_outlookUser != null)
            ListTile(
              leading: const Icon(Icons.mail, color: Colors.blue),
              title: Text(_outlookUser!),
              subtitle: const Text('Outlook'),
              trailing: ElevatedButton(
                onPressed: () async {
                  await _authService.logout();
                  setState(() {
                    _outlookUser = null;
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已退出 Outlook 账户')),
                    );
                  }
                },
                child: const Text('退出登录'),
              ),
            ),
          ..._imapUsers.entries.map((entry) {
            final provider = entry.key;
            final email = entry.value;
            return ListTile(
              leading: Icon(
                Icons.mail_outline,
                color: provider == 'Yahoo' 
                    ? Colors.purple 
                    : provider == 'QQ' 
                        ? Colors.blue 
                        : Colors.grey,
              ),
              title: Text(email),
              subtitle: Text(provider),
              trailing: ElevatedButton(
                onPressed: () async {
                  await _imapService.logout(provider);
                  setState(() {
                    _imapUsers.remove(provider);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已退出 $provider 账户')),
                    );
                  }
                },
                child: const Text('退出登录'),
              ),
            );
          }),
          if (_gmailUser == null && _outlookUser == null && _imapUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '暂无已登录账户',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}