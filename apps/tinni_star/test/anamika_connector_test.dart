import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tinni_star/core/anamika_connector.dart';
import 'package:tinni_star/core/function_pack.dart';

void main() {
  AnamikaConnector makeConnector() => AnamikaConnector(
        runtime: FunctionPackRuntime(
          signatureVerifier: const DevelopmentSignatureVerifier(),
        ),
      );

  test('diagnostic command returns Tinni Star snapshot', () {
    final connector = makeConnector();
    final result = jsonDecode(
      connector.handleCommandJson(
        '{"type":"diagnostics"}',
        ownerApproved: true,
      ),
    ) as Map<String, dynamic>;
    expect(result['ok'], true);
    expect((result['data'] as Map<String, dynamic>)['app'], 'Tinni Star');
  });

  test('apply_pack command changes compatible runtime config', () {
    final connector = makeConnector();
    final command = jsonEncode({
      'type': 'apply_pack',
      'pack': {
        'id': 'room-core',
        'version': 1,
        'minSchema': 1,
        'maxSchema': 1,
        'summary': 'test pack',
        'signature': 'TINNI_DEV_SIGNED',
        'config': {
          'seatCount': 20,
          'inviteMode': false,
          'gamesEnabled': true,
        },
      },
    });
    final result = jsonDecode(
      connector.handleCommandJson(command, ownerApproved: true),
    ) as Map<String, dynamic>;
    expect(result['ok'], true);
    expect(connector.runtime.config.seatCount, 20);
    expect(connector.runtime.config.gamesEnabled, true);
  });

  test('apply_pack still rejects without owner approval', () {
    final connector = makeConnector();
    final command = jsonEncode({
      'type': 'apply_pack',
      'pack': {
        'id': 'room-core',
        'version': 1,
        'minSchema': 1,
        'maxSchema': 1,
        'summary': 'test pack',
        'signature': 'TINNI_DEV_SIGNED',
        'config': {'seatCount': 20},
      },
    });
    final result = jsonDecode(
      connector.handleCommandJson(command, ownerApproved: false),
    ) as Map<String, dynamic>;
    expect(result['ok'], false);
    expect(connector.runtime.config.seatCount, 12);
  });
}
