import 'package:flutter/foundation.dart';

class ImuData {
  int timestamp = 0;
  double aX = 0.0;
  double aY = 0.0;
  double aZ = 0.0;
  double gX = 0.0;
  double gY = 0.0;
  double gZ = 0.0;
}

class ImuDataProvider with ChangeNotifier, DiagnosticableTreeMixin {
  final ImuData _imuData = ImuData();

  ImuData get imuData => _imuData;

  void update(ImuData newImuData) {
    _imuData.timestamp = newImuData.timestamp;
    _imuData.aX = newImuData.aX;
    _imuData.aY = newImuData.aY;
    _imuData.aZ = newImuData.aZ;
    _imuData.gX = newImuData.gX;
    _imuData.gY = newImuData.gY;
    _imuData.gZ = newImuData.gZ;

    notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('timestamp', _imuData.timestamp));
    properties.add(DoubleProperty('aX', _imuData.aX));
  }
}
