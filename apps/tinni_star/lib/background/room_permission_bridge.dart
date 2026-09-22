import 'package:flutter/services.dart';

class RoomPermissionBridge {
  const RoomPermissionBridge();

  static const MethodChannel _channel =
      MethodChannel('tinni.star/permissions');

  Future<bool> hasVoiceRoomPermissions() async {
    try {
      return await _channel.invokeMethod<bool>('hasVoiceRoom') ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> requestVoiceRoomPermissions() async {
    try {
      return await _channel.invokeMethod<bool>('requestVoiceRoom') ?? false;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return false;
    }
  }
}
