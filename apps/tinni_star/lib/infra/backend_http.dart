import 'dart:async';
import 'dart:convert';
import 'dart:io';

const backendRequestTimeout = Duration(seconds: 15);

Future<HttpClientRequest> openBackendRequest(
  HttpClient client,
  String method,
  Uri uri, {
  Duration timeout = backendRequestTimeout,
}) async {
  var accepting = true;
  try {
    return await client.openUrl(method, uri).then((request) {
      // Release a request that finishes connecting after its caller timed out.
      if (!accepting) request.abort();
      return request;
    }).timeout(timeout);
  } finally {
    accepting = false;
  }
}

Future<HttpClientResponse> closeBackendRequest(
  HttpClientRequest request, {
  Duration timeout = backendRequestTimeout,
}) async {
  try {
    return await request.close().timeout(timeout);
  } catch (error) {
    request.abort(error);
    rethrow;
  }
}

Future<String> readBackendResponse(
  HttpClientResponse response, {
  Duration timeout = backendRequestTimeout,
}) =>
    utf8.decoder
        .bind(response)
        .timeout(timeout, onTimeout: (sink) {
          sink.addError(TimeoutException('Server response timed out', timeout));
          sink.close();
        })
        .join();
