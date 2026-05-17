import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// Renders the Hunger Cafe logo.
///
/// Prefers `assets/logo.png` if the user dropped one in; falls back to the
/// bundled `assets/logo.svg`.
class BrandLogo extends StatefulWidget {
  final double size;
  const BrandLogo({super.key, this.size = 96});

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  late Future<bool> _hasPng;

  @override
  void initState() {
    super.initState();
    _hasPng = rootBundle
        .load('assets/logo.png')
        .then((_) => true)
        .catchError((_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasPng,
      builder: (context, snap) {
        if (snap.data == true) {
          return Image.asset(
            'assets/logo.png',
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
          );
        }
        return SvgPicture.asset(
          'assets/logo.svg',
          width: widget.size,
          height: widget.size,
        );
      },
    );
  }
}
