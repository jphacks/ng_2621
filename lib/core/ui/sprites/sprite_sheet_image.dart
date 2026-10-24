import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Resolves a cached sheet and owns its image handle for the builder lifetime.
class SpriteSheetImage extends StatefulWidget {
  const SpriteSheetImage({
    super.key,
    required this.assetPath,
    required this.builder,
  });
  final String assetPath;
  final Widget Function(BuildContext context, ui.Image? image) builder;
  @override
  State<SpriteSheetImage> createState() => _SpriteSheetImageState();
}

class _SpriteSheetImageState extends State<SpriteSheetImage> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SpriteSheetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _info?.dispose();
      _info = null;
      _resolve();
    }
  }

  void _resolve() {
    final stream = AssetImage(widget.assetPath)
        .resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream;
    stream.addListener(_listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final previous = _info;
    setState(() => _info = info);
    previous?.dispose();
  }

  void _onError(Object error, StackTrace? stackTrace) =>
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Zoo sprite sheets',
          context: ErrorDescription('while loading ${widget.assetPath}'),
        ),
      );
  @override
  Widget build(BuildContext context) => widget.builder(context, _info?.image);
  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }
}
