import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/tinni_app.dart';
import 'app/tinni_state.dart';
import 'auth/auth_persistence.dart';
import 'core/anamika_link_bridge.dart';
import 'core/connector_persistence.dart';
import 'core/connector_security.dart';
import 'core/function_pack.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final persistence = ConnectorPersistence();
  final pairingToken = await persistence.getOrCreatePairingToken();
  final runtime = FunctionPackRuntime(
    signatureVerifier: PairingHmacSignatureVerifier(pairingToken),
  );
  await persistence.restore(runtime);

  final state = TinniState(runtime: runtime);

  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    state.crashReporter.record(details.exception, details.stack);
    previousFlutterError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    state.crashReporter.record(error, stackTrace);
    return false;
  };

  final authPersistence = AuthPersistence();
  state.attachAuthPersistence(authPersistence);
  final restored = await authPersistence.restore(state.auth);
  if (restored && state.auth.current != null) {
    state.profile.loadFromAccount(state.auth.current!);
    await state.push.register(state.auth.current!.userId);
  }

  await state.refreshRemoteConfig();
  state.analytics.event('app_start', <String, Object?>{
    'auth_restored': restored,
  });

  final bridge = AnamikaLinkBridge(
    connector: state.connector,
    persistence: persistence,
  );
  await bridge.start();
  state.attachConnectorBridge(bridge);

  runApp(TinniStarApp(state: state));
}
