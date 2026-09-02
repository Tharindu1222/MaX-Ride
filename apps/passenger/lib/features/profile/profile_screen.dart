import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? me;
  final nameCtrl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
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
    setState(() => saving = true);
    final api = ref.read(apiClientProvider);
    await api.patch('/passengers/me', {'fullName': nameCtrl.text.trim()});
    await _load();
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  Future<void> _logout() async {
    await ref.read(apiClientProvider).clearTokens();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final initial = (nameCtrl.text.isNotEmpty ? nameCtrl.text[0] : 'M')
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: maxForest,
              child: Text(
                initial,
                style: const TextStyle(
                  color: maxLime,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              me?['phoneNumber']?.toString() ?? '',
              style: const TextStyle(color: maxMuted, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: maxSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: maxShadowFloat,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'How drivers should greet you',
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextButton(
            onPressed: _logout,
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
