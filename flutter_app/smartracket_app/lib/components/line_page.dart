import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'global_state.dart';
import 'app_colors.dart';

const double scaleA = 2.0; // Accelerometer scale
const double scaleG = 500.0; // Gyroscope scale
const double multiplierAx = 1.2; // 球桿握柄方向的移動量放大倍數(顯示用)

class LinePage extends StatefulWidget {
  const LinePage({super.key});

  final Color axColor = AppColors.contentColorBlue;
  final Color ayColor = AppColors.contentColorYellow;
  final Color azColor = AppColors.contentColorRed;

  final Color gxColor = AppColors.contentColorBlue;
  final Color gyColor = AppColors.contentColorYellow;
  final Color gzColor = AppColors.contentColorRed;

  @override
  State<LinePage> createState() => _LinePageState();
}

class _LinePageState extends State<LinePage> {
  final limitCount = 100;
  final axPoints = <FlSpot>[];
  final ayPoints = <FlSpot>[];
  final azPoints = <FlSpot>[];

  final gxPoints = <FlSpot>[];
  final gyPoints = <FlSpot>[];
  final gzPoints = <FlSpot>[];

  double xValue = 0;
  double step = 0.05;

  late Timer timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(milliseconds: 20), (timer) {
      while (axPoints.length > limitCount) {
        axPoints.removeAt(0);
        ayPoints.removeAt(0);
        azPoints.removeAt(0);

        gxPoints.removeAt(0);
        gyPoints.removeAt(0);
        gzPoints.removeAt(0);
      }

      setState(() {
        final imuData = context.read<ImuDataProvider>().imuData;
        xValue = imuData.timestamp.toDouble();

        axPoints.add(FlSpot(xValue, imuData.aX * multiplierAx));
        ayPoints.add(FlSpot(xValue, imuData.aY));
        azPoints.add(FlSpot(xValue, imuData.aZ));

        gxPoints.add(FlSpot(xValue, imuData.gX));
        gyPoints.add(FlSpot(xValue, imuData.gY));
        gzPoints.add(FlSpot(xValue, imuData.gZ));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return ayPoints.isNotEmpty
        ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 5),
            Text(
              'timestamp: ${xValue.toStringAsFixed(1)}',
              style: const TextStyle(
                color: AppColors.contentColorBlack,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            Row(
              //ax, ay, az
              children: [
                Spacer(),
                Text(
                  'aX: ${axPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.axColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  'aY: ${ayPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.ayColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  'aZ: ${azPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.azColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
              ],
            ),

            AspectRatio(
              // ax, ay, az
              aspectRatio: 1.5,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5.0),
                child: LineChart(
                  LineChartData(
                    minY: -scaleA,
                    maxY: scaleA,
                    minX: axPoints.first.x,
                    maxX: axPoints.last.x,
                    lineTouchData: const LineTouchData(enabled: false),
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      axLine(axPoints),
                      ayLine(ayPoints),
                      azLine(azPoints),
                    ],
                    titlesData: const FlTitlesData(show: false),
                  ),
                ),
              ),
            ),

            Row(
              //gx, gy, gz
              children: [
                Spacer(),
                Text(
                  'gX: ${gxPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.gxColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  'gY: ${gyPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.gyColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Text(
                  'gZ: ${gzPoints.last.y.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: widget.gzColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
              ],
            ),

            AspectRatio(
              //gx, gy, gz
              aspectRatio: 2,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 25.0),
                child: LineChart(
                  LineChartData(
                    minY: -scaleG,
                    maxY: scaleG,
                    minX: gxPoints.first.x,
                    maxX: gxPoints.last.x,
                    lineTouchData: const LineTouchData(enabled: false),
                    clipData: const FlClipData.all(),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      gxLine(gxPoints),
                      gyLine(gyPoints),
                      gzLine(gzPoints),
                    ],
                    titlesData: const FlTitlesData(show: false),
                  ),
                ),
              ),
            ),
          ],
        )
        : Container();
  }

  LineChartBarData axLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.axColor.withValues(alpha: 0), widget.axColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  LineChartBarData ayLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.ayColor.withValues(alpha: 0), widget.ayColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  LineChartBarData azLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.azColor.withValues(alpha: 0), widget.azColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  LineChartBarData gxLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.gxColor.withValues(alpha: 0), widget.gxColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  LineChartBarData gyLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.gyColor.withValues(alpha: 0), widget.gyColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  LineChartBarData gzLine(List<FlSpot> points) {
    return LineChartBarData(
      spots: points,
      dotData: const FlDotData(show: false),
      gradient: LinearGradient(
        colors: [widget.gzColor.withValues(alpha: 0), widget.gzColor],
        stops: const [0.1, 1.0],
      ),
      barWidth: 3,
      isCurved: false,
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }
}
