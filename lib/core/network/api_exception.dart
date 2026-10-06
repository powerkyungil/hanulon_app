import 'package:dio/dio.dart';

enum ApiErrorType {
  unauthorized,
  forbidden,
  validation,
  network,
  timeout,
  server,
  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
    this.code,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final String? code;

  factory ApiException.fromDio(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;
    final responseJson = responseData is Map<String, dynamic>
        ? responseData
        : null;
    final nestedError = responseJson?['error'];
    final envelopeData = responseJson?['data'];
    final nestedEnvelopeError = envelopeData is Map<String, dynamic>
        ? envelopeData['error']
        : null;
    final errorJson = nestedError is Map<String, dynamic>
        ? nestedError
        : nestedEnvelopeError is Map<String, dynamic>
        ? nestedEnvelopeError
        : responseJson;
    final responseMessage = errorJson?['message'] ?? errorJson?['error'];
    final message = responseMessage is String && responseMessage.isNotEmpty
        ? responseMessage
        : _fallbackMessage(error, statusCode);
    final codeValue = errorJson?['code'];
    final code = codeValue is String ? codeValue : null;

    return ApiException(
      type: _typeFor(error, statusCode),
      message: message,
      statusCode: statusCode,
      code: code,
    );
  }

  static ApiErrorType _typeFor(DioException error, int? statusCode) {
    if (statusCode == 401) return ApiErrorType.unauthorized;
    if (statusCode == 403) return ApiErrorType.forbidden;
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return ApiErrorType.validation;
    }
    if (statusCode != null && statusCode >= 500) return ApiErrorType.server;
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return ApiErrorType.timeout;
    }
    if (error.type == DioExceptionType.connectionError) {
      return ApiErrorType.network;
    }
    return ApiErrorType.unknown;
  }

  static String _fallbackMessage(DioException error, int? statusCode) {
    if (statusCode == 401) return '로그인이 만료되었습니다.';
    if (statusCode == 403) return '이 작업을 수행할 권한이 없습니다.';
    if (statusCode != null && statusCode >= 500) {
      return '서버에서 요청을 처리하지 못했습니다.';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return '요청 시간이 초과되었습니다.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return '네트워크 연결을 확인해 주세요.';
    }
    return '요청을 처리하지 못했습니다.';
  }

  @override
  String toString() => message;
}
