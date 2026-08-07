import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

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
      setState(() => message = 'Submitted for admin approval. Ask admin to Approve this driver.');
    } catch (e) {
      setState(() => message = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver onboarding')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: nicCtrl, decoration: const InputDecoration(labelText: 'NIC')),
          TextField(controller: licenseCtrl, decoration: const InputDecoration(labelText: 'License no.')),
          TextField(
            controller: regCtrl,
            decoration: const InputDecoration(labelText: 'Vehicle registration'),
          ),
          const SizedBox(height: 12),
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
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: loading ? null : _submit,
            child: Text(loading ? 'Submitting…' : 'Submit application'),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!),
          ],
        ],
      ),
    );
  }
}
