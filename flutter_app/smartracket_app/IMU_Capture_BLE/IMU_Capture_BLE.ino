// Tony 更改自 IMU_Capture_BLE_v9 只加入 LED 燈號顯示 和 setLocalName
// 開機時 LED 燈亮，BLE 連接時，LED 燈滅，以便 Debug
#include <LSM6DS3.h>
#include <Wire.h>
#include <ArduinoBLE.h>

#define DEBUG_PRINT false

// Create a instance of class LSM6DS3
LSM6DS3 myIMU(I2C_MODE, 0x6A); // I2C device address 0x6A

// BLE Service & Characteristic
BLEService imuService("0769bb8e-b496-4fdd-b53b-87462ff423d0"); // 180C
// 自訂 characteristic UUID  // 固定 32 bytes（timestamp + 6 floats + 1 uint32）
BLECharacteristic imuDataChar("8ee82f5b-76c7-4170-8f49-fff786257090", BLERead | BLENotify, 30); // 2A56

bool imuReady = false;
bool calibrationDone = false;
float offsetAX = 0.0f, offsetAY = 0.0f, offsetAZ = 0.0f;
float offsetGX = 0.0f, offsetGY = 0.0f, offsetGZ = 0.0f;

// 電壓快取用的全域變數
unsigned long lastVoltageReadTime = -60000;
int16_t voltageRaw = 0;
bool isHighCurrentCharging = false; // 預設為低電流模式
const int ledPin = LED_BUILTIN;     // Tony: pin to use for the LED

void setup()
{
  // put your setup code here, to run once:
  Serial.begin(115200);
  delay(1000); // 加一點緩衝時間
  // while (!Serial); // Tony: 沒有接電腦就不會有 Seiral = true 的情況

  pinMode(ledPin, OUTPUT);   // Tony: set LED pin to output mode
  digitalWrite(ledPin, LOW); // Tony: turn on the LED to indicate the connection:

  // 開啟電壓偵測通道
  pinMode(P0_14, OUTPUT);
  digitalWrite(P0_14, LOW);

  // 設定 D13 為低電流充電
  pinMode(P0_13, OUTPUT);
  digitalWrite(P0_13, HIGH);

  // 設定 I²C 傳輸頻率為 400kHz
  Wire.begin();
  Wire.setClock(400000); // Fast Mode

  // Call .begin() to configure the IMUs
  if (myIMU.begin() != 0)
  {
    Serial.println("Device error");
  }
  else
  {
    Serial.println("timestamp,aX,aY,aZ,gX,gY,gZ");
  }

  // 初始化 BLE
  if (!BLE.begin())
  {
    Serial.println("BLE init failed");
    while (1)
      ;
  }

  imuService.addCharacteristic(imuDataChar);
  BLE.addService(imuService);
  imuDataChar.setValue((uint8_t *)"", 0); // 設定一個初始空值，避免 notify 錯誤

  BLE.setLocalName("SmartRacket-Tony");
  BLE.setAdvertisedService(imuService);
  BLE.advertise();

  Serial.println("BLE advertising started...");
}

void loop()
{
  checkVoltageAndSleep();

  BLEDevice central = BLE.central();

  if (central && central.connected())
  {

    if (!calibrationDone)
    {
      calibrateIMUOffsets(); // 執行一次就好
      calibrationDone = true;
    }

    Serial.println("Connected to central");

    // 初始化時間記錄
    const unsigned long interval = 20; // 每 20ms 傳一次
    const unsigned long idleTimeout = 60000;
    unsigned long lastSendTime = millis();

    while (central.connected())
    {

      unsigned long now = millis();

      if ((long)(now - lastSendTime) >= 0)
      {

        uint32_t timestamp = millis(); // 加入時間戳  用 millis() 當 timestamp

        float aX = 0, aY = 0, aZ = 0, gX = 0, gY = 0, gZ = 0;
        if (imuReady)
        {
          aX = myIMU.readFloatAccelX() - offsetAX;
          aY = myIMU.readFloatAccelY() - offsetAY;
          aZ = myIMU.readFloatAccelZ() - offsetAZ;
          gX = myIMU.readFloatGyroX() - offsetGX;
          gY = myIMU.readFloatGyroY() - offsetGY;
          gZ = myIMU.readFloatGyroZ() - offsetGZ;
        }
        else
        {
          Serial.println("IMU not ready, skipping data read.");
        }

        // 藍牙傳送資料
        // 打包資料
        uint8_t buffer[30];
        memcpy(buffer, &timestamp, 4);
        memcpy(buffer + 4, &aX, 4);
        memcpy(buffer + 8, &aY, 4);
        memcpy(buffer + 12, &aZ, 4);
        memcpy(buffer + 16, &gX, 4);
        memcpy(buffer + 20, &gY, 4);
        memcpy(buffer + 24, &gZ, 4);
        memcpy(buffer + 28, &voltageRaw, 2);

        // 傳送資料 via BLE notify
        if (central.connected())
        {
          imuDataChar.writeValue(buffer, 30);
        }

        if (DEBUG_PRINT)
        {
          // print the data in CSV format
          Serial.print(timestamp);
          Serial.print(',');
          Serial.print(aX, 8);
          Serial.print(',');
          Serial.print(aY, 8);
          Serial.print(',');
          Serial.print(aZ, 8);
          Serial.print(',');
          Serial.print(gX, 8);
          Serial.print(',');
          Serial.print(gY, 8);
          Serial.print(',');
          Serial.print(gZ, 8);
          Serial.print(',');
          Serial.print(voltageRaw);
          Serial.println();
        }

        // 固定用 += interval，避免節奏往後推延
        lastSendTime += interval;
      }
    }
    Serial.println("Disconnected from central");
    BLE.advertise();
  }
  else
  {
    // 沒有連線 → 省電掛機
    // Serial.println("No central connected. Sleeping...");
    delay(500);
    return;
  }
}

// 電壓偵測及電量過小啟動低耗電
void checkVoltageAndSleep()
{
  unsigned long now = millis();

  if (now - lastVoltageReadTime >= 60000)
  { // 每分鐘檢查一次
    voltageRaw = analogRead(A0);
    lastVoltageReadTime = now;

    float voltage = voltageRaw * (3.3 / 1023.0) * 2.0;

    updateChargingMode(voltage);

    if (voltage < 3.2)
    {
      Serial.println("Voltage too low! Entering sleep mode.");
      // 嘗試通知手機（即使沒連線也無妨）
      if (BLE.connected())
      {

        const char *warning = "LowPowerSleep";
        uint8_t buffer[30] = {0};
        memcpy(buffer, warning, strlen(warning));
        // 改用最後 2 bytes 做為 type code
        uint16_t type = 0xABCD; // or 0x1234
        memcpy(buffer + 28, &type, 2);
        imuDataChar.writeValue(buffer, 30);

        delay(50);
        BLE.disconnect(); // 強制斷線，讓手機收到
        delay(300);
        BLE.advertise();
      }

      // 掛機直到重新連線
      while (!BLE.central().connected())
      {
        delay(1000); // 簡單省電，等手機重新連
      }

      Serial.println("BLE reconnected. Wake up.");
      BLE.advertise();
    }
  }
}

// 高低電流切換
void updateChargingMode(float batteryVoltage)
{
  if (batteryVoltage < 3.7)
  {
    if (!isHighCurrentCharging)
    {
      pinMode(P0_13, OUTPUT);
      digitalWrite(P0_13, LOW); // 切換到高電流充電
      isHighCurrentCharging = true;
      Serial.println("Switched to HIGH current charging.");
    }
  }
  else
  {
    if (isHighCurrentCharging)
    {
      pinMode(P0_13, OUTPUT);
      digitalWrite(P0_13, HIGH); // 切換回低電流充電
      isHighCurrentCharging = false;
      Serial.println("Switched to LOW current charging.");
    }
  }
}

// 自動校正函式
void calibrateIMUOffsets()
{
  {
    checkVoltageAndSleep();

    BLEDevice central = BLE.central();

    if (central)
    {
      Serial.println("Connected to central");
      Serial.println(central.address());

      // turn off the LED to indicate the connection:
      digitalWrite(ledPin, HIGH);

      // 初始化時間記錄
      unsigned long lastSendTime = 0;
      const unsigned long interval = 20; // 每 20ms 傳一次

      while (central.connected())
      {

        unsigned long now = millis();

        // 每 300,000 ms 讀一次電壓
        if (now - lastVoltageReadTime >= 300000)
        { // 5 分鐘 = 300,000 ms
          voltageRaw = analogRead(A0);
          lastVoltageReadTime = now;
        }

        if (now - lastSendTime >= interval)
        {
          lastSendTime = now;

          uint32_t timestamp = millis(); // 加入時間戳  用 millis() 當 timestamp
          float aX = myIMU.readFloatAccelX();
          float aY = myIMU.readFloatAccelY();
          float aZ = myIMU.readFloatAccelZ();
          
          float gX = myIMU.readFloatGyroX();
          float gY = myIMU.readFloatGyroY();
          float gZ = myIMU.readFloatGyroZ();

          // 藍牙傳送資料
          // 打包資料
          uint8_t buffer[30];
          memcpy(buffer, &timestamp, 4);
          memcpy(buffer + 4, &aX, 4);
          memcpy(buffer + 8, &aY, 4);
          memcpy(buffer + 12, &aZ, 4);
          memcpy(buffer + 16, &gX, 4);
          memcpy(buffer + 20, &gY, 4);
          memcpy(buffer + 24, &gZ, 4);
          memcpy(buffer + 28, &voltageRaw, 2);

          // 傳送資料 via BLE notify
          if (BLE.connected())
          {
            imuDataChar.writeValue(buffer, 30);
          }
        }
      }
      // when the central disconnects, turn off the LED:
      digitalWrite(ledPin, HIGH);
      Serial.println("Disconnected from central");
      digitalWrite(ledPin, HIGH); // turn off the LED to indicate the connection:
    }
  }
}