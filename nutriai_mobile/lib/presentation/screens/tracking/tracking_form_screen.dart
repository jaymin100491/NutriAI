import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/tracking_model.dart';
import '../../providers/tracking_provider.dart';

class TrackingFormScreen extends ConsumerStatefulWidget {
  const TrackingFormScreen({super.key});

  @override
  ConsumerState<TrackingFormScreen> createState() => _TrackingFormScreenState();
}

class _TrackingFormScreenState extends ConsumerState<TrackingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _notesController = TextEditingController();
  int _moodValue = 5;

  @override
  void dispose() {
    _weightController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _glucoseController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitTracking() async {
    if (_formKey.currentState!.validate()) {
      final tracking = DailyTracking(
        id: 0,
        userId: 1,
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        weightLbs: _weightController.text.isNotEmpty ? double.tryParse(_weightController.text) : null,
        systolicBp: _systolicController.text.isNotEmpty ? int.tryParse(_systolicController.text) : null,
        diastolicBp: _diastolicController.text.isNotEmpty ? int.tryParse(_diastolicController.text) : null,
        bloodGlucose: _glucoseController.text.isNotEmpty ? int.tryParse(_glucoseController.text) : null,
        mood: _moodValue,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await ref.read(trackingNotifierProvider.notifier).submitTracking(tracking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking data saved!')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(trackingNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Daily Metrics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildWeightField(),
              const SizedBox(height: 16),
              _buildBloodPressureFields(),
              const SizedBox(height: 16),
              _buildGlucoseField(),
              const SizedBox(height: 24),
              _buildMoodSlider(),
              const SizedBox(height: 24),
              _buildNotesField(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: trackingState.isLoading ? null : _submitTracking,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: trackingState.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Tracking Data', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightField() {
    return TextFormField(
      controller: _weightController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Weight (lbs)',
        hintText: 'Enter your weight',
        prefixIcon: Icon(Icons.monitor_weight),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildBloodPressureFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Blood Pressure (mmHg)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _systolicController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Systolic',
                  hintText: '120',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: TextFormField(
                controller: _diastolicController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Diastolic',
                  hintText: '80',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlucoseField() {
    return TextFormField(
      controller: _glucoseController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Blood Glucose (mg/dL)',
        hintText: 'Enter your blood glucose level',
        prefixIcon: Icon(Icons.bloodtype),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildMoodSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Mood Today', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(_getMoodEmoji(_moodValue), style: const TextStyle(fontSize: 32)),
            Expanded(
              child: Slider(
                value: _moodValue.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                label: _moodValue.toString(),
                onChanged: (value) {
                  setState(() {
                    _moodValue = value.toInt();
                  });
                },
              ),
            ),
            Text(
              '$_moodValue/10',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('Poor', style: TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Excellent', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Notes (optional)',
        hintText: 'How are you feeling today?',
        border: OutlineInputBorder(),
      ),
    );
  }

  String _getMoodEmoji(int mood) {
    if (mood <= 3) return '😞';
    if (mood <= 5) return '😐';
    if (mood <= 7) return '🙂';
    return '😄';
  }
}
