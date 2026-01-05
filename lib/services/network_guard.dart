import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const Duration kNetworkTimeout = Duration(seconds: 8);

class NetworkException implements Exception {
  NetworkException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

String formatNetworkError(Object error) {
  if (error is NetworkException) return error.message;
  if (error is TimeoutException) return '网络超时，请检查服务器是否可访问';
  if (error is SocketException) return '无法连接服务器，请检查网络/服务器地址/端口';
  return error.toString();
}

Future<T> runWithNetworkGuard<T>(
  Future<T> Function() action, {
  Duration timeout = kNetworkTimeout,
}) async {
  try {
    return await action().timeout(timeout);
  } on NetworkException {
    rethrow;
  } on TimeoutException catch (e) {
    throw NetworkException('网络超时，请检查服务器是否可访问', cause: e);
  } on SocketException catch (e) {
    throw NetworkException('无法连接服务器，请检查网络/服务器地址/端口', cause: e);
  } catch (e) {
    throw NetworkException(e.toString(), cause: e);
  }
}

Future<http.Response> guardedGet(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = kNetworkTimeout,
}) {
  return runWithNetworkGuard(
    () => client.get(uri, headers: headers),
    timeout: timeout,
  );
}

Future<http.Response> guardedPost(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
  Duration timeout = kNetworkTimeout,
}) {
  return runWithNetworkGuard(
    () => client.post(uri, headers: headers, body: body, encoding: encoding),
    timeout: timeout,
  );
}
