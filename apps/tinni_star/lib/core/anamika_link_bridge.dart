import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';

import 'anamika_connector.dart';
import 'connector_persistence.dart';

class AnamikaLinkBridge {
  AnamikaLinkBridge({
    required this.connector,
    required this.persistence,
    AppLinks? appLinks,
  }) : _appLinks = appLinks ?? AppLinks();

  final AnamikaConnector connector;
  final ConnectorPersistence persistence;
  final AppLinks _appLinks;

  final StreamController<String> _responses =
      StreamController<String>.broadcast();
  StreamSubscription<Uri>? _subscription;
  String? _pairingToken;

  Stream<String> get responses => _responses.stream;
  String? get pairingToken => _pairingToken;

  Future<void> start() async {
    _pairingToken = await persistence.getOrCreatePairingToken();
    _subscription ??= _appLinks.uriLinkStream.listen(
      (uri) => handleUri(uri),
      onError: (Object error) {
        _responses.add(
          jsonEncode({
            'ok': false,
            'type': 'link_error',
            'message': error.toString(),
          }),
        );
      },
    );
  }

  Future<String> handleUri(Uri uri) async {
    if (uri.scheme != 'tinnistar' || uri.host != 'anamika') {
      return _emitError('Unsupported connector URI.');
    }

    final token = uri.queryParameters['token'];
    if (token == null || token != _pairingToken) {
      return _emitError('Pairing token verification failed.');
    }

    final command = uri.queryParameters['command'];
    if (command == null || command.isEmpty) {
      return _emitError('Connector command is missing.');
    }

    try {
      final decoded = jsonDecode(command);
      if (decoded is! Map<String, dynamic>) {
        return _emitError('Connector command must be a JSON object.');
      }

      final response = connector.handleCommandJson(
        command,
        ownerApproved: true,
      );
      final responseMap = jsonDecode(response) as Map<String, dynamic>;
      final ok = responseMap['ok'] == true;

      if (ok && decoded['type'] == 'apply_pack') {
        final pack = decoded['pack'];
        if (pack is Map<String, dynamic>) {
          await persistence.recordApplied(jsonEncode(pack));
        }
      } else if (ok && decoded['type'] == 'rollback') {
        await persistence.recordRollback();
      }

      _responses.add(response);
      return response;
    } catch (error) {
      return _emitError(error.toString());
    }
  }

  String _emitError(String message) {
    final response = jsonEncode({
      'ok': false,
      'type': 'connector_error',
      'message': message,
    });
    _responses.add(response);
    return response;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _responses.close();
  }
}
