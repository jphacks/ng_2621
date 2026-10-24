import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A non-interactive sprite. Wrap in a button when actions are needed.
class PixelSprite extends StatefulWidget {
  const PixelSprite({
    super.key,
    required this.assetPath,
    required this.sourceRect,
    this.scale = 3,
    this.semanticLabel,
  }) : assert(scale > 0 && scale < double.infinity);

  final String assetPath;
  final Rect sourceRect;

  /// Logical pixels per source pixel. Prefer integer scales for pixel artwork.
  final double scale;
  final String? semanticLabel;

  @override
  State<PixelSprite> createState() => _PixelSpriteState();
}

class _PixelSpriteState extends State<PixelSprite> {
  ImageStream? _stream;
  ImageInfo? _imageInfo;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PixelSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _imageInfo?.dispose();
      _imageInfo = null;
      _resolve();
    }
  }

  void _resolve() {
    // The sheet is decoded once and shared through Flutter's image cache.
    final stream = AssetImage(widget.assetPath)
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final previous = _imageInfo;
    setState(() => _imageInfo = info);
    previous?.dispose();
  }

  void _onError(Object error, StackTrace? stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'Zoo pixel sprites',
        context: ErrorDescription('while loading ${widget.assetPath}'),
      ),
    );
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _imageInfo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = widget.sourceRect;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: rect.width * widget.scale,
        height: rect.height * widget.scale,
        child: CustomPaint(painter: _SpritePainter(_imageInfo?.image, rect)),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.image, this.sourceRect);

  final ui.Image? image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    final image = this.image;
    if (image == null) return;
    canvas.drawImageRect(
      image,
      sourceRect,
      Offset.zero & size,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.sourceRect != sourceRect;
}
