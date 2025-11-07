import 'package:flutter/material.dart';
import 'src/services/auth_service.dart';
import 'src/mail_cleaner/mail_home_page.dart';
import 'src/photo_cleaner/similar_photos_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Tools',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WelcomePage(),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.init();
  }

  Future<void> _login() async {
    final accessToken = await _authService.acquireToken();
    if (accessToken != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(accessToken: accessToken),
        ),
      );
    } else {
      // Handle login failure
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed')),
      );
    }
  }

  void _navigateToPhotoCleaner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimilarPhotosPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('功能选择'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _login,
              child: const Text('登录 Outlook 清理邮件'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _navigateToPhotoCleaner,
              child: const Text('扫描相似照片'),
            ),
          ],
        ),
      ),
    );
  }
}