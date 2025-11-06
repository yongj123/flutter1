
import 'package:flutter/material.dart';
import 'package:flutter1/auth_service.dart';
import 'package:flutter1/mail_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Outlook Mail Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.init();
  }

  Future<void> _login() async {
    final accessToken = await _authService.acquireToken();
    if (accessToken != null) {
      Navigator.pushReplacement(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _login,
          child: const Text('Login with Outlook'),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final String accessToken;

  const HomePage({super.key, required this.accessToken});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mail Categories'),
      ),
      body: ListView(
        children: [
          _buildCategory(context, 'Social Media'),
          _buildCategory(context, 'Promotions'),
          _buildCategory(context, 'Other'),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String title) {
    return ListTile(
      title: Text(title),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MailListPage(
              accessToken: accessToken,
              category: title,
            ),
          ),
        );
      },
    );
  }
}

class MailListPage extends StatefulWidget {
  final String accessToken;
  final String category;

  const MailListPage(
      {super.key, required this.accessToken, required this.category});

  @override
  State<MailListPage> createState() => _MailListPageState();
}

class _MailListPageState extends State<MailListPage> {
  late final MailService _mailService;
  List<dynamic> _mails = [];
  final Set<String> _selectedMailIds = {};

  @override
  void initState() {
    super.initState();
    _mailService = MailService(widget.accessToken);
    _fetchMails();
  }

  Future<void> _fetchMails() async {
    try {
      final mails = await _mailService.getMails();
      setState(() {
        _mails = _filterMails(mails, widget.category);
      });
    } catch (e) {
      // Handle error
      print('Error fetching mails: $e');
    }
  }

  List<dynamic> _filterMails(List<dynamic> mails, String category) {
    if (category == 'Social Media') {
      return mails
          .where((mail) =>
              (mail['sender']?['emailAddress']?['address'] ?? '')
                  .contains('facebook') ||
              (mail['sender']?['emailAddress']?['address'] ?? '')
                  .contains('twitter'))
          .toList();
    } else if (category == 'Promotions') {
      return mails
          .where((mail) =>
              (mail['categories'] as List?)?.contains('Promotion') ?? false)
          .toList();
    } else {
      return mails
          .where((mail) =>
              !((mail['sender']?['emailAddress']?['address'] ?? '')
                      .contains('facebook') ||
                  (mail['sender']?['emailAddress']?['address'] ?? '')
                      .contains('twitter')) &&
              !((mail['categories'] as List?)?.contains('Promotion') ?? false))
          .toList();
    }
  }

  Future<void> _showDeleteConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Mails'),
          content: const Text(
              'Permanently delete these mails or move them to the Deleted Items folder?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Move to Deleted Items'),
              onPressed: () {
                _moveSelectedMailsToDeletedItems();
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Permanently Delete'),
              onPressed: () {
                _deleteSelectedMails();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _moveSelectedMailsToDeletedItems() async {
    try {
      await _mailService.moveMailsToDeletedItems(_selectedMailIds.toList());
      setState(() {
        _mails.removeWhere((mail) => _selectedMailIds.contains(mail['id']));
        _selectedMailIds.clear();
      });
    } catch (e) {
      // Handle error
      print('Error moving mails: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to move mails')),
      );
    }
  }

  Future<void> _deleteSelectedMails() async {
    try {
      await _mailService.deleteMails(_selectedMailIds.toList());
      setState(() {
        _mails.removeWhere((mail) => _selectedMailIds.contains(mail['id']));
        _selectedMailIds.clear();
      });
    } catch (e) {
      // Handle error
      print('Error deleting mails: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _selectedMailIds.isNotEmpty ? _showDeleteConfirmationDialog : null,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _mails.length,
        itemBuilder: (context, index) {
          final mail = _mails[index];
          final isSelected = _selectedMailIds.contains(mail['id']);

          return ListTile(
            title: Text(mail['subject'] ?? 'No Subject'),
            subtitle: Text(mail['sender']?['emailAddress']?['name'] ?? 'Unknown Sender'),
            leading: Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedMailIds.add(mail['id']);
                  } else {
                    _selectedMailIds.remove(mail['id']);
                  }
                });
              },
            ),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedMailIds.remove(mail['id']);
                } else {
                  _selectedMailIds.add(mail['id']);
                }
              });
            },
          );
        },
      ),
    );
  }
}
