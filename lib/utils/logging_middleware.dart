import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cnattendance/utils/custom_http_client.dart';
import 'package:cnattendance/utils/api_logger.dart';

class LoggingMiddleware implements http.Client {
  final http.Client _inner;

  LoggingMiddleware._(this._inner);

  static Future<LoggingMiddleware> create() async {
    final client = await CustomHttpClient.getClient();
    return LoggingMiddleware._(client);
  }

  // Legacy constructor for compatibility - creates default client
  LoggingMiddleware(http.Client client) : _inner = client;

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) {
    return _logRequest(() => _inner.head(url, headers: headers), 'HEAD', url,
        headers: headers);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) {
    return _logRequest(() => _inner.get(url, headers: headers), 'GET', url,
        headers: headers);
  }

  @override
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return _logRequest(
        () =>
            _inner.post(url, headers: headers, body: body, encoding: encoding),
        'POST',
        url,
        body: body,
        headers: headers);
  }

  @override
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return _logRequest(
        () => _inner.put(url, headers: headers, body: body, encoding: encoding),
        'PUT',
        url,
        body: body,
        headers: headers);
  }

  @override
  Future<http.Response> patch(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return _logRequest(
        () =>
            _inner.patch(url, headers: headers, body: body, encoding: encoding),
        'PATCH',
        url,
        body: body,
        headers: headers);
  }

  @override
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers, Object? body, Encoding? encoding}) {
    return _logRequest(
        () => _inner.delete(url,
            headers: headers, body: body, encoding: encoding),
        'DELETE',
        url,
        body: body,
        headers: headers);
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) {
    return _inner.read(url, headers: headers);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) {
    return _inner.readBytes(url, headers: headers);
  }

  Future<http.Response> _logRequest(
      Future<http.Response> Function() requestFunction, String method, Uri url,
      {Object? body, Map<String, String>? headers}) async {
    const transientDelay = Duration(milliseconds: 350);
    try {
      // Log request
      ApiLogger.logRequest(
        method: method,
        url: url.toString(),
        body: body,
        headers: headers,
      );

      final response = await requestFunction();

      // Log response
      ApiLogger.logResponse(
        method: method,
        url: url.toString(),
        statusCode: response.statusCode,
        responseBody: response.body,
        headers: response.headers,
      );

      return response;
    } catch (e, stackTrace) {
      final isGet = method == 'GET';
      final isTransientDnsOrConnection =
          e is SocketException ||
          (e is http.ClientException &&
              (e.message.toLowerCase().contains('failed host lookup') ||
                  e.message.toLowerCase().contains('connection abort')));

      if (isGet && isTransientDnsOrConnection) {
        try {
          await Future.delayed(transientDelay);
          final retryResponse = await requestFunction();
          ApiLogger.logResponse(
            method: '$method (retry)',
            url: url.toString(),
            statusCode: retryResponse.statusCode,
            responseBody: retryResponse.body,
            headers: retryResponse.headers,
          );
          return retryResponse;
        } catch (_) {
          // Fall through to the original error log/rethrow path below.
        }
      }

      // Log error
      ApiLogger.logError(
        method: method,
        url: url.toString(),
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
