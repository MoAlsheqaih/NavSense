// ============================================================================
// UWB Tag — BLE + 3-Anchor + Antenna Delay Calibration + Haptic Motors
// ============================================================================
// Communication : BLE Nordic UART Service (works on iOS & Android)
// Ranging       : DW1000 UWB — ranges to 3 anchors simultaneously
// Haptic output : 5 vibration motors (F / B / L / R / Centre)
// Sends         : JSON with all anchor ranges at 10 Hz over BLE notify
// Receives      : Single char command (F/B/L/R) over BLE write → haptic
//
// ANTENNA DELAY CALIBRATION:
//   1. Place tag exactly 2.000 m from one anchor
//   2. Read Serial Monitor range output
//   3. Adjust ANTENNA_DELAY until reported range = 2.000 m
//      (increase if reading too high, decrease if too low — steps of 5–10)
//   4. Use the same final value in ALL anchors and this tag file
// ============================================================================

#include <SPI.h>
#include <DW1000Ranging.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "link.h"

// ── UWB SPI & control pins ───────────────────────────────────────────────────
#define SPI_SCK  18
#define SPI_MISO 19
#define SPI_MOSI 23
#define DW_CS     4
#define PIN_RST  27
#define PIN_IRQ  34

// ── Antenna delay calibration ─────────────────────────────────────────────────
// Default: 16384. Tune using the procedure in the header comment above.
// Must match the value set in Anchor1, Anchor2, and Anchor3.
#define ANTENNA_DELAY 16384

// ── Vibration motor pins ─────────────────────────────────────────────────────
const uint8_t PIN_UP     = 32;
const uint8_t PIN_LEFT   = 26;
const uint8_t PIN_CENTER = 14;
const uint8_t PIN_RIGHT  = 25;
const uint8_t PIN_DOWN   = 13;

// ── Haptic timing ────────────────────────────────────────────────────────────
const uint8_t  REPS             = 3;    // Number of repetitions
const uint16_t PULSE_DURATION_MS = 150;  // Duration of each motor pulse
const uint16_t INTER_PULSE_MS   = 100;  // Gap between DOWN→CENTER→TARGET
const uint16_t REP_INTERVAL_MS = 300; // Gap between repetitions

// ── Safety timeout ───────────────────────────────────────────────────────
const unsigned long HAPTIC_SAFETY_TIMEOUT_MS = 5000;  // 5 seconds max

// ── BLE configuration ───────────────────────────────────────────────────────
#define DEVICE_NAME           "UWB-Wearable"
#define NUS_SERVICE_UUID      "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define NUS_CHARACTERISTIC_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"  // app → ESP32
#define NUS_CHARACTERISTIC_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"  // ESP32 → app

// ── BLE state ────────────────────────────────────────────────────────────────
BLEServer         *pServer    = nullptr;
BLECharacteristic *pTxChar    = nullptr;
BLECharacteristic *pRxChar    = nullptr;
bool               bleConnected = false;

// ── UWB state ────────────────────────────────────────────────────────────────
struct MyLink *uwb_data;
long   runtime  = 0;
String all_json = "";

// ═══════════════════════════════════════════════════════════════════════════════
// NON-BLOCKING HAPTIC STATE MACHINE
// ═══════════════════════════════════════════════════════════════════════════════════════

enum HapticState { HAPTIC_IDLE, HAPTIC_PULSE, HAPTIC_GAP };

HapticState hapticState = HAPTIC_IDLE;
uint8_t currentTarget = 0;
uint8_t pulseIndex = 0;    // 0=DOWN, 1=CENTER, 2=TARGET
uint8_t currentRep = 0;   // Current repetition (0-2)
unsigned long stateStartTime = 0;
unsigned long hapticStartTime = 0;

// ═══════════════════════════════════════════════════════════════════════════════
// HAPTIC MOTOR FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════════════

void allOff() {
    analogWrite(PIN_UP,     0);
    analogWrite(PIN_LEFT,   0);
    analogWrite(PIN_CENTER, 0);
    analogWrite(PIN_RIGHT,  0);
    analogWrite(PIN_DOWN,   0);

    digitalWrite(PIN_UP,     LOW);
    digitalWrite(PIN_LEFT,   LOW);
    digitalWrite(PIN_CENTER, LOW);
    digitalWrite(PIN_RIGHT,  LOW);
    digitalWrite(PIN_DOWN,   LOW);
}

uint8_t getTargetPin(char direction) {
    if (direction == 'F' || direction == 'f') return PIN_UP;
    if (direction == 'L' || direction == 'l') return PIN_LEFT;
    if (direction == 'R' || direction == 'r') return PIN_RIGHT;
    if (direction == 'B' || direction == 'b') return PIN_DOWN;
    return PIN_CENTER;
}

uint8_t getIntensityForMotor(uint8_t motor) {
    if (motor == PIN_UP)     return 255;  // Full power - primary forward
    if (motor == PIN_DOWN)   return 180;  // Reduced - anchor point
    if (motor == PIN_LEFT)   return 220;  // Medium-high - left
    if (motor == PIN_RIGHT)  return 220;  // Medium-high - right
    if (motor == PIN_CENTER) return 128;  // Low - confirmation pulse
    return 200;  // Default
}

void advancePulseSequence() {
    pulseIndex++;

    if (pulseIndex > 2) {
        pulseIndex = 0;
        currentRep++;

        if (currentRep >= REPS) {
            hapticState = HAPTIC_IDLE;
            pulseIndex = 0;
            currentRep = 0;
            currentTarget = 0;
            Serial.println("[HAPTIC] Pattern complete");
            return;
        }
    }

    uint8_t motor;
    if (pulseIndex == 0) motor = PIN_DOWN;
    else if (pulseIndex == 1) motor = PIN_CENTER;
    else motor = currentTarget;

    analogWrite(motor, getIntensityForMotor(motor));
    hapticState = HAPTIC_PULSE;
    stateStartTime = millis();
}

void playMove(char direction) {
    if (hapticState != HAPTIC_IDLE) {
        allOff();
    }

    currentTarget = getTargetPin(direction);
    currentRep = 0;
    pulseIndex = 0;

    analogWrite(PIN_DOWN, getIntensityForMotor(PIN_DOWN));
    hapticState = HAPTIC_PULSE;
    stateStartTime = millis();
    hapticStartTime = millis();

    Serial.print("[HAPTIC] Starting: ");
    Serial.println(direction);
}

void updateHaptic() {
    if (hapticState == HAPTIC_IDLE) return;

    unsigned long elapsed = millis() - stateStartTime;

    switch (hapticState) {
        case HAPTIC_PULSE:
            if (elapsed >= PULSE_DURATION_MS) {
                allOff();
                stateStartTime = millis();
                hapticState = HAPTIC_GAP;
            }
            break;

        case HAPTIC_GAP: {
            uint16_t gapTime = (pulseIndex < 2) ? INTER_PULSE_MS : REP_INTERVAL_MS;
            if (elapsed >= gapTime) {
                advancePulseSequence();
            }
            break;
        }

        default:
            break;
    }
}

void checkHapticSafety() {
    if (hapticState != HAPTIC_IDLE && (millis() - hapticStartTime) > HAPTIC_SAFETY_TIMEOUT_MS) {
        allOff();
        hapticState = HAPTIC_IDLE;
        Serial.println("[HAPTIC] Safety timeout triggered");
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// BLE CALLBACKS
// ═══════════════════════════════════════════════════════════════════════════════════════

class ServerCallbacks : public BLEServerCallbacks {
    void onConnect(BLEServer *pServer) override {
        bleConnected = true;
        Serial.println("[BLE] App connected");
    }
    void onDisconnect(BLEServer *pServer) override {
        bleConnected = false;
        Serial.println("[BLE] App disconnected — restarting advertising");
        BLEDevice::startAdvertising();
    }
};

class RxCallbacks : public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) override {
        String val = pCharacteristic->getValue();
        if (val.length() > 0) {
            char cmd = val[0];
            if (cmd >= 'a' && cmd <= 'z') cmd = cmd - 'a' + 'A';
            Serial.print("[BLE] Haptic command: ");
            Serial.println(cmd);
            playMove(cmd);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════════════════
// SETUP
// ═══════════════════════════════════════════════════════════════════════════════

void setup() {
    Serial.begin(115200);

    // ── Motor pins ──
    pinMode(PIN_UP,     OUTPUT);
    pinMode(PIN_LEFT,   OUTPUT);
    pinMode(PIN_CENTER, OUTPUT);
    pinMode(PIN_RIGHT,  OUTPUT);
    pinMode(PIN_DOWN,   OUTPUT);
    allOff();

    // ── BLE ──
    BLEDevice::init(DEVICE_NAME);
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    BLEService *pService = pServer->createService(NUS_SERVICE_UUID);

    pTxChar = pService->createCharacteristic(
        NUS_CHARACTERISTIC_TX,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTxChar->addDescriptor(new BLE2902());

    pRxChar = pService->createCharacteristic(
        NUS_CHARACTERISTIC_RX,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    pRxChar->setCallbacks(new RxCallbacks());

    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(NUS_SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    pAdvertising->setMinPreferred(0x06);
    pAdvertising->setMaxPreferred(0x12);
    BLEDevice::startAdvertising();

    Serial.println("[BLE] Advertising as '" DEVICE_NAME "'");

    delay(500);

    // ── UWB ──
    SPI.begin(SPI_SCK, SPI_MISO, SPI_MOSI);
    DW1000Ranging.initCommunication(PIN_RST, DW_CS, PIN_IRQ);

    DW1000.setAntennaDelay(ANTENNA_DELAY);
    Serial.print("[UWB] Antenna delay: ");
    Serial.println(ANTENNA_DELAY);

    DW1000Ranging.attachNewRange(newRange);
    DW1000Ranging.attachNewDevice(newDevice);
    DW1000Ranging.attachInactiveDevice(inactiveDevice);

    DW1000Ranging.startAsTag("7D:00:22:EA:82:60:3B:9C", DW1000.MODE_LONGDATA_RANGE_LOWPOWER);

    uwb_data = init_link();

    Serial.println("[UWB] Tag ready — ranging with 3 anchors");
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN LOOP
// ═══════════════════════════════════════════════════════════════════════════════

void loop() {
    DW1000Ranging.loop();
    updateHaptic();
    checkHapticSafety();

    if ((millis() - runtime) > 100) {
        if (bleConnected) {
            make_link_json(uwb_data, &all_json);
            send_data(&all_json);
        }
        runtime = millis();
    }
}

// ═══════════════════════════════════════════════════════════════════════════════════════
// UWB CALLBACKS
// ═══════════════════════════════════════════════════════════════════════════════════════

void newRange() {
    Serial.print("from: ");
    Serial.print(DW1000Ranging.getDistantDevice()->getShortAddress(), HEX);
    Serial.print("\t Range: ");
    Serial.print(DW1000Ranging.getDistantDevice()->getRange());
    Serial.print(" m");
    Serial.print("\t RX power: ");
    Serial.print(DW1000Ranging.getDistantDevice()->getRXPower());
    Serial.println(" dBm");

    fresh_link(
        uwb_data,
        DW1000Ranging.getDistantDevice()->getShortAddress(),
        DW1000Ranging.getDistantDevice()->getRange(),
        DW1000Ranging.getDistantDevice()->getRXPower()
    );
}

void newDevice(DW1000Device *device) {
    Serial.print("[UWB] New anchor: ");
    Serial.println(device->getShortAddress(), HEX);
    add_link(uwb_data, device->getShortAddress());
}

void inactiveDevice(DW1000Device *device) {
    Serial.print("[UWB] Lost anchor: ");
    Serial.println(device->getShortAddress(), HEX);
    delete_link(uwb_data, device->getShortAddress());
}

void send_data(String *msg_json) {
    if (!bleConnected) return;
    pTxChar->setValue(*msg_json);
    pTxChar->notify();
    Serial.println("[BLE] UWB data sent");
}