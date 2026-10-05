import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

import '../config/app_config.dart';

Dio createPortalDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.labcorpPortalApiUrl,
      connectTimeout: const Duration(milliseconds: 45000),
      receiveTimeout: const Duration(milliseconds: 45000),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
  return dio;
}
