import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../components/ble_data_receiver_page.dart';
import '../components/ble_data_manager.dart';
import '../components/ble_data_posture.dart';

class BleScanPage extends StatefulWidget {
  const BleScanPage({super.key});
  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  BluetoothDevice? connectedDevice;
  static BluetoothDevice? _persistedDevice;

  @override
  void initState() {
    super.initState();
    connectedDevice = _persistedDevice;
    _startScan();
  }

  void _startScan() async {
    if (isScanning) return;

    setState(() {
      scanResults.clear();
      isScanning = true;
    });

    FlutterBluePlus.setLogLevel(LogLevel.warning);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    await FlutterBluePlus.stopScan();

    if (scanResults.isNotEmpty) {
      debugPrint("🔍 掃描到 ${scanResults.length} 個裝置");
    }

    setState(() {
      isScanning = false;
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      debugPrint("🔌 嘗試連線到 ${device.platformName} (${device.remoteId})");
      await device.connect();
      await BleDataManager.instance.startListening(device);

      BleDataManager.instance.markConnectedOnce();

      // 監聽斷線事件
      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint("🔌 裝置已斷線");

          // 通知 BleDataManager
          BleDataManager.instance.setDeviceConnectionStatus(false);

          setState(() {
            connectedDevice = null;
            _persistedDevice = null;
          });
        } else if (state == BluetoothConnectionState.connected) {
          BleDataManager.instance.setDeviceConnectionStatus(true);
        }
      });

      setState(() {
        connectedDevice = device;
        _persistedDevice = device;
        scanResults = List.from(scanResults);
      });

      // 連線後自動切換
      // if (!mounted) return;
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => const BleDataPosturePage()),
      // );
    } catch (e) {
      debugPrint("❌ 連線失敗: $e");
    }
  }

  void _disconnectDevice() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();

      // 清掉 BLE listener 狀態
      BleDataManager.instance.clearCharacteristic();

      setState(() {
        connectedDevice = null;
        _persistedDevice = null;
      });
    }
  }

  void _navigateToReceiverPage() {
    if (connectedDevice != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BleDataReceiverPage()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("尚未連接裝置")));
    }
  }

  void _navigateToPosturePage() {
    if (connectedDevice != null) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const BleDataPosturePage()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("尚未連接裝置")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE 掃描"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _startScan),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: _navigateToReceiverPage,
            color: connectedDevice == null ? Colors.grey : null,
          ),
          IconButton(
            icon: const Icon(Icons.accessibility),
            onPressed: _navigateToPosturePage,
            color: connectedDevice == null ? Colors.grey : null,
          ),
        ],
      ),
      body:
          isScanning
              ? const Center(child: CircularProgressIndicator())
              : scanResults.isEmpty
              ? const Center(child: Text("沒有找到任何裝置"))
              : ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  // 先將 scanResults 依 SmartRacket 名稱排序
                  final sortedResults = List<ScanResult>.from(scanResults)
                    ..sort((a, b) {
                      final aIsSmartRacket =
                          a.device.platformName.contains("SmartRacket") ? 0 : 1;
                      final bIsSmartRacket =
                          b.device.platformName.contains("SmartRacket") ? 0 : 1;
                      return aIsSmartRacket.compareTo(bIsSmartRacket);
                    });
                  final result = sortedResults[index];
                  final name =
                      result.device.platformName.isNotEmpty
                          ? result.device.platformName
                          : "（無名稱）";
                  final isConnected =
                      connectedDevice?.remoteId == result.device.remoteId;

                  return ListTile(
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isConnected ? FontWeight.bold : null,
                      ),
                    ),
                    subtitle: Text(result.device.remoteId.toString()),
                    trailing:
                        isConnected
                            ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "✅ 已連線",
                                  style: TextStyle(color: Colors.green),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _disconnectDevice,
                                  child: const Text("中斷連線"),
                                ),
                              ],
                            )
                            : ElevatedButton(
                              onPressed: () => _connectToDevice(result.device),
                              child: const Text("連線"),
                            ),
                  );
                },
              ),
    );
  }
}
