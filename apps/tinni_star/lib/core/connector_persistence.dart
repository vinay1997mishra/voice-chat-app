import 'package:shared_preferences/shared_preferences.dart';

import 'function_pack.dart';
import 'function_pack_codec.dart';
import 'connector_security.dart';

class ConnectorPersistence {
  ConnectorPersistence({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  static const _pairingTokenKey = 'tinni.connector.pairing_token';
  static const _activePackKey = 'tinni.connector.active_pack';
  static const _previousPackKey = 'tinni.connector.previous_pack';

  final SharedPreferencesAsync _preferences;

  Future<String> getOrCreatePairingToken() async {
    final existing = await _preferences.getString(_pairingTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = generatePairingToken();
    await _preferences.setString(_pairingTokenKey, created);
    return created;
  }

  Future<void> restore(FunctionPackRuntime runtime) async {
    final previous = await _preferences.getString(_previousPackKey);
    final active = await _preferences.getString(_activePackKey);

    if (previous != null && previous.isNotEmpty) {
      final result = runtime.apply(
        FunctionPackCodec.decode(previous),
        ownerApproved: true,
      );
      if (result.status == PackApplyStatus.rejected) {
        await _preferences.remove(_previousPackKey);
      }
    }

    if (active != null && active.isNotEmpty) {
      final result = runtime.apply(
        FunctionPackCodec.decode(active),
        ownerApproved: true,
      );
      if (result.status == PackApplyStatus.rejected) {
        await _preferences.remove(_activePackKey);
      }
    }
  }

  Future<void> recordApplied(String packPayload) async {
    final active = await _preferences.getString(_activePackKey);
    if (active != null && active.isNotEmpty) {
      await _preferences.setString(_previousPackKey, active);
    }
    await _preferences.setString(_activePackKey, packPayload);
  }

  Future<void> recordRollback() async {
    final active = await _preferences.getString(_activePackKey);
    final previous = await _preferences.getString(_previousPackKey);

    if (previous == null || previous.isEmpty) {
      await _preferences.remove(_activePackKey);
      if (active != null && active.isNotEmpty) {
        await _preferences.setString(_previousPackKey, active);
      }
      return;
    }

    await _preferences.setString(_activePackKey, previous);
    if (active == null || active.isEmpty) {
      await _preferences.remove(_previousPackKey);
    } else {
      await _preferences.setString(_previousPackKey, active);
    }
  }

  Future<void> clearPackHistory() async {
    await _preferences.remove(_activePackKey);
    await _preferences.remove(_previousPackKey);
  }
}
