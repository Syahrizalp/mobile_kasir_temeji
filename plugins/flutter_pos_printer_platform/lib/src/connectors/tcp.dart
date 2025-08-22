// plugins/flutter_pos_printer_platform/lib/src/connectors/tcp.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pos_printer_platform/src/models/printer_device.dart';
import 'package:flutter_pos_printer_platform/discovery.dart';
import 'package:flutter_pos_printer_platform/printer.dart';
import 'package:ping_discover_network_forked/ping_discover_network_forked.dart';

class TcpPrinterInput extends BasePrinterInput {
  final String ipAddress;                // IP printer (mis. 192.168.1.123)
  final int port;                        // default 9100 (RAW printing)
  final Duration timeout;                // timeout koneksi
  TcpPrinterInput({
    required this.ipAddress,
    this.port = 9100,
    this.timeout = const Duration(seconds: 5),
  });
}

class TcpPrinterInfo {
  final String address;
  const TcpPrinterInfo({required this.address});
}

class TcpPrinterConnector implements PrinterConnector<TcpPrinterInput> {
  TcpPrinterConnector._();
  static final TcpPrinterConnector _instance = TcpPrinterConnector._();
  static TcpPrinterConnector get instance => _instance;

  Socket? _socket;

  // ---------- Util: ambil IP lokal (IPv4) tanpa network_info_plus ----------
  static Future<String?> _getLocalIPv4() async {
    final ifs = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    // ambil alamat pertama yang bukan loopback & private LAN lebih diutamakan
    for (final ni in ifs) {
      for (final addr in ni.addresses) {
        final ip = addr.address;
        if (!ip.startsWith('127.') && !ip.startsWith('0.')) {
          return ip;
        }
      }
    }
    return null;
  }

  // ---------- Discovery (scan subnet TCP:9100) ----------
  static Future<List<PrinterDiscovered<TcpPrinterInfo>>> discoverPrinters({
    String? ipAddress,        // opsional: kalau null, coba pakai IP lokal perangkat
    int? port,
    Duration? timeOut,
  }) async {
    final List<PrinterDiscovered<TcpPrinterInfo>> result = [];
    final int targetPort = port ?? 9100;

    String? baseIp = ipAddress ?? await _getLocalIPv4();
    if (baseIp == null || !baseIp.contains('.')) return result;

    final String subnet = baseIp.substring(0, baseIp.lastIndexOf('.'));

    final stream = NetworkAnalyzer.discover2(
      subnet,
      targetPort,
      timeout: timeOut ?? const Duration(milliseconds: 4000),
    );

    await for (final addr in stream) {
      if (addr.exists) {
        result.add(
          PrinterDiscovered<TcpPrinterInfo>(
            name: '${addr.ip}:$targetPort',
            detail: TcpPrinterInfo(address: addr.ip),
          ),
        );
      }
    }
    return result;
  }

  /// Versi stream—dipakai kalau library kamu memang expect discovery() berbentuk Stream<PrinterDevice>
  Stream<PrinterDevice> discovery({TcpPrinterInput? model}) async* {
    final int targetPort = model?.port ?? 9100;

    String? baseIp = model?.ipAddress ?? await _getLocalIPv4();
    if (baseIp == null || !baseIp.contains('.')) {
      // tidak bisa menentukan subnet -> tidak ada hasil
      return;
    }

    final String subnet = baseIp.substring(0, baseIp.lastIndexOf('.'));
    final stream = NetworkAnalyzer.discover2(subnet, targetPort);

    await for (final data in stream) {
      if (data.exists) {
        yield PrinterDevice(
          name: '${data.ip}:$targetPort',
          address: data.ip,
        );
      }
    }
  }

  // ---------- Koneksi & Kirim ----------
  @override
  Future<bool> connect(TcpPrinterInput model) async {
    try {
      _socket = await Socket.connect(
        model.ipAddress,
        model.port,
        timeout: model.timeout,
      );
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('TCP connect error: $e');
      _socket = null;
      return false;
    }
  }

  @override
  Future<bool> send(List<int> bytes) async {
    try {
      final s = _socket;
      if (s == null) return false;
      s.add(Uint8List.fromList(bytes));
      await s.flush();
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('TCP send error: $e');
      return false;
    }
  }

  /// [delayMs] opsional: tunggu beberapa ms sebelum benar-benar menutup socket
  @override
  Future<bool> disconnect({int? delayMs}) async {
    try {
      if (delayMs != null) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      await _socket?.flush();
      await _socket?.close();
      _socket = null;
      return true;
    } catch (_) {
      _socket = null;
      return false;
    }
  }
}
