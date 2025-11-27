import 'package:flutter/material.dart';

import '../constants/bank_brands.dart';

class BrandLogoAvatar extends StatelessWidget {
  const BrandLogoAvatar({
    super.key,
    required this.size,
    this.brandKey,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
  });

  final double size;
  final String? brandKey;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final brand = findBankBrand(brandKey);
    if (brandKey == null || brand == null || brand.key == 'custom') {
      return _buildFallbackAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: brand.color,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      alignment: Alignment.center,
      child: Text(
        brand.shortName,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: iconColor,
      ),
    );
  }
}

