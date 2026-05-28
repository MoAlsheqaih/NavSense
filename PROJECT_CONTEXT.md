# NavSense
This repository will contain our Software Implementation for the Senior Design Project, which is NavSense: An indoor Navigation System with A Haptic Wearable Device.

DO NOT STRICTLY CONSTRAINED YOURSELF TO THE FOLLOWING TEXT, IT IS JUST FOR REFERENCE, YOU CAN CHANGE IT IF YOU HAVE BETTER IDEAS, ALSO IT IS JUST FOR PROVIDING THE SENIOR PROJECT'S CONTEXT

# NavSense: Indoor Navigation & Haptic Wearable System
**System Context & AI Developer Guide**

## 📖 1. Project Overview
**NavSense** is an inclusive, high-precision indoor navigation system designed for both visually impaired individuals and the general public. It solves the "last-mile" navigation problem where outdoor GNSS/GPS fails. 

Instead of relying on audio (which blocks ambient noise) or low-accuracy Wi-Fi trilateration, NavSense uses a **Hybrid UWB-BLE infrastructure** combined with a **spatial haptic wearable wristband** to provide eyes-free, ears-free, centimeter-level guidance.

### Target Audience
* Primary: Visually impaired individuals requiring safe, obstacle-aware navigation.
* Secondary: General public in complex buildings (hospitals, airports, universities).

### Core Objectives & Specifications
* **Localization Accuracy:** < 0.5 meters (critical for doorway/wall distinction).
* **Haptic Latency:** < 200 milliseconds (crucial for real-time turn notifications).
* **Update Rate:** 5 Hz (smooth continuous tracking).
* **Route Calculation Time:** < 3 seconds.
* **Accessibility:** WCAG 2.1 Level AA compliant, fully bilingual (English LTR / Arabic RTL).

---

## 🏗️ 2. System Architecture
The system functions as a closed-loop perception-decision-action cycle consisting of 4 layers:

1. **Infrastructure Layer:** 
   * **UWB Anchors:** Provide precise Time-of-Flight (ToF) ranging.
   * **BLE Beacons:** Provide low-power zone/room detection to save battery.
2. **Wearable Device (Hardware):** An ESP32-based wristband acting as the embedded sensing node. It collects UWB ranging data and IMU headings, then sends them to the mobile app via BLE.
3. **Mobile Application (Software):** The processing brain. Fuses data, calculates position via trilateration, handles UI, and sends discrete vibration commands back to the wristband.
4. **Cloud Backend:** Serverless functions handling pathfinding (TSP or A* search algorithm) - optional, we are thinking whether to include it or not.

---

## 💻 3. Software Stack & Guidelines (Flutter)
The mobile application is built using **Flutter**. 

### Architecture Pattern: MVVM (Model-View-ViewModel)
* **View (UI):** Passive display. Must support bilingual layouts (AR/EN).
* **ViewModel:** Handles presentation logic and state management.
* **Model:** Core business logic (Bluetooth connection state, user location, graph-based map info).
* **Reactive Programming:** UI reacts to continuous sensor data streams automatically.

### ⚠️ AI Coding Constraints (DO NOT VIOLATE):
1. **Decoupling:** Do not mix hardware communication logic (BLE/UWB) directly inside UI Widget files. Always use the ViewModel or dedicated Service classes.
2. **State Management:** Navigation state changes rapidly (5Hz). Do not trigger continuous unnecessary UI rebuilds.
3. **Hardware Latency:** Any code sending Bluetooth commands to the wearable must remain highly optimized to respect the 200ms end-to-end latency constraint.

---

## ⚙️ 4. Hardware & Sensor Data
If modifying hardware communication layers, assume the following packet structure and hardware setup:
* **Microcontroller:** ESP32.
* **UWB Module:** Decawave DW1000 (connected via High-Speed SPI).
* **IMU:** MPU-6050 (connected via I2C).
* **Communication:** Wearable transmits 5 packets per second containing `timestamp`, `anchorcount`, `distances` (UWB), `heading` (IMU), `stepdetected`, and `confidence`.

---

## 📳 5. Haptic Command Dictionary
The mobile app sends navigation instructions to the wearable encoded as specific patterns. When writing navigation logic, trigger these specific states:

| Command | Motor Pattern | Duration | Meaning |
| :--- | :--- | :--- | :--- |
| **FORWARD** | Center pulse | 200 ms | Continue straight |
| **LEFT** | Left motors pulse | 300 ms | Turn left |
| **RIGHT** | Right motors pulse | 300 ms | Turn right |
| **STOP** | Long vibration | 700 ms | Destination reached |
| **ALERT** | Rapid pulses | 500 ms | Off-route warning / Obstacle |
| **PAUSE** | Slow periodic pulse | Continuous | Localization uncertain |

---

## 🤖 6. AI Agent System Prompt
*(If you are an AI assistant reading this file to help the developer, follow these rules):*
* Acknowledge that this is an IoT project. Treat mobile code and hardware connectivity with equal care.
* Do not suggest visual-only UI cues for navigation; the primary feedback mechanism is **Haptic**.
* When writing Flutter code, assume the app is bilingual and always use proper localization practices.
* Maintain the MVVM architecture strictly.