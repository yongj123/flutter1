import 'package:flutter/material.dart';
import 'mail_list_page.dart';

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
