import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
          headers: const <String, String>{'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(AuthInterceptor(tokenStorage));
  }

  final Dio _dio;

  Dio get raw => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? data) decode,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
      return decode(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    required T Function(Object? data) decode,
  }) async {
    try {
      final response = await _dio.post<Object?>(path, data: data);
      return decode(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    required T Function(Object? data) decode,
  }) async {
    try {
      final response = await _dio.put<Object?>(path, data: data);
      return decode(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<T> delete<T>(
    String path, {
    Object? data,
    required T Function(Object? data) decode,
  }) async {
    try {
      final response = await _dio.delete<Object?>(path, data: data);
      return decode(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppEnvironment.apiBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});
