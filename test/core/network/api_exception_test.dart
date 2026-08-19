import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_guild_app/core/network/api_exception.dart';

void main() {
  test('v1 error envelope의 code와 message를 읽는다', () {
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/api/v1/auth/login'),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: '/api/v1/auth/login'),
          statusCode: 401,
          data: <String, dynamic>{
            'error': <String, dynamic>{
              'code': 'INVALID_CREDENTIALS',
              'message': '아이디 또는 비밀번호가 올바르지 않습니다.',
            },
          },
        ),
      ),
    );

    expect(exception.type, ApiErrorType.unauthorized);
    expect(exception.code, 'INVALID_CREDENTIALS');
    expect(exception.message, '아이디 또는 비밀번호가 올바르지 않습니다.');
  });
}
