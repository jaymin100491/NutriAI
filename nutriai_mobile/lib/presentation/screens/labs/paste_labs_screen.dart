import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/diet_plan_provider.dart';
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
  String? _success;

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

  Future<void> _finishSuccess(String? message) async {
    await ref.read(authProvider.notifier).markLabsImported();
    await ref.read(dietPlanNotifierProvider.notifier).loadCurrentDietPlan();
    if (!mounted) return;
    setState(() {
      _saving = false;
      _success = message ?? 'Labs saved and your Mon–Sun plan is ready.';
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_success!), duration: const Duration(seconds: 4)),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  Future<void> _savePaste() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste your lab panel text, or upload a PDF.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final msg = await ref.read(allLabResultsProvider.notifier).pasteLabs(
          text: text,
          testDate: _dateController.text.trim().isEmpty ? null : _dateController.text.trim(),
          panelTitle: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
        );
    if (!mounted) return;
    if (msg != null && msg.startsWith('ERROR:')) {
      setState(() {
        _saving = false;
        _error = msg.substring(6);
      });
      return;
    }
    await _finishSuccess(msg);
  }

  Future<void> _pickPdf() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _saving = false);
        return;
      }

      final files = result.files.where((f) => (f.bytes?.isNotEmpty ?? false)).toList();
      if (files.isEmpty) {
        setState(() {
          _saving = false;
          _error = 'Could not read PDF bytes. Try another file or paste text.';
        });
        return;
      }

      String? lastMsg;
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final isLast = i == files.length - 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isLast
                    ? 'Processing ${file.name} and generating your plan…'
                    : 'Saving ${file.name} (${i + 1}/${files.length})…',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        final msg = await ref.read(allLabResultsProvider.notifier).uploadPdf(
              bytes: file.bytes!,
              filename: file.name,
              testDate: _dateController.text.trim().isEmpty
                  ? null
                  : _dateController.text.trim(),
              // Store history on early files; generate plan only after the last PDF.
              generatePlan: isLast,
            );
        if (!mounted) return;
        if (msg != null && msg.startsWith('ERROR:')) {
          setState(() {
            _saving = false;
            _error = msg.substring(6);
          });
          return;
        }
        lastMsg = msg;
      }
      await _finishSuccess(
        lastMsg ??
            'Saved ${files.length} lab PDF(s) and prepared your Mon–Sun plan.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
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
            TextButton(onPressed: _saving ? null : _goHome, child: const Text('Skip for now')),
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
                'Welcome — upload one or more Labcorp Patient Report PDFs (or paste markers).\n\n'
                'We extract and store each panel in your history, derive goals, then build your '
                'Mon–Sun diet plan. Multiple PDFs are supported — pick all 7 at once for the demo.\n\n'
                'Track biometrics daily. Every Friday we prepare next week’s plan from your progress.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saving ? null : _pickPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Upload lab PDF(s)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Text('— or paste markers —', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Panel title (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Test date YYYY-MM-DD (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Paste lab markers',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _textController.text = _sample),
                icon: const Icon(Icons.content_paste_go, size: 18),
                label: const Text('Insert sample panel'),
              ),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _saving ? null : _savePaste,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save labs & build my week plan', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
