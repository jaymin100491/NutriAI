import 'package:dio/dio.dart';

bool isTransientNetworkError(Object error) {
  if (error is! DioException) return false;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.badResponse:
      final code = error.response?.statusCode ?? 0;
      // Render/proxy blips while waking
      return code == 502 || code == 503 || code == 504;
    case DioExceptionType.unknown:
      final msg = error.message?.toLowerCase() ?? '';
      return msg.contains('xmlhttprequest') ||
          msg.contains('network') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection');
    default:
      return false;
  }
}

String friendlyAuthError(Object error) {
  if (isTransientNetworkError(error)) {
    return 'Server is still waking up (free hosting). Please try again in a moment.';
  }
  final raw = error.toString();
  if (raw.contains('DioException')) {
    return 'Could not reach NutriAI. Check your connection and try again.';
  }
  return raw.replaceFirst('Exception: ', '');
}
