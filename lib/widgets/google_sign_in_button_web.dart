import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

/// Chiều cao native của GIS `GSIButtonSize.large` (~40px).
const double _gsiNativeHeight = 40.0;

/// Nút Google Identity Services (GIS) trên web — scale để khớp nút Chơi ngay.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.width = double.infinity,
    this.height = 54,
  });

  final Future<void> Function() onPressed;
  final bool busy;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = width == double.infinity
            ? constraints.maxWidth
            : width;
        final scale = height / _gsiNativeHeight;
        // GIS giới hạn 400px; chia scale để sau phóng to = đúng maxWidth.
        final innerWidth = (maxWidth / scale).clamp(120.0, 400.0);

        return SizedBox(
          width: maxWidth,
          height: height,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: SizedBox(
              width: innerWidth,
              height: _gsiNativeHeight,
              child: gsi_web.renderButton(
                configuration: gsi_web.GSIButtonConfiguration(
                  type: gsi_web.GSIButtonType.standard,
                  theme: gsi_web.GSIButtonTheme.outline,
                  size: gsi_web.GSIButtonSize.large,
                  text: gsi_web.GSIButtonText.continueWith,
                  shape: gsi_web.GSIButtonShape.pill,
                  minimumWidth: innerWidth,
                  locale: 'vi',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
