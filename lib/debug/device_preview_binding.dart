import 'package:flutter/widgets.dart';

/// Stub — không dùng Device Preview (mobile / release).
const bool kUseDevicePreview = false;

void runAppWithPreview(Widget app) => runApp(app);

Locale? devicePreviewLocale(BuildContext context) => null;

Widget devicePreviewBuilder(BuildContext context, Widget child) => child;
