import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The frame-level texture every screen carries: a film-grain background layer
/// beneath the content and a 1px luminous hairline across the top edge.
///
/// Wrapped around the shell and the auth page rather than applied per-panel, so
/// the grain tiles continuously across the whole frame instead of restarting at
/// each card. The grain paints first so every opaque surface (sidebar, top bar,
/// cards, popovers) occludes it; only the bare frame background shows it. Both
/// layers are non-interactive.
class FrameTexture extends StatelessWidget {
  const FrameTexture({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: IgnorePointer(child: _Grain())),
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: AppTexture.topHairline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Grain extends StatefulWidget {
  const _Grain();

  @override
  State<_Grain> createState() => _GrainState();
}

class _GrainState extends State<_Grain> {
  ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    _loadTile();
  }

  Future<void> _loadTile() async {
    final tile = await _grainTile();
    if (mounted) setState(() => _tile = tile);
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    // Until the tile decodes there is simply no grain — it is texture, so
    // there's nothing to reserve space for or fall back to.
    if (tile == null) return const SizedBox.shrink();
    return CustomPaint(painter: _GrainPainter(tile));
  }
}

/// Decoded once for the whole app: the tile is 140×140 and identical on every
/// frame, so re-generating it per screen would be pure waste.
Future<ui.Image>? _grainTileFuture;

Future<ui.Image> _grainTile() {
  return _grainTileFuture ??= _decodeGrainTile();
}

Future<ui.Image> _decodeGrainTile() {
  const size = AppTexture.grainTile;
  final pixels = Uint8List(size * size * 4);
  // Seeded so the grain is identical across launches — a texture that reshuffles
  // on every restart would show up as flicker in screenshot diffs and tests.
  final random = math.Random(0x5EED);
  const maxAlpha = 255 * AppTexture.grainOpacity;

  for (var i = 0; i < size * size; i++) {
    final offset = i * 4;
    final alpha = (random.nextDouble() * maxAlpha).round();
    // `rgba8888` is *premultiplied*: the channels must already be scaled by
    // alpha. The grain is white, so each channel equals alpha. Writing 255 here
    // instead would be invalid premultiplied data and rasterize as opaque white,
    // painting the whole frame out.
    pixels[offset] = alpha;
    pixels[offset + 1] = alpha;
    pixels[offset + 2] = alpha;
    pixels[offset + 3] = alpha;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    size,
    size,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.tile);

  final ui.Image tile;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ImageShader(
        tile,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.tile != tile;
}
