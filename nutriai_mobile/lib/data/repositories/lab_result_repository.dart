import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/lab_result_model.dart';
import 'labcorp_portal_repository.dart';
import 'package:flutter/foundation.dart';

class LabResultRepository {
  final DioClient _dioClient;
  final LabcorpPortalRepository _portalRepository = LabcorpPortalRepository();

  LabResultRepository(this._dioClient);

  Future<List<LabResult>> getAllLabResults() async {
    final response = await _dioClient.dio.get(ApiConstants.labResults);
    final data = response.data as Map<String, dynamic>;
    final results = data['lab_results'] as List<dynamic>;
    return results.map((json) => LabResult.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LabResult> getLatestLabResult() async {
    final response = await _dioClient.dio.get(ApiConstants.latestLabResult);
    return LabResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LabResult> getLabResultById(int id) async {
    final response = await _dioClient.dio.get('${ApiConstants.labResults}/$id');
    return LabResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<LabResult>> syncFromLabcorp() async {
    if (kIsWeb) {
      try {
        final portalPayload = await _portalRepository.fetchAllResultsForImport();
        final response = await _dioClient.dio.post(
          ApiConstants.labResultsImportFromPortal,
          data: portalPayload,
        );
        final data = response.data as Map<String, dynamic>;
        final results = data['lab_results'] as List<dynamic>;
        return results.map((json) => LabResult.fromJson(json as Map<String, dynamic>)).toList();
      } catch (_) {
        // Portal session optional for open-market demo — fall through to empty/manual paste.
        return getAllLabResults();
      }
    }

    final response = await _dioClient.dio.post(
      ApiConstants.labResultsSync,
      queryParameters: {'source': 'labcorp', 'health_system': 'labcorp'},
    );
    final data = response.data as Map<String, dynamic>;
    final results = data['lab_results'] as List<dynamic>;
    return results.map((json) => LabResult.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<LabResult>> pasteLabText({
    required String text,
    String? testDate,
    String? panelTitle,
  }) async {
    final response = await _dioClient.dio.post(
      ApiConstants.labResultsPaste,
      data: {
        'text': text,
        if (testDate != null && testDate.isNotEmpty) 'test_date': testDate,
        if (panelTitle != null && panelTitle.isNotEmpty) 'panel_title': panelTitle,
        'source_label': 'pasted_panel',
      },
    );
    final data = response.data as Map<String, dynamic>;
    final results = data['lab_results'] as List<dynamic>;
    return results.map((json) => LabResult.fromJson(json as Map<String, dynamic>)).toList();
  }
}
