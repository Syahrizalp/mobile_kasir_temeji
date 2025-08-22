// plugins/flutter_pos_printer_platform/lib/src/printers/star.dart
import 'dart:typed_data';
import 'package:flutter_pos_printer_platform/printer.dart';

/// Dummy enum agar kompatibel dengan kode yang sudah terlanjur memakai StarEmulation.
enum StarEmulation { starPRNT, starLine, starGraphic }

/// Shim: menonaktifkan dukungan Star tanpa dependensi flutter_star_prnt.
/// Jika nanti kamu butuh Star lagi, tinggal ganti implementasi ini
/// dan tambahkan kembali paket flutter_star_prnt.
class StarPrinter extends Printer {
  StarPrinter({
    StarEmulation emulation = StarEmulation.starGraphic,
    int width = 580,
  });

  UnsupportedError get _err => UnsupportedError(
      'Star printer support is disabled. Remove usages of StarPrinter or add the flutter_star_prnt package.');

  @override
  Future<bool> beep() async => Future.error(_err);

  @override
  Future<bool> image(Uint8List bytes, {int threshold = 150}) async =>
      Future.error(_err);

  @override
  Future<bool> pulseDrawer() async => Future.error(_err);

  @override
  Future<bool> selfTest() async => Future.error(_err);

  @override
  Future<bool> setIp(String ipAddress) async => Future.error(_err);
}
