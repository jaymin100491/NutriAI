import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/tracking_model.dart';

class TrackingRepository {
  final DioClient _dioClient;

  TrackingRepository(this._dioClient);

  Future<List<DailyTracking>> getDailyTracking({int days = 400}) async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/tracking/daily',
        queryParameters: {'days': days},
      );
      return (response.data as List)
          .map((json) => DailyTracking.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch tracking data: $e');
    }
  }

  Future<ProgressData> getProgress({int days = 400}) async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.apiV1}/tracking/progress',
        queryParameters: {'days': days},
      );
      return ProgressData.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch progress: $e');
    }
  }

  Future<DailyTracking> submitTracking(DailyTracking tracking) async {
    try {
      final response = await _dioClient.dio.post(
        '${ApiConstants.apiV1}/tracking/daily',
        data: tracking.toJson(),
      );
      return DailyTracking.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to submit tracking: $e');
    }
  }
}
