import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'dynamic_gifts_v08.dart';

class DynamicGiftManagerV08 extends StatefulWidget {
  const DynamicGiftManagerV08({
    super.key,
    required this.title,
    required this.vipLevel,
    required this.isAppOwner,
    this.roomId,
  });

  final String title;
  final int vipLevel;
  final bool isAppOwner;
  final String? roomId;

  @override
  State<DynamicGiftManagerV08> createState() => _DynamicGiftManagerV08State();
}

class _DynamicGiftManagerV08State extends State<DynamicGiftManagerV08> {
  final ImagePicker _picker = ImagePicker();

  List<GiftLeaseV08> get _allowedLeases => widget.isAppOwner
      ? GiftLeaseV08.values
      : roomGiftLeasesForVipV08(widget.vipLevel);

  List<DynamicGiftV08> get _visibleGifts => widget.isAppOwner
      ? dynamicGiftStoreV08.gifts
      : dynamicGiftStoreV08.forRoomOwner(widget.roomId ?? '');

  @override
  Widget build(BuildContext context) {
    final leases = _allowedLeases;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Video Gift Rules',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Video maximum 8 seconds'),
                  const Text('• File maximum 12 MB'),
                  const Text('• Expired gifts automatically hide from users'),
                  if (!widget.isAppOwner) ...[
                    const SizedBox(height: 8),
                    Text('Your room VIP: VIP ' + widget.vipLevel.toString()),
                    const Text(
                      'VIP8: 15 days • VIP9: up to 1 month • VIP10: up to 3 months • VIP11: up to 6 months or Lifetime',
                    ),
                  ] else
                    const Text(
                      'App Owner can use 15d / 1m / 3m / 6m / Lifetime and can disable or remove any uploaded gift.',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (leases.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.lock_rounded),
                title: Text('VIP8+ required'),
                subtitle: Text(
                  'Room owners need VIP8 or above to upload video gifts.',
                ),
              ),
            )
          else
            FilledButton.icon(
              key: const Key('add-video-gift-v08'),
              onPressed: _addGift,
              icon: const Icon(Icons.video_call_rounded),
              label: const Text('Add Gift Video'),
            ),
          const SizedBox(height: 18),
          Text(
            widget.isAppOwner ? 'All Dynamic Gifts' : 'My Room Video Gifts',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (_visibleGifts.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No video gifts added yet'),
                subtitle: Text('Use Add Gift Video to create one.'),
              ),
            ),
          for (final gift in _visibleGifts) _giftTile(gift),
        ],
      ),
    );
  }

  Widget _giftTile(DynamicGiftV08 gift) {
    final expiry = gift.expiresAt;
    final expired = expiry != null && !DateTime.now().isBefore(expiry);
    final scope = gift.isGlobal ? 'Global' : 'Room only';
    final status = expired ? ' • Expired' : '';
    return Card(
      key: ValueKey('dynamic-gift-' + gift.id),
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.ondemand_video_rounded),
            ),
            title: Text(gift.name),
            subtitle: Text(
              gift.coins.toString() +
                  ' Coins • ' +
                  gift.lease.label +
                  '\n' +
                  gift.durationLabel +
                  ' • ' +
                  gift.sizeLabel +
                  ' • ' +
                  scope +
                  status,
            ),
            isThreeLine: true,
          ),
          if (widget.isAppOwner)
            SwitchListTile(
              dense: true,
              title: const Text('Visible to users'),
              value: gift.enabled,
              onChanged: (value) {
                setState(() {
                  dynamicGiftStoreV08.setEnabled(gift.id, value);
                });
              },
            ),
          ButtonBar(
            children: [
              TextButton.icon(
                onPressed: gift.localFileExists
                    ? () => DynamicGiftVideoEffectV08.show(context, gift)
                    : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Preview'),
              ),
              TextButton.icon(
                key: ValueKey('remove-dynamic-gift-' + gift.id),
                onPressed: () {
                  setState(() {
                    dynamicGiftStoreV08.remove(gift.id);
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addGift() async {
    final leases = _allowedLeases;
    if (leases.isEmpty) return;

    final name = TextEditingController();
    final coins = TextEditingController(text: '10000');
    GiftLeaseV08 selectedLease = leases.last;
    _ValidatedGiftVideoV08? selectedVideo;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Video Gift',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('dynamic-gift-name-v08'),
                  controller: name,
                  maxLength: 32,
                  decoration: const InputDecoration(
                    labelText: 'Gift name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('dynamic-gift-coins-v08'),
                  controller: coins,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Gift price in Coins',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<GiftLeaseV08>(
                  key: const Key('dynamic-gift-lease-v08'),
                  value: selectedLease,
                  decoration: const InputDecoration(
                    labelText: 'Gift availability',
                    border: OutlineInputBorder(),
                  ),
                  items: leases
                      .map(
                        (lease) => DropdownMenuItem(
                          value: lease,
                          child: Text(lease.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setLocal(() => selectedLease = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('pick-gift-video-v08'),
                  onPressed: () async {
                    final video = await _pickValidatedVideo(sheetContext);
                    if (video != null) {
                      setLocal(() => selectedVideo = video);
                    }
                  },
                  icon: const Icon(Icons.video_library_rounded),
                  label: Text(
                    selectedVideo == null
                        ? 'Select Video (max 8 sec / 12 MB)'
                        : 'Selected: ' +
                            selectedVideo!.durationLabel +
                            ' • ' +
                            selectedVideo!.sizeLabel,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Videos longer than 8 seconds or larger than 12 MB are rejected.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  key: const Key('save-dynamic-gift-v08'),
                  onPressed: () {
                    final cleanName = name.text.trim();
                    final price = int.tryParse(coins.text.trim()) ?? 0;
                    if (cleanName.isEmpty || price <= 0 || selectedVideo == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Add name, valid price and a valid video'),
                        ),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final video = selectedVideo!;
                    dynamicGiftStoreV08.add(
                      DynamicGiftV08(
                        id: now.microsecondsSinceEpoch.toString(),
                        name: cleanName,
                        coins: price,
                        videoPath: video.path,
                        videoBytes: video.bytes,
                        videoDuration: video.duration,
                        lease: selectedLease,
                        createdAt: now,
                        createdBy: widget.isAppOwner ? 'App Owner' : 'Room Owner',
                        roomId: widget.isAppOwner ? null : widget.roomId,
                      ),
                    );
                    setState(() {});
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Add Gift'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    coins.dispose();
    if (mounted) setState(() {});
  }

  Future<_ValidatedGiftVideoV08?> _pickValidatedVideo(
    BuildContext feedbackContext,
  ) async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: dynamicGiftMaxVideoDurationV08,
    );
    if (picked == null) return null;

    final bytes = await picked.length();
    if (bytes > dynamicGiftMaxVideoBytesV08) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          const SnackBar(content: Text('Video must be 12 MB or smaller')),
        );
      }
      return null;
    }

    final controller = VideoPlayerController.file(File(picked.path));
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      if (duration <= Duration.zero ||
          duration > dynamicGiftMaxVideoDurationV08) {
        if (feedbackContext.mounted) {
          ScaffoldMessenger.of(feedbackContext).showSnackBar(
            const SnackBar(content: Text('Video must be 8 seconds or shorter')),
          );
        }
        return null;
      }
      return _ValidatedGiftVideoV08(
        path: picked.path,
        bytes: bytes,
        duration: duration,
      );
    } catch (_) {
      if (feedbackContext.mounted) {
        ScaffoldMessenger.of(feedbackContext).showSnackBar(
          const SnackBar(content: Text('Could not read this video file')),
        );
      }
      return null;
    } finally {
      await controller.dispose();
    }
  }
}

class _ValidatedGiftVideoV08 {
  const _ValidatedGiftVideoV08({
    required this.path,
    required this.bytes,
    required this.duration,
  });

  final String path;
  final int bytes;
  final Duration duration;

  String get sizeLabel =>
      (bytes / (1024 * 1024)).toStringAsFixed(1) + ' MB';

  String get durationLabel =>
      (duration.inMilliseconds / 1000).toStringAsFixed(1) + ' sec';
}

class DynamicGiftVideoEffectV08 extends StatefulWidget {
  const DynamicGiftVideoEffectV08({
    super.key,
    required this.gift,
  });

  final DynamicGiftV08 gift;

  static Future<void> show(
    BuildContext context,
    DynamicGiftV08 gift,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: DynamicGiftVideoEffectV08(gift: gift),
      ),
    );
  }

  @override
  State<DynamicGiftVideoEffectV08> createState() =>
      _DynamicGiftVideoEffectV08State();
}

class _DynamicGiftVideoEffectV08State
    extends State<DynamicGiftVideoEffectV08> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.gift.videoPath));
    _init();
  }

  Future<void> _init() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.play();
      if (mounted) setState(() => _ready = true);
      _controller.addListener(_closeWhenFinished);
    } catch (_) {
      _closeSafely();
    }
  }

  void _closeWhenFinished() {
    if (!_controller.value.isInitialized) return;
    if (_controller.value.position >= _controller.value.duration &&
        !_controller.value.isPlaying) {
      _closeSafely();
    }
  }

  void _closeSafely() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller.removeListener(_closeWhenFinished);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: _ready
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const CircularProgressIndicator(),
        ),
        Positioned(
          top: 36,
          right: 16,
          child: IconButton.filledTonal(
            onPressed: _closeSafely,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 36,
          child: Text(
            widget.gift.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
