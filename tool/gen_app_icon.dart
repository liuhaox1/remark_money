import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  final root = Directory.current.path;
  final outBase = _join(root, 'assets', 'app_icon');
  Directory(outBase).createSync(recursive: true);

  final base1024 = _renderIcon(1024);
  _writePng(_join(outBase, 'app_icon_1024.png'), base1024);

  // Android launcher icons (ic_launcher.png)
  final androidRes = _join(root, 'android', 'app', 'src', 'main', 'res');
  _writeAndroidMipmaps(androidRes, base1024);

  // iOS AppIcon assets
  final iosAppIcon = _join(
    root,
    'ios',
    'Runner',
    'Assets.xcassets',
    'AppIcon.appiconset',
  );
  _writeIosAppIcons(iosAppIcon, base1024);

  // macOS AppIcon assets
  final macosAppIcon = _join(
    root,
    'macos',
    'Runner',
    'Assets.xcassets',
    'AppIcon.appiconset',
  );
  _writeMacosAppIcons(macosAppIcon, base1024);

  // Windows ICO
  final windowsIco = _join(root, 'windows', 'runner', 'resources', 'app_icon.ico');
  _writeWindowsIco(windowsIco, base1024);

  // Web
  final webIconsDir = _join(root, 'web', 'icons');
  _writeWebIcons(webIconsDir, base1024);
  _writePng(_join(root, 'web', 'favicon.png'), _resize(base1024, 32));

  stdout.writeln('[gen_app_icon] Done.');
}

img.Image _renderIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  // Minimal accounting icon: blue gradient + bold ¥.
  const c1 = 0xFF4F8CFF; // blue
  const c2 = 0xFF2D9CDB; // blue (deeper)
  final r1 = (c1 >> 16) & 0xFF;
  final g1 = (c1 >> 8) & 0xFF;
  final b1 = c1 & 0xFF;
  final r2 = (c2 >> 16) & 0xFF;
  final g2 = (c2 >> 8) & 0xFF;
  final b2 = c2 & 0xFF;

  final s = (size - 1).toDouble();
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = ((x + y) / (2 * s)).clamp(0.0, 1.0);
      var r = (r1 + (r2 - r1) * t).round();
      var g = (g1 + (g2 - g1) * t).round();
      var b = (b1 + (b2 - b1) * t).round();

      // Subtle highlight (top-left), keep it very light.
      final hx = x - size * 0.18;
      final hy = y - size * 0.16;
      final d = math.sqrt(hx * hx + hy * hy) / (size * 0.78);
      final h = (1.0 - d).clamp(0.0, 1.0) * 0.10;
      r = (r + (255 - r) * h).round();
      g = (g + (255 - g) * h).round();
      b = (b + (255 - b) * h).round();

      image.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  // Rounded corner mask.
  final radius = (size * 0.22).round();
  _applyRoundedMask(image, radius);

  // Big bold ¥ (dark, high contrast).
  final yenSize = (size * 0.56).round();
  final yenThickness = math.max(10, (size * 0.030).round());
  final yenColor = img.ColorRgba8(18, 24, 36, 245);
  final yenShadow = img.ColorRgba8(0, 0, 0, 40);

  // Shadow (slight offset) to lift symbol.
  _drawYenSymbol(
    image,
    cx: (size * 0.51).round(),
    cy: (size * 0.47).round() + (size * 0.015).round(),
    size: yenSize,
    color: yenShadow,
    thickness: yenThickness,
  );
  _drawYenSymbol(
    image,
    cx: (size * 0.51).round(),
    cy: (size * 0.47).round(),
    size: yenSize,
    color: yenColor,
    thickness: yenThickness,
  );

  return image;
}

void _drawYenSymbol(
  img.Image image, {
  required int cx,
  required int cy,
  required int size,
  required img.ColorRgba8 color,
  required int thickness,
}) {
  final half = (size / 2).round();
  final top = cy - half;
  final mid = cy - (size * 0.05).round();
  final bottom = cy + half;

  // V legs
  _drawThickLine(image, cx - half, top, cx, mid, thickness, color);
  _drawThickLine(image, cx + half, top, cx, mid, thickness, color);

  // vertical stem
  _drawThickLine(image, cx, mid, cx, bottom, thickness, color);

  // two horizontal bars
  final barW = (size * 0.55).round();
  final y1 = cy - (size * 0.05).round();
  final y2 = cy + (size * 0.10).round();
  _drawThickLine(image, cx - barW, y1, cx + barW, y1, thickness, color);
  _drawThickLine(image, cx - barW, y2, cx + barW, y2, thickness, color);
}

void _applyRoundedMask(img.Image image, int radius) {
  final w = image.width;
  final h = image.height;
  final r2 = radius * radius;
  bool outsideCorner(int x, int y, int cx, int cy) {
    final dx = cx - x;
    final dy = cy - y;
    return dx * dx + dy * dy > r2;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var transparent = false;
      if (x < radius && y < radius) {
        transparent = outsideCorner(x, y, radius, radius);
      } else if (x >= w - radius && y < radius) {
        transparent = outsideCorner(x, y, w - radius - 1, radius);
      } else if (x < radius && y >= h - radius) {
        transparent = outsideCorner(x, y, radius, h - radius - 1);
      } else if (x >= w - radius && y >= h - radius) {
        transparent = outsideCorner(x, y, w - radius - 1, h - radius - 1);
      }
      if (transparent) {
        final p = image.getPixel(x, y);
        image.setPixelRgba(x, y, p.r, p.g, p.b, 0);
      }
    }
  }
}

void _fillRoundedRect(
  img.Image image, {
  required int x,
  required int y,
  required int w,
  required int h,
  required int r,
  required img.ColorRgba8 color,
}) {
  // center rect
  img.fillRect(image, x1: x + r, y1: y, x2: x + w - r, y2: y + h, color: color);
  img.fillRect(image, x1: x, y1: y + r, x2: x + w, y2: y + h - r, color: color);
  // corners
  img.fillCircle(image, x: x + r, y: y + r, radius: r, color: color);
  img.fillCircle(image, x: x + w - r, y: y + r, radius: r, color: color);
  img.fillCircle(image, x: x + r, y: y + h - r, radius: r, color: color);
  img.fillCircle(image, x: x + w - r, y: y + h - r, radius: r, color: color);
}

void _drawThickLine(
  img.Image image,
  int x1,
  int y1,
  int x2,
  int y2,
  int thickness,
  img.ColorRgba8 color,
) {
  final t = math.max(1, thickness);
  for (var i = -t ~/ 2; i <= t ~/ 2; i++) {
    img.drawLine(image, x1: x1, y1: y1 + i, x2: x2, y2: y2 + i, color: color);
  }
}

void _drawRing(
  img.Image image,
  int cx,
  int cy,
  int radius,
  int thickness,
  img.ColorRgba8 color,
) {
  final t = math.max(1, thickness);
  for (var i = 0; i < t; i++) {
    img.drawCircle(image, x: cx, y: cy, radius: radius + i, color: color);
  }
}

img.Image _resize(img.Image src, int size) {
  return img.copyResize(src, width: size, height: size, interpolation: img.Interpolation.cubic);
}

void _writePng(String path, img.Image image) {
  File(path).parent.createSync(recursive: true);
  File(path).writeAsBytesSync(img.encodePng(image, level: 6));
}

void _writeAndroidMipmaps(String resDir, img.Image base1024) {
  final sizes = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  for (final entry in sizes.entries) {
    final out = _join(resDir, entry.key, 'ic_launcher.png');
    _writePng(out, _resize(base1024, entry.value));
  }
}

void _writeIosAppIcons(String appIconDir, img.Image base1024) {
  final map = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  for (final entry in map.entries) {
    final out = _join(appIconDir, entry.key);
    _writePng(out, _resize(base1024, entry.value));
  }
}

void _writeMacosAppIcons(String appIconDir, img.Image base1024) {
  final map = <String, int>{
    'app_icon_16.png': 16,
    'app_icon_32.png': 32,
    'app_icon_64.png': 64,
    'app_icon_128.png': 128,
    'app_icon_256.png': 256,
    'app_icon_512.png': 512,
    'app_icon_1024.png': 1024,
  };
  for (final entry in map.entries) {
    final out = _join(appIconDir, entry.key);
    _writePng(out, _resize(base1024, entry.value));
  }
}

void _writeWindowsIco(String outPath, img.Image base1024) {
  final sizes = [16, 24, 32, 48, 64, 128, 256];
  final images = sizes.map((s) => _resize(base1024, s)).toList();
  final multi = images.first;
  multi.frames = images;
  final bytes = img.encodeIco(multi, singleFrame: false);
  File(outPath).parent.createSync(recursive: true);
  File(outPath).writeAsBytesSync(bytes);
}

void _writeWebIcons(String webIconsDir, img.Image base1024) {
  Directory(webIconsDir).createSync(recursive: true);
  _writePng(_join(webIconsDir, 'Icon-192.png'), _resize(base1024, 192));
  _writePng(_join(webIconsDir, 'Icon-512.png'), _resize(base1024, 512));

  // Maskable: add padding for safe area.
  final mask192 = _maskable(base1024, 192);
  final mask512 = _maskable(base1024, 512);
  _writePng(_join(webIconsDir, 'Icon-maskable-192.png'), mask192);
  _writePng(_join(webIconsDir, 'Icon-maskable-512.png'), mask512);
}

img.Image _maskable(img.Image base1024, int outSize) {
  final bg = img.Image(width: outSize, height: outSize, numChannels: 4);
  // Solid blue background for maskable icons.
  img.fill(bg, color: img.ColorRgba8(79, 140, 255, 255));
  final inner = _resize(base1024, (outSize * 0.78).round());
  final dx = ((outSize - inner.width) / 2).round();
  final dy = ((outSize - inner.height) / 2).round();
  img.compositeImage(bg, inner, dstX: dx, dstY: dy);
  return bg;
}

String _join(String a, String b, [String? c, String? d, String? e, String? f]) {
  final parts = [a, b, if (c != null) c, if (d != null) d, if (e != null) e, if (f != null) f];
  return parts.join(Platform.pathSeparator);
}
