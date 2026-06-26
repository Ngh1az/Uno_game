import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Chỉ preview khi dev trên trình duyệt (flutter run -d chrome).
const bool kUseDevicePreview = !kReleaseMode;

void runAppWithPreview(Widget app) {
  if (kUseDevicePreview) {
    runApp(DevicePreview(enabled: true, builder: (context) => app));
  } else {
    runApp(app);
  }
}

Locale? devicePreviewLocale(BuildContext context) =>
    kUseDevicePreview ? DevicePreview.locale(context) : null;

Widget devicePreviewBuilder(BuildContext context, Widget child) =>
    kUseDevicePreview ? DevicePreview.appBuilder(context, child) : child;
