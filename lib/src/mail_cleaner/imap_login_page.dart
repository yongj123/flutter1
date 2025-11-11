
import 'package:flutter/material.dart';
import 'package:flutter1/src/services/imap_service.dart';

class ImapLoginPage extends StatefulWidget {
  final String provider;
  final String? initialEmail;
  final String? initialHost;
  final int? initialPort;
  final bool? initialIsSecure;

  const ImapLoginPage({
    super.key,
    required this.provider,
    this.initialEmail,
    this.initialHost,
    this.initialPort,
    this.initialIsSecure,
  });

  @override
  State<ImapLoginPage> createState() => _ImapLoginPageState();
}

class _ImapLoginPageState extends State<ImapLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _imapService = ImapService();
  bool _isLoading = false;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  bool _isSecure = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _passwordController = TextEditingController();
    _hostController = TextEditingController(text: widget.initialHost);
    _portController = TextEditingController(text: widget.initialPort?.toString());
    _isSecure = widget.initialIsSecure ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMAP 登录'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: '邮箱地址'),
                enableInteractiveSelection: true,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入邮箱地址';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
                enableInteractiveSelection: true,
                enableSuggestions: false,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(labelText: 'IMAP 服务器'),
                enableInteractiveSelection: true,
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入 IMAP 服务器地址';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(labelText: '端口'),
                keyboardType: TextInputType.number,
                enableInteractiveSelection: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入端口号';
                  }
                  return null;
                },
              ),
              Row(
                children: [
                  const Text('使用 SSL/TLS'),
                  Switch(
                    value: _isSecure,
                    onChanged: (value) {
                      setState(() {
                        _isSecure = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('登录'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await _imapService.login(
      widget.provider,
      _emailController.text,
      _passwordController.text,
      _hostController.text,
      int.parse(_portController.text),
      _isSecure,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        // 返回 true 表示登录成功
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录失败. 请检查您的凭证或网络.')),
        );
      }
    }
  }
}
