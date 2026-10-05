import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_result_provider.dart';
import '../main_navigation_screen.dart';

class PasteLabsScreen extends ConsumerStatefulWidget {
  final bool allowSkip;

  const PasteLabsScreen({super.key, this.allowSkip = true});

  @override
  ConsumerState<PasteLabsScreen> createState() => _PasteLabsScreenState();
}

class _PasteLabsScreenState extends ConsumerState<PasteLabsScreen> {
  final _textController = TextEditingController();
  final _dateController = TextEditingController();
  final _titleController = TextEditingController();
  bool _saving = false;
  String? _error;

  static const _sample = '''Cholesterol, Total  228  mg/dL  100-199  High
Triglycerides  178  mg/dL  0-149  High
HDL Cholesterol  38  mg/dL  >39  Low
LDL Chol Calc (NIH)  154  mg/dL  0-99  High
Glucose  118  mg/dL  65-99  High
Hemoglobin A1c  6.2  %  4.8-5.6  High''';

  @override
  void dispose() {
    _textController.dispose();
    _dateController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste your lab panel text first.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final err = await ref.read(allLabResultsProvider.notifier).pasteLabs(
          text: text,
          testDate: _dateController.text.trim().isEmpty
              ? null
              : _dateController.text.trim(),
          panelTitle: _titleController.text.trim().isEmpty
              ? null
              : _titleController.text.trim(),
        );

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _saving = false;
        _error = err;
      });
      return;
    }

    await ref.read(authProvider.notifier).markLabsImported();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add your lab results'),
        actions: [
          if (widget.allowSkip)
            TextButton(
              onPressed: _saving ? null : _goHome,
              child: const Text('Skip for now'),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade100),
              ),
              child: const Text(
                'For this demo: copy a few markers from MyChart, Labcorp, '
                'or your employer portal and paste them below. '
                'We store them in NutriAI to build your nutrition plan.\n\n'
                'Coming next: automatic sync from connected health systems '
                '(no copy-paste needed).',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Panel title (optional)',
                hintText: 'e.g. Lipid + A1c — Jun 2025',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Test date YYYY-MM-DD (optional)',
                hintText: '2025-06-15',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              minLines: 10,
              maxLines: 18,
              decoration: const InputDecoration(
                labelText: 'Paste lab markers',
                alignLabelWithHint: true,
                hintText:
                    'Cholesterol, Total  228  mg/dL  100-199  High\nGlucose  118  mg/dL  65-99  High',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _textController.text = _sample),
                icon: const Icon(Icons.content_paste_go, size: 18),
                label: const Text('Insert sample panel'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save to my NutriAI profile', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
