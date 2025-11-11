import 'package:flutter/material.dart';
import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/unified_email_service.dart';
import 'package:flutter1/src/services/mail_classifier_service.dart';
import 'package:flutter1/src/mail_cleaner/unified_mail_list_page.dart';

/// 统一的邮件清理主页（分类页面）
/// 适用于所有邮箱服务
class UnifiedMailCleanPage extends StatefulWidget {
  final UnifiedEmailService emailService;
  final String providerName;

  const UnifiedMailCleanPage({
    super.key,
    required this.emailService,
    required this.providerName,
  });

  @override
  State<UnifiedMailCleanPage> createState() => _UnifiedMailCleanPageState();
}

class _UnifiedMailCleanPageState extends State<UnifiedMailCleanPage> {
  bool _isLoading = false;
  Map<MailCategory, List<UnifiedEmailMessage>>? _classifiedEmails;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmails();
  }

  Future<void> _loadEmails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final emails = await widget.emailService.fetchAndClassifyEmails();
      if (mounted) {
        setState(() {
          _classifiedEmails = emails;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: Text('Are you sure you want to logout from ${widget.providerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.emailService.logout();
        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.providerName} Clean'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Loading failed: $_error',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadEmails,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _classifiedEmails == null
                  ? const Center(child: Text('No data'))
                  : RefreshIndicator(
                      onRefresh: _loadEmails,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildCategoryCard(
                            'Social Media',
                            _classifiedEmails![MailCategory.socialMedia]!,
                            Icons.people,
                            Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          _buildCategoryCard(
                            'Promotions',
                            _classifiedEmails![MailCategory.promotions]!,
                            Icons.local_offer,
                            Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          _buildCategoryCard(
                            'Other',
                            _classifiedEmails![MailCategory.other]!,
                            Icons.mail,
                            Colors.grey,
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    List<UnifiedEmailMessage> emails,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: emails.isEmpty
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UnifiedMailListPage(
                      providerName: widget.providerName,
                      category: title,
                      emails: emails,
                      emailService: widget.emailService,
                    ),
                  ),
                );
                // 返回后刷新邮件列表
                _loadEmails();
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${emails.length} email${emails.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              if (emails.isNotEmpty)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

