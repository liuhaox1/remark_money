import 'package:flutter/material.dart';

class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final frameStart = DateTime.now();
    final media = MediaQuery.of(context);
    final size = media.size;
    if (size.width <= 520) return child;

    const width = 430.0;
    final height = (size.height * 0.92).clamp(640.0, 900.0);

    final framedChild = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: MediaQuery(
        data: media.copyWith(
          size: Size(width, height),
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
        ),
        child: child,
      ),
    );

    final duration =
        DateTime.now().difference(frameStart).inMilliseconds;
    debugPrint('DeviceFrame build: ${duration}ms');

    return ColoredBox(
      color: const Color(0xFFEDE9E0),
      child: Center(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: framedChild,
        ),
      ),
    );
  }
}
