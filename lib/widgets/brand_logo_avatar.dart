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

  static const Map<String, String> _bankLogoAssets = {
    'icbc': 'assets/brands/banks_icon_trim/icbc.png',
    'abc': 'assets/brands/banks_icon_trim/abc.png',
    'boc': 'assets/brands/banks_icon_trim/boc.png',
    'ccb': 'assets/brands/banks_icon_trim/ccb.png',
    'bocom': 'assets/brands/banks_icon_trim/bocom.png',
    'spdb': 'assets/brands/banks_icon_trim/spdb.png',
    'cib': 'assets/brands/banks_icon_trim/cib.png',
    'gdb': 'assets/brands/banks_icon_trim/gdb.png',
    'cmbc': 'assets/brands/banks_icon_trim/cmbc.png',
    'citic': 'assets/brands/banks_icon_trim/citic.png',
  };

  static const Map<String, double> _bankLogoScales = {
    // Some icon sources have very different internal whitespace.
    // Scale them a bit so the visual weight is consistent in the list.
    'gdb': 0.90,
    'boc': 0.92,
    'citic': 0.95,
    // These two icons were tightly cropped in the source; keep scale at 1.0 after re-padding the PNGs.
    'spdb': 1.00,
    'abc': 1.00,
    'cib': 1.00,
    'bocom': 0.96,
    'ccb': 0.95,
    'icbc': 1.16,
    'cmbc': 1.22,
  };

  @override
  Widget build(BuildContext context) {
    final brand = findBankBrand(brandKey);
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

    final bankAsset = brandKey != null ? _bankLogoAssets[brandKey] : null;
    if (bankAsset != null) {
      final cs = Theme.of(context).colorScheme;
      final scale = brandKey != null ? (_bankLogoScales[brandKey] ?? 1.0) : 1.0;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(size / 3),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        // Give more horizontal breathing room so the logo doesn't feel "cropped".
        // Less padding -> logo looks larger (avoid ClipRect; scaling should not crop).
        padding: EdgeInsets.fromLTRB(
          size * 0.16,
          size * 0.16,
          size * 0.16,
          size * 0.16,
        ),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Image.asset(
            bankAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return _buildIconOnlyFallback(context, brand);
            },
          ),
        ),
      );
    }

    return _buildIconOnlyFallback(context, brand);
  }

  Widget _buildIconOnlyFallback(BuildContext context, BankBrand? brand) {
    final cs = Theme.of(context).colorScheme;
    final tint = brand?.color ?? iconColor;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: tint),
    );
  }

  Widget _buildShortNameAvatar(BuildContext context, BankBrand brand) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(size / 3),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      alignment: Alignment.center,
      child: Text(
        brand.shortName,
        style: tt.labelLarge!.copyWith(
          fontWeight: FontWeight.w700,
          color: brand.color,
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
