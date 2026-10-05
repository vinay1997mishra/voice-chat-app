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
    final opening = switch (method.toUpperCase()) {
      'GET' => client.getUrl(uri),
      'POST' => client.postUrl(uri),
      'PUT' => client.putUrl(uri),
      'PATCH' => client.patchUrl(uri),
      'DELETE' => client.deleteUrl(uri),
      'HEAD' => client.headUrl(uri),
      _ => client.openUrl(method, uri),
    };
    return await opening.then((request) {
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
    utf8.decoder.bind(response).join().timeout(timeout);
