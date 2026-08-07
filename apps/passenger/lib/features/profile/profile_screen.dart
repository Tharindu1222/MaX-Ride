import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? me;
  final nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    final res = await api.get('/auth/me');
    final data = Map<String, dynamic>.from(res['data'] as Map);
    setState(() {
      me = data;
      nameCtrl.text = data['fullName']?.toString() ?? '';
    });
  }

  Future<void> _save() async {
    final api = ref.read(apiClientProvider);
    await api.patch('/passengers/me', {'fullName': nameCtrl.text.trim()});
    await _load();
  }

  Future<void> _logout() async {
    await ref.read(apiClientProvider).clearTokens();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 8),
            Text(me?['phoneNumber']?.toString() ?? ''),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
            TextButton(onPressed: _logout, child: const Text('Log out')),
          ],
        ),
      ),
    );
  }
}
