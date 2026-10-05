import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/portal_dio.dart';

/// Calls portal-api directly from the browser — same as patient-website-ui.
class LabcorpPortalRepository {
  final Dio _dio = createPortalDio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> loginWithOktaToken(String oktaAccessToken) async {
    await _dio.post<void>(
      '/protected/patients/current/login',
      options: Options(
        headers: {'Authorization': 'Bearer $oktaAccessToken'},
      ),
    );
  }

  Future<void> ensureBrowserPortalSession() async {
    final token = await _storage.read(key: 'okta_access_token');
    if (token != null && token.isNotEmpty) {
      await loginWithOktaToken(token);
    }
  }

  Future<List<Map<String, dynamic>>> fetchResultHeaders() async {
    final response = await _dio.get<List<dynamic>>(
      '/protected/patients/current/linkedAccounts/results/headers/all',
    );
    return response.data!
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> fetchResultDetail(int resultId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/protected/patients/current/linkedAccounts/results/$resultId',
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<Map<String, dynamic>> fetchAllResultsForImport() async {
    try {
      return await _fetchAllResultsForImport();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        await ensureBrowserPortalSession();
        return _fetchAllResultsForImport();
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _fetchAllResultsForImport() async {
    final headers = await fetchResultHeaders();
    final reports = <Map<String, dynamic>>[];

    for (final header in headers) {
      if (header['isDetailAvailable'] == true) {
        final resultId = header['id'];
        if (resultId is int) {
          reports.add(await fetchResultDetail(resultId));
        } else if (resultId is num) {
          reports.add(await fetchResultDetail(resultId.toInt()));
        }
      }
    }

    return {'headers': headers, 'reports': reports};
  }
}
