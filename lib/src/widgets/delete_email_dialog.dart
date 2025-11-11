import 'package:flutter/material.dart';

/// 删除邮件的选项
enum DeleteEmailOption {
  moveToDeleted,  // 移动到已删除目录
  permanentDelete, // 永久删除
}

/// 统一的删除邮件对话框
/// 参考 Outlook 的删除弹窗设计
class DeleteEmailDialog extends StatelessWidget {
  final int selectedCount;

  const DeleteEmailDialog({
    super.key,
    required this.selectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏（带关闭按钮）
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Delete Emails',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),
            
            // 内容区域
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Text(
                'You have selected $selectedCount email${selectedCount > 1 ? 's' : ''}. How would you like to proceed?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),

            // 分隔线
            const Divider(height: 1),

            // 选项按钮
            InkWell(
              onTap: () => Navigator.of(context).pop(DeleteEmailOption.moveToDeleted),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.blue[700],
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Move to Deleted Items',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Can be recovered later',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            InkWell(
              onTap: () => Navigator.of(context).pop(DeleteEmailOption.permanentDelete),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever,
                      color: Colors.red[700],
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Permanently Delete',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cannot be recovered',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 显示删除对话框
  static Future<DeleteEmailOption?> show(BuildContext context, int selectedCount) {
    return showDialog<DeleteEmailOption>(
      context: context,
      builder: (context) => DeleteEmailDialog(selectedCount: selectedCount),
    );
  }
}

