import '../../../../bitsdojo_window_platform_interface/lib/bitsdojo_window_platform_interface.dart';
import 'dart:ui';
export './window_interface.dart';

class BitsdojoWindowWindows extends BitsdojoWindowPlatform {
  BitsdojoWindowWindows() {
    assert(false);
  }

  @override
  void doWhenWindowReady(VoidCallback callback) {}

  @override
  DesktopWindow get appWindow {
    return AppWindowNotImplemented();
  }
}
