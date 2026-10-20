import 'package:flutter/material.dart';
import '../state/housing_store.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});
  final HousingStore store;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _server = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _server.text = widget.store.baseUrl;
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _server.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_server.text.trim().isNotEmpty && _server.text.trim() != widget.store.baseUrl) {
      await widget.store.setBaseUrl(_server.text);
    }
    final err = await widget.store.loginAsync(_user.text, _pass.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Future<void> _openServerDialog() async {
    final controller = TextEditingController(text: widget.store.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('عنوان الخادم'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'عنوان الخادم', hintText: 'http://192.168.1.10:8080/api'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await widget.store.setBaseUrl(result);
      if (mounted) setState(() => _server.text = widget.store.baseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(22)),
                  child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('إدارة الشؤون — إدارة السكن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: navy))),
              const SizedBox(height: 4),
              const Center(child: Text('تسجيل الدخول لمراقبي السكن والمتعهدين', style: TextStyle(fontSize: 12, color: muted))),
              const SizedBox(height: 26),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم', prefixIcon: Icon(Icons.person_outline_rounded)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline_rounded)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Color(0xFFC2414B), fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 16),
                    PrimaryAction(
                      label: _busy ? 'جارٍ الاتصال...' : 'دخول',
                      icon: Icons.login_rounded,
                      onPressed: _busy ? null : _submit,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(
                      widget.store.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 18,
                      color: widget.store.isOnline ? const Color(0xFF16846B) : const Color(0xFFC2414B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      widget.store.isOnline ? 'متصل بالخادم المشترك' : 'غير متصل بالخادم',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: navy),
                    )),
                    TextButton(
                      onPressed: _openServerDialog,
                      child: const Text('تغيير'), 
                    ),
                  ]),
                  Text(widget.store.baseUrl, style: const TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 8),
                  Text(
                    'يجب أن تشير جميع الأجهزة (المتعهد ومراقب السكن) إلى نفس عنوان الخادم لوصول الطلبات.',
                    style: const TextStyle(fontSize: 10, color: muted),
                  ),
                ]),
              ),
              const SizedBox(height: 20),
              const Center(child: Text('الدخول مخصّص لمراقبي السكن والمتعهدين فقط', style: TextStyle(fontSize: 11, color: muted))),
            ],
          ),
        ),
      ),
    );
  }
}
