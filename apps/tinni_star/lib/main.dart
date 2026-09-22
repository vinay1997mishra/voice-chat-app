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
  final authPersistence = AuthPersistence();
  state.attachAuthPersistence(authPersistence);
  await authPersistence.restore(state.auth);

  final bridge = AnamikaLinkBridge(
    connector: state.connector,
    persistence: persistence,
  );
  await bridge.start();
  state.attachConnectorBridge(bridge);

  runApp(TinniStarApp(state: state));
}
