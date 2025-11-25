# Flutter iot_imu_ble

A Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Launcher Icons

https://pub.dev/packages/flutter_launcher_icons

1. dart run flutter_launcher_icons:generate
2. 把 icon 放在 assets/icon/icon.png
3. 編輯 flutter_launcher_icons.yaml 
4. dart run flutter_launcher_icons:main

## Rename App

flutter pub add rename_app
dart run rename_app:main all="My App Name"

## Run 
flutter run -d chrome
flutter run -d M2101K7BNY # Redmi Note 10S
flutter run -d 2407FPN8EG # Xiami 14T Pro

### 小米手機 issue

adb: failed to install app-debug.apk: Failure [INSTALL_FAILED_USER_RESTRICTED: Installcanceled by user]

解決方法：開發人員選項 > 打開「USB 安裝」

當執行 flutter run 時，要手動在 Android 手機上允許安裝應用程式。

## Build
flutter build apk --release --verbose

## Debug

dart devtools

https://docs.flutter.dev/tools/devtools/vscode

https://docs.flutter.dev/testing/code-debugging

# Android Tools

C:\Users\tony\AppData\Local\Android\Sdk\platform-tools

在 Android 手機上看ip:port(每次都不一樣) >　開發人員選項　> 無線偵錯 > IP 位址和通訊埠

adb connect 192.168.1.21:45571

# TensorFlow Lite

## tflite flutter plugin

https://pub.dev/packages/tflite_flutter

https://github.com/tensorflow/flutter-tflite

## Android
在 android/app/build.gradle.kts 加入

dependencies {
    implementation("org.tensorflow:tensorflow-lite:2.10.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.10.0")
    implementation("org.tensorflow:tensorflow-lite-gpu-api:2.10.0")
}
