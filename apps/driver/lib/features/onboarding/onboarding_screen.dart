import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final nameCtrl = TextEditingController(text: 'Demo Driver');
  final nicCtrl = TextEditingController(text: '199012345678');
  final licenseCtrl = TextEditingController(text: 'B1234567');
  final regCtrl = TextEditingController(
    text: 'CAB-${DateTime.now().millisecondsSinceEpoch % 100000}',
  );
  List categories = [];
  String? categoryId;
  String? message;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    nicCtrl.dispose();
    licenseCtrl.dispose();
    regCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final cats = await api.get('/vehicle-categories');
      setState(() {
        categories = (cats['data'] as List?) ?? [];
        if (categories.isNotEmpty) categoryId = categories.first['id'] as String?;
      });
    } catch (e) {
      setState(() => message = e.toString());
    }
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/drivers/me', {
        'fullName': nameCtrl.text.trim(),
        'nicNumber': nicCtrl.text.trim(),
        'drivingLicenseNumber': licenseCtrl.text.trim(),
      });
      await api.post('/drivers/me/documents', {
        'documentType': 'DRIVING_LICENSE',
        'fileUrl': 'local://mock-license.jpg',
      });
      if (categoryId != null) {
        await api.post('/drivers/me/vehicles', {
          'vehicleCategoryId': categoryId,
          'registrationNumber': regCtrl.text.trim(),
          'make': 'Toyota',
          'model': 'Aqua',
          'color': 'White',
          'manufactureYear': 2019,
        });
      }
      await api.post('/drivers/me/submit');
      setState(() =>
          message = 'Submitted. Ask an admin to approve this driver.');
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const Text(
            'Vehicle & documents',
            style: TextStyle(color: maxMuted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: maxSurface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: maxShadowFloat,
            ),
            child: Column(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    hintText: 'Name on your NIC',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nicCtrl,
                  decoration: const InputDecoration(labelText: 'NIC number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: licenseCtrl,
                  decoration: const InputDecoration(labelText: 'License number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle registration',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: (c as Map)['id'] as String,
                          child: Text(c['name']?.toString() ?? ''),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => categoryId = v),
                  decoration: const InputDecoration(labelText: 'Vehicle type'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? () {} : _submit,
            child: Text(loading ? 'Submitting…' : 'Submit application'),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(color: maxForest, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
