// lib/src/screens/printer_setting_screen.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pos_printer_platform/flutter_pos_printer_platform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

enum PrintMode { bluetooth, network, usb }

class PrinterSettingScreen extends StatefulWidget {
  const PrinterSettingScreen({super.key});
  @override
  State<PrinterSettingScreen> createState() => _PrinterSettingScreenState();
}

class _PrinterSettingScreenState extends State<PrinterSettingScreen> {
  final PrinterManager _pm = PrinterManager.instance;

  bool _printEnabled = false;
  PrintMode _mode = PrintMode.bluetooth;

  // ---------- Bluetooth ----------
  bool _scanBt = false;
  List<PrinterDevice> _btDevices = [];
  PrinterDevice? _selectedBt;
  String? _selectedBtName;
  String? _savedBtAddress;
  String? _savedBtName;
  bool _btConnected = false;
  StreamSubscription<PrinterDevice>? _btScanSub;

  // ---------- Network (Wi-Fi / TCP) ----------
  final _ipCtrl = TextEditingController(text: '192.168.1.100');
  final _portCtrl = TextEditingController(text: '9100');

  // ---------- USB (wired) ----------
  bool _scanUsb = false;
  List<PrinterDevice> _usbDevices = [];
  PrinterDevice? _selectedUsb;
  int? _savedUsbVendorId;
  int? _savedUsbProductId;
  String? _savedUsbName;
  bool _usbConnected = false;
  StreamSubscription<PrinterDevice>? _usbScanSub;

  // ---------- Pref keys ----------
  static const _kEnabled = 'print_enabled';
  static const _kMode = 'print_mode'; // 'bluetooth' | 'network' | 'usb'

  static const _kBtAddress = 'bt_address';
  static const _kBtName = 'bt_name';

  static const _kIp = 'net_ip';
  static const _kPort = 'net_port';

  // gunakan SATU set key USB saja
  static const _kUsbVendorId = 'usb_vendor_id';
  static const _kUsbProductId = 'usb_product_id';
  static const _kUsbName = 'usb_name';

  @override
  void initState() {
    super.initState();
    _restorePrefs();
  }

  @override
  void dispose() {
    _btScanSub?.cancel();
    _usbScanSub?.cancel();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  // ---------- Prefs ----------
  Future<void> _restorePrefs() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _printEnabled = sp.getBool(_kEnabled) ?? false;

      final modeStr = sp.getString(_kMode) ?? 'bluetooth';
      _mode = switch (modeStr) {
        'network' => PrintMode.network,
        'usb' => PrintMode.usb,
        _ => PrintMode.bluetooth,
      };

      // Bluetooth
      _savedBtAddress = sp.getString(_kBtAddress);
      _savedBtName = sp.getString(_kBtName);
      _btConnected = false;

      // Network
      _ipCtrl.text = sp.getString(_kIp) ?? _ipCtrl.text;
      _portCtrl.text = sp.getString(_kPort) ?? _portCtrl.text;

      // USB
      _savedUsbVendorId = sp.getInt(_kUsbVendorId);
      _savedUsbProductId = sp.getInt(_kUsbProductId);
      _savedUsbName = sp.getString(_kUsbName);
      _usbConnected = false;
    });
  }

  Future<void> _savePrefs() async {
    final sp = await SharedPreferences.getInstance();

    // umum
    await sp.setBool(_kEnabled, _printEnabled);
    // simpan semua kemungkinan mode
    final modeStr = switch (_mode) {
      PrintMode.bluetooth => 'bluetooth',
      PrintMode.network => 'network',
      PrintMode.usb => 'usb',
    };
    await sp.setString(_kMode, modeStr);

    // bluetooth (simpan kalau ada yang dipilih)
    if (_selectedBt?.address != null && _selectedBt!.address!.isNotEmpty) {
      await sp.setString(_kBtAddress, _selectedBt!.address!);
      await sp.setString(_kBtName, _selectedBtName ?? (_selectedBt!.name ?? ''));
      _savedBtAddress = _selectedBt!.address!;
      _savedBtName = _selectedBtName ?? _selectedBt!.name;
    }

    // network
    await sp.setString(_kIp, _ipCtrl.text.trim());
    await sp.setString(_kPort, _portCtrl.text.trim());

    // USB (simpan HANYA jika vendorId & productId tidak null)
    // USB (simpan HANYA jika vendorId & productId tidak null)
    final dev = _selectedUsb;

    // Normalisasi vendorId & productId ke int?
    int? toInt(dynamic x) {
      if (x == null) return null;
      if (x is int) return x;
      // kalau String / num / dynamic
      return int.tryParse(x.toString());
    }

    final int? vId = toInt(dev?.vendorId);
    final int? pId = toInt(dev?.productId);

    if (vId != null && pId != null) {
      await sp.setInt(_kUsbVendorId, vId);
      await sp.setInt(_kUsbProductId, pId);
      await sp.setString(_kUsbName, dev?.name ?? 'USB Printer');

      // field di state kita bertipe int? jadi aman
      _savedUsbVendorId = vId;
      _savedUsbProductId = pId;
      _savedUsbName = dev?.name ?? 'USB Printer';
    }

  }

  // ---------- Bluetooth: scan/connect ----------
  Future<void> _startScanBluetooth() async {
    if (_scanBt) return;
    await _btScanSub?.cancel();

    setState(() {
      _scanBt = true;
      _btDevices = [];
      _selectedBt = null;
      _selectedBtName = null;
    });

    _btScanSub = _pm
        .discovery(type: PrinterType.bluetooth, isBle: false)
        .listen((PrinterDevice d) {
      final exists = _btDevices.any((x) => x.address == d.address);
      if (!exists) {
        setState(() => _btDevices = [..._btDevices, d]);

        if (_savedBtAddress != null &&
            _savedBtAddress!.isNotEmpty &&
            _selectedBt == null &&
            d.address == _savedBtAddress) {
          setState(() {
            _selectedBt = d;
            _selectedBtName = d.name;
          });
        }
      }
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal scan BT: $e')),
        );
      }
      _stopScanBluetooth();
    }, onDone: () {
      if (mounted) setState(() => _scanBt = false);
    });
  }

  Future<void> _stopScanBluetooth() async {
    await _btScanSub?.cancel();
    _btScanSub = null;
    if (mounted) setState(() => _scanBt = false);
  }

  Future<void> _connectBluetooth() async {
    if (_selectedBt == null || (_selectedBt!.address ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih printer Bluetooth terlebih dahulu')),
      );
      return;
    }
    try {
      await _pm.connect(
        type: PrinterType.bluetooth,
        model: BluetoothPrinterInput(
          name: _selectedBt!.name,
          address: _selectedBt!.address!,
          isBle: false,
          autoConnect: true,
        ),
      );
      setState(() => _btConnected = true);
      await _savePrefs();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Bluetooth connected')));
      }
    } catch (e) {
      setState(() => _btConnected = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal connect BT: $e')));
      }
    }
  }

  Future<void> _disconnectBluetooth() async {
    try {
      await _pm.disconnect(type: PrinterType.bluetooth);
      if (mounted) setState(() => _btConnected = false);
    } catch (_) {}
  }

  // ---------- USB: scan/connect ----------
  Future<void> _startScanUsb() async {
    if (_scanUsb) return;
    await _usbScanSub?.cancel();

    setState(() {
      _scanUsb = true;
      _usbDevices = [];
      _selectedUsb = null;
    });

    _usbScanSub = _pm
        .discovery(type: PrinterType.usb)
        .listen((PrinterDevice d) {
      final exists = _usbDevices.any(
          (x) => x.vendorId == d.vendorId && x.productId == d.productId);
      if (!exists) {
        setState(() => _usbDevices = [..._usbDevices, d]);

        if (_savedUsbVendorId != null &&
            _savedUsbProductId != null &&
            _selectedUsb == null &&
            d.vendorId == _savedUsbVendorId &&
            d.productId == _savedUsbProductId) {
          setState(() => _selectedUsb = d);
        }
      }
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal scan USB: $e')),
        );
      }
      _stopScanUsb();
    }, onDone: () {
      if (mounted) setState(() => _scanUsb = false);
    });
  }

  Future<void> _stopScanUsb() async {
    await _usbScanSub?.cancel();
    _usbScanSub = null;
    if (mounted) setState(() => _scanUsb = false);
  }

  Future<void> _connectUsb() async {
    final dev = _selectedUsb;
    if (dev == null || dev.vendorId == null || dev.productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih printer USB terlebih dahulu')),
      );
      return;
    }
    try {
      await _pm.connect(
        type: PrinterType.usb,
        model: UsbPrinterInput(
          name: dev.name ?? 'USB Printer',
          productId: dev.productId!,
          vendorId: dev.vendorId!,
        ),
      );
      setState(() => _usbConnected = true);
      await _savePrefs();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('USB connected')));
      }
    } catch (e) {
      setState(() => _usbConnected = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal connect USB: $e')));
      }
    }
  }

  Future<void> _disconnectUsb() async {
    try {
      await _pm.disconnect(type: PrinterType.usb);
      if (mounted) setState(() => _usbConnected = false);
    } catch (_) {}
  }

  // ---------- Network: simpan saja ----------
  Future<void> _saveNetwork() async {
    await _savePrefs();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('IP/Port tersimpan')));
    }
  }

  // ---------- Test print ----------
  Future<void> _testPrint() async {
    if (!_printEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aktifkan cetak struk terlebih dahulu')),
      );
      return;
    }

    try {
      final profile = await CapabilityProfile.load();
      final gen = Generator(PaperSize.mm58, profile);
      final bytes = <int>[];
      bytes.addAll(gen.text(
        'TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          width: PosTextSize.size2,
          height: PosTextSize.size2,
          bold: true,
        ),
      ));
      bytes.addAll(gen.text('Flutter POS Printer', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.text('👍 Connection OK', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.hr());
      bytes.addAll(gen.text('Terima kasih!', styles: const PosStyles(align: PosAlign.center)));
      bytes.addAll(gen.feed(2));
      bytes.addAll(gen.cut());
      final data = Uint8List.fromList(bytes);

      switch (_mode) {
        case PrintMode.bluetooth:
          if (!_btConnected) await _connectBluetooth();
          await _pm.send(type: PrinterType.bluetooth, bytes: data);
          break;

        case PrintMode.network:
          final ip = _ipCtrl.text.trim();
          final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
          if (ip.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Isi IP printer terlebih dahulu')),
            );
            return;
          }
          await _pm.connect(
            type: PrinterType.network,
            model: TcpPrinterInput(ipAddress: ip, port: port),
          );
          await _pm.send(type: PrinterType.network, bytes: data);
          await _pm.disconnect(type: PrinterType.network);
          break;

        case PrintMode.usb:
          if (!_usbConnected) await _connectUsb();
          await _pm.send(type: PrinterType.usb, bytes: data);
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Test print dikirim')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal test print: $e')));
      }
    }
  }

  // ---------- UI helpers ----------
  Widget _statusChip() {
    String label;
    IconData icon;
    Color color;

    switch (_mode) {
      case PrintMode.bluetooth:
        label = _btConnected ? 'BT Connected' : 'BT Disconnected';
        icon = _btConnected ? Icons.check_circle : Icons.cancel;
        color = _btConnected ? Colors.green : Colors.red;
        break;
      case PrintMode.network:
        label = 'Network Mode';
        icon = Icons.wifi;
        color = Colors.blue;
        break;
      case PrintMode.usb:
        label = _usbConnected ? 'USB Connected' : 'USB Disconnected';
        icon = _usbConnected ? Icons.check_circle : Icons.usb;
        color = _usbConnected ? Colors.green : Colors.orange;
        break;
    }

    return Chip(avatar: Icon(icon, color: color, size: 18), label: Text(label));
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer (POS)'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: _statusChip()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Aktifkan cetak struk'),
            value: _printEnabled,
            onChanged: (v) async {
              setState(() => _printEnabled = v);
              await _savePrefs();
            },
          ),
          const SizedBox(height: 8),

          SegmentedButton<PrintMode>(
            segments: const [
              ButtonSegment(value: PrintMode.bluetooth, label: Text('Bluetooth')),
              ButtonSegment(value: PrintMode.network, label: Text('Wi-Fi (TCP)')),
              ButtonSegment(value: PrintMode.usb, label: Text('USB')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) async {
              setState(() => _mode = s.first);
              await _savePrefs();
            },
          ),

          const SizedBox(height: 16),

          // ---------- BLUETOOTH ----------
          if (_mode == PrintMode.bluetooth) ...[
            Row(
              children: [
                const Icon(Icons.bluetooth, size: 20),
                const SizedBox(width: 8),
                const Text('Pilih printer Bluetooth (paired/nearby)'),
                const Spacer(),
                IconButton(
                  tooltip: _scanBt ? 'Scanning...' : 'Scan',
                  onPressed: _scanBt ? null : _startScanBluetooth,
                  icon: _scanBt
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_savedBtAddress != null && (_selectedBt == null))
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Dipilih sebelumnya: ${_savedBtName ?? '-'} (${_savedBtAddress!}). '
                  'Tap Scan untuk memunculkannya.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),

            DropdownButtonFormField<PrinterDevice>(
              value: (_selectedBt != null &&
                      _btDevices.any((d) => d.address == _selectedBt!.address))
                  ? _selectedBt
                  : null,
              hint: const Text('Pilih printer'),
              items: _btDevices
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text('${d.name ?? 'Unknown'} (${d.address ?? '-'})'),
                      ))
                  .toList(),
              onChanged: (d) {
                setState(() {
                  _selectedBt = d;
                  _selectedBtName = d?.name;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _btConnected ? null : _connectBluetooth,
                    icon: const Icon(Icons.link),
                    label: const Text('CONNECT'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _btConnected ? _disconnectBluetooth : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('DISCONNECT'),
                  ),
                ),
              ],
            ),
          ],

          // ---------- NETWORK ----------
          if (_mode == PrintMode.network) ...[
            Row(
              children: const [
                Icon(Icons.wifi, size: 20),
                SizedBox(width: 8),
                Text('Printer Jaringan (IP:Port)'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipCtrl,
                    decoration: const InputDecoration(
                      labelText: 'IP Printer',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: isTablet ? 140 : 110,
                  child: TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saveNetwork,
              child: const Text('SIMPAN'),
            ),
          ],

          // ---------- USB ----------
          if (_mode == PrintMode.usb) ...[
            Row(
              children: [
                const Icon(Icons.usb, size: 20),
                const SizedBox(width: 8),
                const Text('Pilih printer USB'),
                const Spacer(),
                IconButton(
                  tooltip: _scanUsb ? 'Scanning...' : 'Scan',
                  onPressed: _scanUsb ? null : _startScanUsb,
                  icon: _scanUsb
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
            if (_savedUsbVendorId != null && _savedUsbProductId != null && _selectedUsb == null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  'Dipilih sebelumnya: ${_savedUsbName ?? '-'} '
                  '(VID: $_savedUsbVendorId, PID: $_savedUsbProductId). '
                  'Tap Scan untuk memunculkannya.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 8),

            DropdownButtonFormField<PrinterDevice>(
              value: (_selectedUsb != null &&
                      _usbDevices.any((d) =>
                          d.vendorId == _selectedUsb!.vendorId &&
                          d.productId == _selectedUsb!.productId))
                  ? _selectedUsb
                  : null,
              hint: const Text('Pilih printer USB'),
              items: _usbDevices
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          '${d.name ?? 'USB'}  '
                          '(VID:${d.vendorId ?? 0}, PID:${d.productId ?? 0})',
                        ),
                      ))
                  .toList(),
              onChanged: (d) => setState(() => _selectedUsb = d),
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _usbConnected ? null : _connectUsb,
                    icon: const Icon(Icons.link),
                    label: const Text('CONNECT'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _usbConnected ? _disconnectUsb : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('DISCONNECT'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _savePrefs,
              child: const Text('SIMPAN PILIHAN USB'),
            ),
          ],

          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.print),
              onPressed: _testPrint,
              label: const Text('TEST PRINT'),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Catatan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            '• Bluetooth: hidupkan Bluetooth & pair jika perlu. Scan lalu pilih perangkat.\n'
            '• Wi-Fi (TCP): isi IP dan port (umumnya 9100) lalu Simpan. Test Print akan connect–send–disconnect.\n'
            '• USB: colok printer via OTG/USB host. Scan → pilih → Connect. Tambahkan <uses-feature android:name="android.hardware.usb.host" android:required="false" /> di AndroidManifest.\n'
            '• Test Print mengirim struk pendek (esc_pos_utils) untuk uji koneksi.',
          ),
        ],
      ),
    );
  }
}
