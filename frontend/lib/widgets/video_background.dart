import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBackground extends StatefulWidget {
  final Widget child;
  final String videoPath;
  final BoxFit fit;
  final bool muted;
  final bool loop;

  const VideoBackground({
    super.key,
    required this.child,
    required this.videoPath,
    this.fit = BoxFit.cover,
    this.muted = true,
    this.loop = true,
  });

  @override
  State<VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<VideoBackground> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.videoPath)
      ..initialize().then((_) {
        if (mounted) setState(() {});
        if (widget.loop) _controller.setLooping(true);
        _controller.setVolume(widget.muted ? 0 : 1);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_controller.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: widget.fit,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          Container(color: Colors.grey.shade200), // пока грузится
        widget.child,
      ],
    );
  }
}