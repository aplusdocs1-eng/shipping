import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Looping background video with a graceful fallback. Shows [fallback]
/// immediately, cross-fades to the first real video frame once it's ready,
/// and falls back permanently (never crashes, never blocks the page) if the
/// video fails to load. Muted + looping — browsers require silence for
/// autoplay, and every use of this widget is ambient decoration, never a
/// video with a soundtrack meant to be heard.
///
/// Shared by the public landing page hero and the admin dashboard shell —
/// extracted here once both needed the exact same video-lifecycle handling
/// rather than duplicating it.
///
/// Deliberately not FittedBox for the cover-fit sizing: FittedBox achieves
/// BoxFit through a scale Transform, and platform views (the underlying
/// <video> is a real embedded DOM element on web, not canvas-painted) don't
/// reliably support being wrapped in one — an earlier version of this
/// wrapped in FittedBox and the video rendered oversized and mispositioned
/// as a result, bleeding outside its intended bounds. ClipRect +
/// LayoutBuilder + OverflowBox gets the same "cover" result through plain
/// sizing/positioning instead, which platform views do handle correctly.
class VideoBackdrop extends StatefulWidget {
  final bool enabled;
  final String assetPath;
  // Empty = use assetPath.
  final String networkUrl;
  final Widget fallback;
  const VideoBackdrop({
    super.key,
    required this.enabled,
    required this.assetPath,
    this.networkUrl = '',
    required this.fallback,
  });

  @override
  State<VideoBackdrop> createState() => _VideoBackdropState();
}

class _VideoBackdropState extends State<VideoBackdrop> {
  VideoPlayerController? _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _init();
  }

  @override
  void didUpdateWidget(covariant VideoBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled &&
        widget.networkUrl == oldWidget.networkUrl &&
        widget.assetPath == oldWidget.assetPath) {
      return;
    }
    // Callers whose video URL can change after first mount (the public
    // hero, which renders default content before swapping in a real
    // site_content override a moment later) need this — initState alone
    // already ran once with whatever URL was current at first build, and
    // would otherwise never notice a different one arriving later.
    final oldController = _controller;
    _controller = null;
    _ready = false;
    oldController?.dispose();
    if (widget.enabled) _init();
  }

  Future<void> _init() async {
    try {
      final url = widget.networkUrl.trim();
      // A malformed admin-pasted URL throwing belongs inside this try too,
      // same as every other way loading can fail.
      final controller = url.isEmpty
          ? VideoPlayerController.asset(widget.assetPath)
          : VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(true);
      await controller.setVolume(
        0,
      ); // muted — required for autoplay in every browser
      await controller.play();
      if (!mounted) return;
      // Mount the video layer at opacity 0 first, then flip it to 1 on the
      // next frame so AnimatedOpacity below has an actual transition to
      // animate instead of just appearing at full opacity on first build.
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _ready = true);
      });
    } catch (e) {
      // Slow connection, codec issue, whatever — the fallback just stays
      // up. A background video is decoration, never load-bearing.
      // ignore: avoid_print
      print('[VideoBackdrop] failed to load: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.fallback,
        if (controller != null && controller.value.isInitialized)
          AnimatedOpacity(
            opacity: _ready ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final videoSize = controller.value.size;
                  final containerW = constraints.maxWidth;
                  final containerH = constraints.maxHeight;
                  if (videoSize.width <= 0 ||
                      videoSize.height <= 0 ||
                      !containerW.isFinite ||
                      !containerH.isFinite ||
                      containerW <= 0 ||
                      containerH <= 0) {
                    return const SizedBox.shrink();
                  }
                  final videoAspect = videoSize.width / videoSize.height;
                  final containerAspect = containerW / containerH;
                  final double w, h;
                  if (containerAspect > videoAspect) {
                    w = containerW;
                    h = w / videoAspect;
                  } else {
                    h = containerH;
                    w = h * videoAspect;
                  }
                  return OverflowBox(
                    maxWidth: w,
                    maxHeight: h,
                    child: SizedBox(
                      width: w,
                      height: h,
                      child: VideoPlayer(controller),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
