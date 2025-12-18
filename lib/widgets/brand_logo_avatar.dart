import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  static const Map<String, ({String asset, Color color})> _specialBrands = {
    'alipay': (asset: 'assets/brands/alipay.svg', color: Color(0xFF0AA1E4)),
    'wechat': (asset: 'assets/brands/wechat.svg', color: Color(0xFF22B573)),
  };

  @override
  Widget build(BuildContext context) {
    final special = brandKey != null ? _specialBrands[brandKey] : null;
    if (special != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: special.color,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        padding: EdgeInsets.all(size * 0.22),
        child: SvgPicture.asset(
          special.asset,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      );
    }

    final brand = findBankBrand(brandKey);
    if (brandKey == null || brand == null || brand.key == 'custom') {
      return _buildFallbackAvatar();
    }
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
        style: tt.labelLarge!.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onPrimary,
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
