import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ble_data_manager.dart';
import 'line_page.dart';
import 'global_state.dart';

class BleDataReceiverPage extends StatefulWidget {
  const BleDataReceiverPage({super.key});
  @override
  State<BleDataReceiverPage> createState() => _BleDataReceiverPageState();
}

class _BleDataReceiverPageState extends State<BleDataReceiverPage> {
  final ScrollController _scrollController = ScrollController();
  late bool _uploadEnabled;
  DateTime? _lastUIUpdate;
  int? _previousLogLength;

  @override
  void initState() {
    super.initState();
    if (BleDataManager.instance.hasConnectedOnce &&
        !BleDataManager.instance.uploadEnabled) {
      _uploadEnabled = false;
      BleDataManager.instance.setUploadEnabled(false);
    } else {
      _uploadEnabled = BleDataManager.instance.uploadEnabled;
    }
    BleDataManager.instance.addListener(_refreshUI);
    // 設定 IMU 資料 callback，直接用 context 更新 provider
    BleDataManager.instance.onImuDataUpdate = (imuData) {
      if (mounted) {
        context.read<ImuDataProvider>().update(imuData);
      }
    };
  }

  @override
  void dispose() {
    BleDataManager.instance.onImuDataForPrediction = null;
    BleDataManager.instance.onImuDataUpdate = null;
    BleDataManager.instance.removeListener(_refreshUI);
    super.dispose();
  }

  void _refreshUI() {
    if (!mounted) return;

    final logs = BleDataManager.instance.logMessages;
    final now = DateTime.now();
    if (_lastUIUpdate != null &&
        now.difference(_lastUIUpdate!) < const Duration(milliseconds: 100)) {
      return; // 限制 UI 更新頻率為 100ms 一次
    }

    _lastUIUpdate = now;

    setState(() {});

    final prevLength = _previousLogLength ?? 0;
    _previousLogLength = logs.length;

    if (_uploadEnabled && logs.length > prevLength) {
      _scrollToBottom();
    }

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        setState(() {});
        if (_uploadEnabled) {
          _scrollToBottom();
        }
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _toggleUpload(bool value) {
    setState(() {
      _uploadEnabled = value;
      BleDataManager.instance.setUploadEnabled(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final logs = BleDataManager.instance.logMessages;
    final isConnected = BleDataManager.instance.isDeviceConnected;
    final battery = BleDataManager.instance.latestBattery;
    final batteryPercent = BleDataManager.instance.batteryPercent;

    return Scaffold(
      appBar: AppBar(
        title: const Text("IMU資料接收"),
        actions: [
          Row(
            children: [
              Icon(
                _uploadEnabled ? Icons.cloud_upload : Icons.cloud_off,
                color: _uploadEnabled ? Colors.green : Colors.red,
              ),
              Switch(value: _uploadEnabled, onChanged: _toggleUpload),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (battery != null && batteryPercent != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8),
              child: Text(
                "🔋 $batteryPercent%（${battery.toStringAsFixed(2)}V）",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (!_uploadEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "⚠️ 資料僅接收，未上傳至資料庫",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // ❌ 藍牙斷線提示
          if (!isConnected)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 8),
              child: Text(
                "❌ 裝置已斷線，停止接收資料",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              thickness: 10,
              radius: const Radius.circular(8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isSuccess = log.startsWith("✅");
                  final isError = log.startsWith("❌");

                  return ListTile(
                    title: Text(
                      log,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isSuccess
                                ? Colors.green
                                : isError
                                ? Colors.red
                                : Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          LinePage(),
        ],
      ),
    );
  }
}
