import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer' as developer;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'line_page.dart';
import 'ble_data_manager.dart';
import 'global_state.dart';

class BleDataPosturePage extends StatefulWidget {
  const BleDataPosturePage({super.key});
  @override
  State<BleDataPosturePage> createState() => _BleDataPosturePageState();
}

class _BleDataPosturePageState extends State<BleDataPosturePage> {
  DateTime? _lastUIUpdate;
  final List<List<double>> _imuBuffer = []; // ✅ BLE 資料累積用
  String _predictedPosture = "other"; // ✅ 推理結果
  bool _isLockPosture = true; // ✅ 是否鎖定姿勢推理

  late Interpreter interpreter;
  Future<void> loadModel() async {
    interpreter = await Interpreter.fromAsset('assets/badminton_model.tflite');
  }

  @override
  void initState() {
    super.initState();

    if (BleDataManager.instance.hasConnectedOnce &&
        !BleDataManager.instance.uploadEnabled) {
      BleDataManager.instance.setUploadEnabled(false);
    }

    BleDataManager.instance.addListener(_refreshUI);
    // 設定 IMU 資料 callback，直接用 context 更新 provider
    BleDataManager.instance.onImuDataUpdate = (imuData) {
      if (mounted) {
        context.read<ImuDataProvider>().update(imuData);
      }
    };
    loadModel();

    // ✅ 監聽 BLE 每筆 IMU 資料（直接把資料送進 buffer）
    BleDataManager.instance.onImuDataForPrediction = (data) {
      final imuRow = [
        data["aX"] ?? 0.0,
        data["aY"] ?? 0.0,
        data["aZ"] ?? 0.0,
        data["gX"] ?? 0.0,
        data["gY"] ?? 0.0,
        data["gZ"] ?? 0.0,
      ];

      final List<double> imuRowDouble =
          imuRow.map((e) => (e as num).toDouble()).toList();
      _imuBuffer.add(imuRowDouble);

      if (_imuBuffer.length > 40) {
        _imuBuffer.removeAt(0);
      }

      if (_imuBuffer.length == 40) {
        classifyPosture();
      }
    };
  }

  Future<void> classifyPosture() async {
    // 🔴 如果 buffer 不滿 40 筆就不推理
    if (_imuBuffer.length < 40) {
      developer.log("❌ 不足 40 筆，無法推理");
      return;
    }

    try {
      // ✅ 組成 TFLite 需要的輸入格式: [1, 40, 6, 1]
      final input = [
        _imuBuffer.map((row) => row.map((v) => [v]).toList()).toList(),
      ];

      // ✅ 準備輸出空間: [1, 3]
      final output = List.generate(1, (_) => List.filled(3, 0.0));

      // ✅ 呼叫本地模型推理
      interpreter.run(input, output);

      final result = output[0]; // [0.1, 0.8, 0.1] 這樣
      // debugPrint("🎯 本地模型輸出: $result");

      // 🔍 找最大值 index
      final maxIndex = result.indexWhere(
        (e) => e == result.reduce((a, b) => a > b ? a : b),
      );

      String posture;
      switch (maxIndex) {
        case 0:
          posture = "drive";
          break;
        case 1:
          posture = "other";
          break;
        case 2:
          posture = "smash";
          break;
        default:
          posture = "other";
      }

      if (posture != "other") {
        debugPrint("posture: $posture");
      }

      // ✅ 如果是 drive 或 smash，3 秒後還原顯示為 "other"
      if (_isLockPosture) {
        if (posture == "drive" || posture == "smash") {
          if (_predictedPosture != "other") {
            // 避免 other => drive / smash => smash / drive 的情況
            return;
          }

          setState(() {
            _predictedPosture = posture;
          });

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _predictedPosture = "other"; // reset posture
              });
            }
          });
        }

        if (_predictedPosture == "other") {
          setState(() {
            _predictedPosture = posture;
          });
        }
      } else {
        setState(() {
          _predictedPosture = posture;
        });
      }
    } catch (e) {
      developer.log("❌ 推理錯誤: $e");
    }
  }

  @override
  void dispose() {
    BleDataManager.instance.onImuDataForPrediction = null;
    BleDataManager.instance.onImuDataUpdate = null;
    BleDataManager.instance.removeListener(_refreshUI);
    interpreter.close();
    super.dispose();
  }

  void _refreshUI() {
    if (!mounted) return;

    final now = DateTime.now();
    if (_lastUIUpdate != null &&
        now.difference(_lastUIUpdate!) < const Duration(milliseconds: 100)) {
      return; // 限制 UI 更新頻率為 100ms 一次
    }

    _lastUIUpdate = now;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = BleDataManager.instance.isDeviceConnected;
    final battery = BleDataManager.instance.latestBattery;
    final batteryPercent = BleDataManager.instance.batteryPercent;

    return Scaffold(
      appBar: AppBar(
        title: const Text("姿勢判斷"),
        actions: [
          const Text("凍結3秒", style: TextStyle(fontSize: 16)),
          Switch(
            value: _isLockPosture,
            onChanged: (value) {
              setState(() {
                _isLockPosture = value;
              });
            },
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

          // ❌ 藍牙斷線提示
          if (!isConnected)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, bottom: 8),
              child: Text(
                "❌ 裝置已斷線，請重新連線",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          Center(
            child: Text(
              _predictedPosture,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
                fontSize: 50,
              ),
            ),
          ),

          LinePage(),
        ],
      ),
    );
  }
}
