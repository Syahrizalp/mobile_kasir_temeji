import 'dart:io';
// import 'package:flutter_star_prnt/flutter_star_prnt.dart';

import 'flutter_pos_printer_platform.dart';

class PrinterDiscovered<T> {
  String name;
  T detail;
  PrinterDiscovered({
    required this.name,
    required this.detail,
  });
}

typedef DiscoverResult<T> = Future<List<PrinterDiscovered<T>>>;
// typedef StarPrinterInfo = PortInfo;   // hapus kalau PortInfo juga dari flutter_star_prnt

// ---- versi kosong (karena kita tidak pakai StarPrinter lagi) ----
DiscoverResult<dynamic> discoverStarPrinter() async {
  return [];
}

Future<List<PrinterDiscovered>> discoverPrinters({
  List<DiscoverResult Function()> modes = const [
    // kalau sudah tidak pakai Star, jangan panggil discoverStarPrinter
    // discoverStarPrinter,
    UsbPrinterConnector.discoverPrinters,
    BluetoothPrinterConnector.discoverPrinters,
    TcpPrinterConnector.discoverPrinters
  ],
}) async {
  List<PrinterDiscovered> result = [];
  await Future.wait(modes.map((m) async {
    result.addAll(await m());
  }));
  return result;
}
