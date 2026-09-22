import 'package:flutter/services.dart';

class RoomForegroundServiceBridge {
  const RoomForegroundServiceBridge();

  static const MethodChannel _channel =
      MethodChannel('tinni.star/room_service');

  Future<bool> start() async {
    try {
      return await _channel.invokeMethod<bool>('start') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> stop() async {
    try {
      return await _channel.invokeMethod<bool>('stop') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
