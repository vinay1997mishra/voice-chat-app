import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Account-scoped app files survive server expiry and normal app restarts.
class LocalChatStore {
  LocalChatStore({Future<Directory> Function()? directoryProvider})
      : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _writes = Future<void>.value();

  Future<Directory> _accountDirectory(String account) async {
    final root = await _directoryProvider();
    final name = sha256.convert(utf8.encode(account)).toString();
    return Directory('${root.path}/private_chats/$name')..createSync(recursive: true);
  }

  Future<Map<String, dynamic>> load(String account) async {
    await _writes;
    final dir = await _accountDirectory(account);
    final file = File('${dir.path}/history.json');
    if (!await file.exists()) return <String, dynamic>{};
    final data = jsonDecode(await file.readAsString());
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> save(String account, Map<String, dynamic> data) {
    final contents = jsonEncode(data);
    final operation = _writes.then((_) async {
      final dir = await _accountDirectory(account);
      final staged = File('${dir.path}/history.json.tmp');
      await staged.writeAsString(contents, flush: true);
      await staged.rename('${dir.path}/history.json');
    });
    _writes = operation.catchError((Object _) {});
    return operation;
  }

  Future<File> _photoFile(String account, String messageId) async {
    final dir = await _accountDirectory(account);
    final name = sha256.convert(utf8.encode(messageId)).toString();
    return File('${dir.path}/photo-$name');
  }

  Future<Uint8List?> readPhoto(String account, String messageId) async {
    final file = await _photoFile(account, messageId);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> savePhoto(String account, String messageId, Uint8List bytes) async {
    final file = await _photoFile(account, messageId);
    final staged = File('${file.path}.tmp');
    await staged.writeAsBytes(bytes, flush: true);
    await staged.rename(file.path);
  }
}
