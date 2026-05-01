# NavSense

**Indoor Navigation System with Haptic Wearable**  
Senior Design Project — Flutter Mobile Application

---

## Overview

NavSense is a cross-platform mobile application that guides users through indoor environments where GPS is unavailable. It fuses **UWB ranging** and **BLE beacon** data to determine position, then delivers **haptic feedback** through a custom wristband so users can navigate eyes-free and ears-free.

The primary target is visually impaired individuals, with a secondary audience of anyone navigating complex buildings such as hospitals, airports, or universities.

---

## Key Features

| Feature | Description |
|---|---|
| **UWB Live Map** | Real-time floor plan with trilaterated position, route overlay, and anchor visualization |
| **Turn-by-turn Navigation** | Dijkstra-based routing with discrete step instructions and BLE beacon ranging |
| **Haptic Guidance** | Direction-encoded vibration patterns sent over BLE to the ESP32 wristband |
| **Simulation Mode** | Full navigation rehearsal on any device — no hardware required |
| **Beacon Scanner** | Live iBeacon RSSI/distance diagnostic tool |
| **Session History** | Timestamped event log (destination set → turns → arrival) exportable as JSON |
| **Bilingual UI** | English (LTR) and Arabic (RTL) with full string coverage across every screen |
| **Accuracy Logger** | CSV export of UWB position fixes for field validation |

---

## Architecture

```
lib/
├── core/               # DI container, routing, theme, constants
├── domain/             # Entities, use cases, repository interfaces
│   ├── entities/       # NavigationSession, RouteStep, SessionEvent, Waypoint
│   ├── repositories/   # Abstract contracts
│   └── usecases/       # ComputeRoute, LogEvent, StartNavigation
├── data/               # Concrete implementations
│   ├── datasources/    # Local session storage, MIP/fallback route sources
│   ├── models/         # JSON-serializable DTOs
│   └── repositories/   # Repository implementations
├── presentation/       # Flutter UI
│   ├── pages/          # Home, Navigation, Simulation, UWB Map, Beacon Scanner,
│   │                     Session History, Settings
│   └── widgets/        # Shared widgets (SessionLogTile, UwbStatusWidget, …)
├── services/           # Hardware & platform abstractions
│   ├── ble/            # BleService (real / mock)
│   ├── uwb/            # UwbService (real / mock / BLE-bridged), trilateration
│   ├── haptic/         # HapticService (wearable BLE / UDP / mock)
│   ├── routing/        # RouteService (Dijkstra / mock)
│   ├── simulation/     # SimulationPositionService
│   └── logging/        # UwbAccuracyLogger (CSV)
└── l10n/               # ARB source files + generated AppLocalizations
```

**Pattern:** Clean Architecture with domain-driven layers. All hardware services are abstract interfaces with real and mock implementations, enabling full testability and simulation without physical devices.

---

## Screens

- **Home** — destination and start-room selection, route computation trigger
- **Navigation** — live BLE beacon ranging, step-by-step instructions, haptic control
- **Simulation** — interactive floor plan, animated route playback, speed/pause controls
- **UWB Live Map** — real-time position dot on floor plan, bearing arrow, route guidance
- **Beacon Scanner** — raw iBeacon data (UUID, RSSI, distance, proximity)
- **Session History** — collapsible session cards with JSON export
- **Settings** — language toggle (EN ↔ AR), app info

---

## Hardware Integration

| Component | Role |
|---|---|
| ESP32 UWB Pro × 3 | Fixed anchors — UWB Time-of-Flight ranging |
| ESP32 UWB Pro × 1 | Mobile tag on the wristband |
| iBeacon × 4 | Room-level BLE zone detection |
| Haptic motor (ERM) | Vibration feedback on the wristband |

The wristband transmits 5 Hz UWB ranging packets to the phone over BLE. The phone computes a trilaterated position, determines the next navigation instruction, and sends a haptic command back to the wristband.

**Haptic Command Dictionary:**

| Command | Pattern | Duration |
|---|---|---|
| Go straight | Centre pulse | 200 ms |
| Turn left | Left pulse | 300 ms |
| Turn right | Right double pulse | 300 ms |
| Arrived | Long vibration | 700 ms |
| Off-route | Rapid pulses | 500 ms |

---

## Performance Targets

| Metric | Target | Status |
|---|---|---|
| Localization accuracy | < 0.5 m | UWB hardware rated 10–30 cm |
| Haptic end-to-end latency | ≤ 200 ms | Measured ≈ 63–89 ms |
| UWB update rate | 5–10 Hz | Implemented |
| Route calculation time | < 3 s | Dijkstra on embedded graph < 100 ms |
| Concurrent users | 200 | Fully client-side — no shared server |

---

## Getting Started

**Prerequisites:** Flutter SDK ≥ 3.0.0, Xcode (iOS), Android Studio or VS Code.

```bash
# Install dependencies
flutter pub get

# Run on connected device or simulator
flutter run

# Run on a specific device
flutter run -d iphone     # iOS Simulator
flutter run -d macos      # macOS desktop
flutter run -d chrome     # Web

# Analyze code
flutter analyze

# Regenerate localization files (after editing .arb files)
flutter gen-l10n
```

---

## Localization

All user-visible strings live in the ARB source files:

- `lib/l10n/app_en.arb` — English (canonical template)
- `lib/l10n/app_ar.arb` — Arabic

After editing an ARB file, run `flutter gen-l10n` to regenerate the Dart files. The language is toggled at runtime from the **Settings** screen; Flutter's `Directionality` widget handles RTL layout automatically.

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_blue_plus` | BLE communication with wearable and beacons |
| `flutter_beacon` | iBeacon scanning and ranging |
| `provider` | State management |
| `get_it` | Dependency injection |
| `shared_preferences` | Session log persistence |
| `path_provider` + `share_plus` | UWB accuracy CSV export |

---

## Project Documentation

| Document | Description |
|---|---|
| `VERIFICATION_TEST_PLAN.md` | Multi-discipline test matrix (EE, CE, IE, SW) |
| `NavSense_Integrated_Specification_Compliance_Report.md` | How the system meets integrated cross-discipline specs |
| `SE_Specifications_Compliance_Report.md` | How the system meets SE-specific constraints |
| `UWB_IPHONE_INTEGRATION.md` | iOS UWB native integration notes |
| `TESTING_WITH_HARDWARE.md` | Hardware bring-up and field test procedures |

---

*NavSense Senior Design Project — Software Engineering Team: Mohammed Al Sheqaih, Nawaf AlHarthi*
