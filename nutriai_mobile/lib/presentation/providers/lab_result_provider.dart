import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../../data/models/lab_result_model.dart';
import '../../data/repositories/lab_result_repository.dart';

final labResultRepositoryProvider = Provider<LabResultRepository>((ref) {
  return LabResultRepository(ref.watch(dioClientProvider));
});

final allLabResultsProvider =
    AsyncNotifierProvider<LabResultsNotifier, List<LabResult>>(LabResultsNotifier.new);

class LabResultsNotifier extends AsyncNotifier<List<LabResult>> {
  @override
  Future<List<LabResult>> build() async {
    final repository = ref.watch(labResultRepositoryProvider);
    return repository.getAllLabResults();
  }

  Future<void> sync() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(labResultRepositoryProvider);
      return repository.syncFromLabcorp();
    });
  }

  /// Returns null on success (with optional success message), or error string.
  Future<String?> pasteLabs({
    required String text,
    String? testDate,
    String? panelTitle,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(labResultRepositoryProvider);
      final data = await repository.pasteLabText(
        text: text,
        testDate: testDate,
        panelTitle: panelTitle,
      );
      final results = (data['lab_results'] as List<dynamic>? ?? [])
          .map((json) => LabResult.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(results);
      return data['message'] as String?;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'ERROR:$e';
    }
  }

  Future<String?> uploadPdf({
    required List<int> bytes,
    required String filename,
    String? testDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(labResultRepositoryProvider);
      final data = await repository.uploadLabPdf(
        bytes: bytes,
        filename: filename,
        testDate: testDate,
      );
      final results = (data['lab_results'] as List<dynamic>? ?? [])
          .map((json) => LabResult.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(results);
      return data['message'] as String?;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return 'ERROR:$e';
    }
  }
}

final latestLabResultProvider = FutureProvider<LabResult?>((ref) async {
  final repository = ref.watch(labResultRepositoryProvider);
  try {
    return await repository.getLatestLabResult();
  } catch (e) {
    return null;
  }
});
