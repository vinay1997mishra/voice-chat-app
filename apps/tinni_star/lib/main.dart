import 'package:flutter/material.dart';

import 'app/tinni_app.dart';
import 'app/tinni_state.dart';
import 'core/function_pack.dart';

void main() {
  final runtime = FunctionPackRuntime(
    signatureVerifier: const DevelopmentSignatureVerifier(),
  );
  runApp(TinniStarApp(state: TinniState(runtime: runtime)));
}
