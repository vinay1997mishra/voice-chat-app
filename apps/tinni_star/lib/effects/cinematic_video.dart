import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../economy/premium_gift_catalog.dart';

/// Local-only media paths; gift prices and recipients remain server-owned.
class CinematicAssets {
  static String? movieFor(String id) {
    final rocket = RegExp(r'^rocket-([1-9]|10)$').hasMatch(id);
    if (!rocket && PremiumGiftCatalog.find(id) == null) return null;
    return 'assets/cinematic/$id.mp4';
  }

  static String posterFor(String id) => 'assets/cinematic/$id.png';
}

/// The parent owns delivery timing. Decoder failures only change the visual.
class CinematicVideo extends StatefulWidget {
  const CinematicVideo({
    super.key,
    required this.sceneId,
    required this.duration,
    required this.timeline,
    required this.fallback,
    this.fit = BoxFit.contain,
  });

  final String sceneId;
  final Duration duration;
  final Animation<double> timeline;
  final Widget fallback;
  final BoxFit fit;

  @override
  State<CinematicVideo> createState() => _CinematicVideoState();
}

class _CinematicVideoState extends State<CinematicVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  int _generation = 0;
  bool _foreground = true;
  bool _reducedMotion = false;
  bool _prepared = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _release();
      _prepared = false;
    }
    if (!_prepared && !_reducedMotion) {
      _prepared = true;
      unawaited(_prepare());
    }
  }

  @override
  void didUpdateWidget(covariant CinematicVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sceneId != widget.sceneId ||
        oldWidget.timeline != widget.timeline) {
      _release();
      _prepared = false;
      _failed = false;
      if (!_reducedMotion) {
        _prepared = true;
        unawaited(_prepare());
      }
    }
  }

  Future<void> _prepare() async {
    final path = CinematicAssets.movieFor(widget.sceneId);
    if (path == null) return;
    final token = ++_generation;
    final bundle = DefaultAssetBundle.of(context);
    VideoPlayerController? controller;
    try {
      await bundle.load(path);
      if (!mounted || token != _generation) return;
      controller = VideoPlayerController.asset(
        path,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _video = controller;
      controller.addListener(_playerChanged);
      await controller.initialize().timeout(const Duration(seconds: 4));
      if (!mounted || token != _generation) return;
      await controller.setVolume(0);
      await controller.setLooping(false);
      await controller.seekTo(Duration(
        microseconds:
            (widget.duration.inMicroseconds * widget.timeline.value).round(),
      ));
      if (!mounted || token != _generation) return;
      if (_foreground) await controller.play();
      if (mounted && token == _generation) setState(() {});
    } catch (_) {
      if (!mounted || token != _generation) return;
      _failed = true;
      _release();
      setState(() {});
    }
  }

  void _playerChanged() {
    final controller = _video;
    if (controller == null || !controller.value.hasError || _failed) return;
    _failed = true;
    _release();
    if (mounted) setState(() {});
  }

  void _release() {
    _generation++;
    final controller = _video;
    _video = null;
    if (controller != null) {
      controller.removeListener(_playerChanged);
      unawaited(controller.dispose().catchError((Object _) {}));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    unawaited((_foreground ? controller.play() : controller.pause())
        .catchError((Object _) {}));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reducedMotion) {
      return Image.asset(
        CinematicAssets.posterFor(widget.sceneId),
        key: ValueKey('cinematic-poster-' + widget.sceneId),
        fit: widget.fit,
        errorBuilder: (_, error, stackTrace) => widget.fallback,
      );
    }
    final controller = _video;
    if (_failed || controller == null || !controller.value.isInitialized) {
      return widget.fallback;
    }
    return SizedBox.expand(
      key: ValueKey('cinematic-video-' + widget.sceneId),
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}
