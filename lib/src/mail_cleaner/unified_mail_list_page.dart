import 'package:flutter/material.dart';
import 'package:flutter1/src/models/unified_email_message.dart';
import 'package:flutter1/src/services/unified_email_service.dart';
import 'package:flutter1/src/widgets/delete_email_dialog.dart';

/// 统一的邮件列表页
/// 适用于所有邮箱服务，按时间从新到旧排序
class UnifiedMailListPage extends StatefulWidget {
  final String providerName;
  final String category;
  final List<UnifiedEmailMessage> emails;
  final UnifiedEmailService emailService;

  const UnifiedMailListPage({
    super.key,
    required this.providerName,
    required this.category,
    required this.emails,
    required this.emailService,
  });

  @override
  State<UnifiedMailListPage> createState() => _UnifiedMailListPageState();
}

class _UnifiedMailListPageState extends State<UnifiedMailListPage> {
  final Set<int> _selectedIndices = {};
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    // 按日期排序（从新到旧）
    widget.emails.sort((a, b) {
      final aDate = a.date ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final bDate = b.date ?? DateTime.fromMicrosecondsSinceEpoch(0);
      return bDate.compareTo(aDate); // 新的在前
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.providerName} - ${widget.category}'),
        actions: [
          if (_selectedIndices.isNotEmpty)
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _showDeleteDialog,
                    tooltip: 'Delete selected',
                  ),
        ],
      ),
      body: widget.emails.isEmpty
          ? const Center(
              child: Text('No emails'),
            )
          : Column(
              children: [
                // 选择信息栏
                if (_selectedIndices.isNotEmpty)
                  Container(
                    color: Colors.blue[50],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_selectedIndices.length} email${_selectedIndices.length > 1 ? 's' : ''} selected',
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedIndices.clear();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (var i = 0; i < widget.emails.length; i++) {
                                _selectedIndices.add(i);
                              }
                            });
                          },
                          child: const Text('Select All'),
                        ),
                      ],
                    ),
                  ),
                // 邮件列表
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.emails.length,
                    itemBuilder: (context, index) {
                      final email = widget.emails[index];
                      final isSelected = _selectedIndices.contains(index);

                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedIndices.add(index);
                              } else {
                                _selectedIndices.remove(index);
                              }
                            });
                          },
                        ),
                        title: Text(
                          email.displaySubject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: email.isRead ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'From: ${email.displayFrom}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email.displayDate,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            if (email.snippet != null && email.snippet!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  email.snippet!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          // TODO: 实现邮件详情查看
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final selectedCount = _selectedIndices.length;
    
    // 显示统一的删除弹窗
    final option = await DeleteEmailDialog.show(context, selectedCount);

    if (option == null) {
      return; // 用户取消或点击 X
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      final emailsToDelete = _selectedIndices
          .map((index) => widget.emails[index])
          .toList();

      if (option == DeleteEmailOption.moveToDeleted) {
        await widget.emailService.moveEmailsToDeleted(emailsToDelete);
      } else {
        await widget.emailService.permanentlyDeleteEmails(emailsToDelete);
      }

      setState(() {
        // 从列表中移除已删除的邮件
        widget.emails.removeWhere((email) => emailsToDelete.contains(email));
        _selectedIndices.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              option == DeleteEmailOption.moveToDeleted
                  ? 'Moved to Deleted Items'
                  : 'Permanently deleted',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }
}

