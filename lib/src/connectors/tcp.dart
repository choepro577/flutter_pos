import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pos_printer/src/connectors/result.dart';
import 'package:network_info_plus/network_info_plus.dart';

import 'package:flutter_pos_printer/discovery.dart';
import 'package:flutter_pos_printer/printer.dart';

class TcpPrinterInfo {
  InternetAddress address;
  TcpPrinterInfo({
    required this.address,
  });
}

class TcpPrinterConnector implements PrinterConnector {
  TcpPrinterConnector(this._host,
      {Duration timeout = const Duration(seconds: 5), port = 9100})
      : _port = port,
        _timeout = timeout;

  String _host;
  int _port;
  late final Duration _timeout;

  late Socket _socket;

  int? get port => _port;
  String? get host => _host;

  static DiscoverResult<TcpPrinterInfo> discoverPrinters() async {
    final List<PrinterDiscovered<TcpPrinterInfo>> result = [];
    final defaultPort = 9100;

    String? deviceIp;
    if (!Platform.isWindows) {
      deviceIp = await NetworkInfo().getWifiIP();
    }
    if (deviceIp == null) return result;

    final String subnet = deviceIp.substring(0, deviceIp.lastIndexOf('.'));
    final List<String> ips = List.generate(255, (index) => '$subnet.$index');

    await Future.wait(ips.map((ip) async {
      try {
        final _socket = await Socket.connect(ip, defaultPort,
            timeout: Duration(milliseconds: 50));
        _socket.destroy();
        result.add(PrinterDiscovered<TcpPrinterInfo>(
            name: ip, detail: TcpPrinterInfo(address: _socket.address)));
      } catch (e) {}
    }));
    return result;
  }

  @override
  Future<PosPrintResult> connect(String host, {int port = 91000, Duration timeout = const Duration(seconds: 5)}) async {
    _host = host;
    _port = port;
    try {
      _socket = await Socket.connect(host, port, timeout: timeout);
      return Future<PosPrintResult>.value(PosPrintResult.success);
    } catch (e) {
      return Future<PosPrintResult>.value(PosPrintResult.timeout);
    }
  }

  @override
  Future<bool> send(List<int> bytes) async {
    try {
      _socket.add(Uint8List.fromList(bytes));
      return true;
    } catch (e) {
      return false;
    }
  }
}
