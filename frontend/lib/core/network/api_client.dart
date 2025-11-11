import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Dio get client => _dio;
}
