import 'package:flutter/material.dart';
import 'package:flutter1/src/mail_cleaner/mail_provider_selection_page.dart';
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
  @override
  void initState() {
    super.initState();
  }

  void _navigateToPhotoCleaner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimilarPhotosPage()),
    );
  }

  void _navigateToMailCleaner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MailProviderSelectionPage()),
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
              onPressed: _navigateToMailCleaner,
              child: const Text('邮件清理'),
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