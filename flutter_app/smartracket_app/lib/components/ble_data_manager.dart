import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:intl/intl.dart';
// import 'package:provider/provider.dart'; // 已移除 context 依賴

import 'global_state.dart';

class BleDataManager {
  BleDataManager._internal();
  static final BleDataManager instance = BleDataManager._internal();

  final List<Map<String, dynamic>> structuredData = []; // 已打包但未上傳成功的資料
  final List<VoidCallback> _listeners = [];
  final List<String> logMessages = [];
  List<String> recentRawData = [];
  StreamSubscription<List<int>>? _bleSubscription;
  BluetoothCharacteristic? _characteristic;
  String? connectedDeviceName;
  bool hasConnectedOnce = false;
  bool _uploadEnabled = false;
  double? latestBattery;
  int? batteryPercent;
  bool isDeviceConnected = false;
  bool get uploadEnabled => _uploadEnabled;
  int? oldRawVoltage = 0;
  int _dataIndex = 0; // 全域計數器
  final int _maxDataCount = 1000;
  final Map<String, Map<String, dynamic>> _dataMap = {};
  void Function(Map<String, dynamic>)? onImuDataForPrediction;

  int _dotCounter = 0;
  DateTime _lastDotUpdateTime = DateTime.now().subtract(
    const Duration(seconds: 1),
  );

  final serviceUuid = Guid("0769bb8e-b496-4fdd-b53b-87462ff423d0");
  final characteristicUuid = Guid("8ee82f5b-76c7-4170-8f49-fff786257090");

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final l in _listeners) {
      l();
    }
  }

  void clearCharacteristic() {
    _characteristic = null;
  }

  void setDeviceConnectionStatus(bool connected) {
    isDeviceConnected = connected;
    _notifyListeners();
  }

  void markConnectedOnce() {
    hasConnectedOnce = true;
  }

  Future<void> startListening(BluetoothDevice device) async {
    connectedDeviceName = device.platformName; //儲存 BLE 裝置名稱
    debugPrint('advName": ${device.advName}');

    List<BluetoothService> services = await device.discoverServices();
    var service = services.firstWhere((s) => s.serviceUuid == serviceUuid);
    var characteristic = service.characteristics.firstWhere(
      (c) => c.characteristicUuid == characteristicUuid,
    );

    // 解除之前的 listener（避免重複綁定）
    await characteristic.setNotifyValue(false);
    await characteristic.setNotifyValue(true);

    // ✅ 若已存在監聽，先取消
    if (_bleSubscription != null) {
      await _bleSubscription!.cancel();
      _bleSubscription = null;
    }

    _characteristic = characteristic;
    if (_characteristic != null) {
      _bleSubscription = _characteristic!.onValueReceived.listen(_handleData);
    }
  }

  void setUploadEnabled(bool enabled) {
    _uploadEnabled = enabled;
    _notifyListeners();
  }

  void Function(ImuData)? onImuDataUpdate;

  void _handleData(List<int> value) async {
    if (value.length != 30) return;

    final now = DateTime.now();
    final formattedTime = DateFormat("yyyy/MM/dd HH:mm:ss.SSS").format(now);

    final buffer = ByteData.sublistView(Uint8List.fromList(value));
    final timestamp = buffer.getUint32(0, Endian.little);
    final aX = buffer.getFloat32(4, Endian.little);
    final aY = buffer.getFloat32(8, Endian.little);
    final aZ = buffer.getFloat32(12, Endian.little);

    final gX = buffer.getFloat32(16, Endian.little);
    final gY = buffer.getFloat32(20, Endian.little);
    final gZ = buffer.getFloat32(24, Endian.little);
    final rawVoltage = buffer.getInt16(28, Endian.little); // ✅ 只讀 2 bytes

    ImuData newImuData = ImuData();
    newImuData.timestamp = timestamp;
    newImuData.aX = aX;
    newImuData.aY = aY;
    newImuData.aZ = aZ;

    newImuData.gX = gX;
    newImuData.gY = gY;
    newImuData.gZ = gZ;

    if (onImuDataUpdate != null) {
      onImuDataUpdate!(newImuData);
    }

    final imuData = {
      "timestamp": timestamp,
      "aX": aX,
      "aY": aY,
      "aZ": aZ,
      "gX": gX,
      "gY": gY,
      "gZ": gZ,
    };

    // 🔴 如果有人設定 callback，就呼叫它
    if (onImuDataForPrediction != null) {
      onImuDataForPrediction!(imuData);
    }

    if (_uploadEnabled) {
      final indexStr = "D_${_dataIndex.toString().padLeft(4, '0')}";

      _dataMap[indexStr] = {
        "timestamp": timestamp,
        "time": formattedTime,
        "aX": aX,
        "aY": aY,
        "aZ": aZ,

        "gX": gX,
        "gY": gY,
        "gZ": gZ,
      };

      _dataIndex++;

      // 狀態提示：收集中...
      if (_dataMap.length < _maxDataCount) {
        final now = DateTime.now();
        // ✅ 每 1 秒才更新一次動畫點點
        if (now.difference(_lastDotUpdateTime) >= const Duration(seconds: 1)) {
          _dotCounter = (_dotCounter + 1) % 4; // 0,1,2,3
          final dots = '...' * _dotCounter;
          final message = "📝 資料收集中$dots";
          if (logMessages.isNotEmpty &&
              logMessages.last.startsWith("📝 資料收集中")) {
            logMessages.removeLast();
          }
          logMessages.add(message);
          _notifyListeners();
          _lastDotUpdateTime = now;
        }
      }

      // 到達設定筆數就上傳
      if (_dataIndex >= _maxDataCount) {
        // final docId = "Data_${DateFormat('yyyyMMdd_HHmmssSSS').format(now)}";
        final docId = DateFormat('yyyyMMdd_HHmm_ss_SSS').format(now);
        final docData = {"data": _dataMap};

        FirebaseFirestore.instance
            .collection("Deom") // IMUData
            .doc(docId)
            .set(docData)
            .then((_) {
              final msg = "✅ $docId 上傳成功！";
              debugPrint(msg);
              //清除舊的資料收集中訊息
              logMessages.removeWhere((e) => e.startsWith("📝 資料收集中"));
              //新增成功訊息
              logMessages.add(msg);
              _notifyListeners();
            })
            .catchError((e) {
              final msg = "❌ 上傳失敗: $e";
              debugPrint(msg);
              //清除舊的資料收集中訊息
              logMessages.removeWhere((e) => e.startsWith("📝 資料收集中"));
              //新增失敗訊息
              logMessages.add(msg);
              _notifyListeners();
            });

        // 清空暫存
        _dataMap.clear();
        _dataIndex = 0;
      }
    }

    // 更新電量
    if (oldRawVoltage != rawVoltage) {
      oldRawVoltage = rawVoltage;
      final battery = rawVoltage * (3.3 / 1023.0) * 2.0;
      BleDataManager.instance.updateBattery(battery);
    }
  }

  // 🔋 更新電池電壓（從 handleData 呼叫）
  void updateBattery(double voltage) {
    latestBattery = voltage;
    batteryPercent = _estimateBatteryLevel(voltage);
    _notifyListeners();
  }

  int _estimateBatteryLevel(double voltage) {
    const double maxVoltage = 4.2;
    const double minVoltage = 3.3;
    if (voltage >= maxVoltage) return 100;
    if (voltage <= minVoltage) return 0;
    return ((voltage - minVoltage) / (maxVoltage - minVoltage) * 100).round();
  }
}
