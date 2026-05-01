# NavSense — Software Engineering Specifications Compliance Report

**Project:** NavSense Indoor Navigation System  
**Discipline:** Software Engineering  
**Date:** April 2026

---

## 1. Support Up to 200 Concurrent Users

**Specification:** The system shall support up to 200 simultaneous active users.

**How it is met:**

NavSense is a fully **client-side Flutter application**. All computationally intensive logic — route calculation (Dijkstra), UWB trilateration, BLE ranging, haptic scheduling — executes entirely on the user's device. There is no shared application server that becomes a bottleneck. Each installed instance is independent; 200 users running the app simultaneously means 200 independent processes, none of which share state with each other.

The only shared infrastructure is the physical UWB anchor/BLE beacon hardware deployed in the venue, which is a hardware concern shared across disciplines. From the software perspective, concurrency is bounded only by device resources, not by any server-side limit introduced by this codebase.

> **Evidence:** No server-side session management, no shared in-memory state, no database connection pool. The routing engine (`lib/services/routing/route_service.dart`) and positioning engine (`lib/services/positioning_service.dart`) are instantiated per-app-session on the device.

---

## 2. Modular and Open Architecture

**Specification:** The software architecture shall be modular and open to enable future expandability and integration of new features.

**How it is met:**

The project follows **Clean Architecture** with strict layer separation:

| Layer | Directory | Responsibility |
|-------|-----------|----------------|
| Domain | `lib/domain/` | Entities, use cases, repository contracts |
| Data | `lib/data/` | Repository implementations, data sources, models |
| Presentation | `lib/presentation/` | Pages, widgets, view models |
| Services | `lib/services/` | Hardware abstractions (UWB, BLE, haptics) |

Each hardware service is defined as an **abstract interface** with interchangeable implementations:

- `UwbService` → `RealUwbService` / `MockUwbService` / `BleUwbService`
- `BleService` → `RealBleService` / `MockBleService`
- `RouteService` → `RouteService` (Dijkstra) / `MockRouteService` / `FallbackRouteDatasource` / `MipRouteDatasource`

New positioning technologies, routing algorithms, or data sources can be added by implementing the relevant interface and registering it in the DI container (`lib/core/di/`) without modifying existing code — adhering to the **Open/Closed Principle**.

Use cases (`ComputeRouteUsecase`, `LogEventUsecase`, `StartNavigationUsecase`) encapsulate business logic independently of both UI and data sources, making them reusable and independently testable.

---

## 3. Cross-Platform Deployment

**Specification:** The system shall support cross-platform deployment, ensuring it can operate consistently across multiple operating systems and environments without requiring platform-specific modifications.

**How it is met:**

NavSense is built with **Flutter (SDK ≥ 3.0.0)**, a single-codebase framework that compiles to native code for six platforms from one Dart codebase. The project contains generated platform stubs for all targets:

| Platform | Directory | Status |
|----------|-----------|--------|
| Android | `android/` | ✅ |
| iOS | `ios/` | ✅ |
| macOS | `macos/` | ✅ |
| Linux | `linux/` | ✅ |
| Windows | `windows/` | ✅ |
| Web | `web/` | ✅ |

Hardware-dependent features (UWB, BLE) are abstracted behind service interfaces. On platforms where hardware is unavailable, the `MockUwbService` and `MockBleService` implementations are substituted, allowing the application — including the simulation and route planning screens — to run identically on any platform without modifying shared business logic.

No platform-specific UI code exists in the shared `lib/` tree.

---

## 4. Multilingual UI — English (LTR) and Arabic (RTL)

**Specification:** All UI screens shall support Multilingual UI, English (LTR) and Arabic (RTL), with correct layout direction and text rendering, verified by a manual checklist.

**How it is met:**

The app uses Flutter's **`AppLocalizations`** delegate pattern with a hand-maintained abstract base class and two concrete subclasses:

- `AppLocalizationsEn` — English strings, LTR
- `AppLocalizationsAr` — Arabic strings, RTL

The locale is stored in shared preferences and toggled at runtime from the Settings screen. Flutter's `Directionality` widget, driven by the active locale, automatically mirrors all layouts (padding, icon placement, list order, text alignment) for RTL without per-widget overrides.

**Coverage verified across all screens:**

| Screen | Localized |
|--------|-----------|
| Home | ✅ |
| Navigation | ✅ |
| Simulation | ✅ |
| UWB Live Map | ✅ |
| Beacon Scanner | ✅ |
| Session History | ✅ |
| Settings | ✅ |

All user-visible strings — including parametrized ones (e.g., beacon count, ETA, route step count) — are routed through localization methods. No hardcoded English strings remain in any UI file. Internal state values (e.g., `_ScanStateType` enum, strength keys) are kept language-neutral in logic and resolved to localized text only inside `build()`.

> **~74 localization keys** covering every screen, dialog, button, status label, and error message in both languages.

---

## 5. Users Learn ≥ 80% of Key Functions Within ≤ 2 Hours

**Specification:** Users shall be able to learn and operate at least 80% of key functions within 2 hours of first use.

**How it is met:**

The app's UX is designed around **progressive disclosure** — users encounter complexity only when they seek it:

1. **Single entry point:** The Home screen presents one primary action (select destination → start navigation) with no mode switching required.
2. **Visual affordances:** All interactive elements use standard Material Design icons (radar, stop, play, reset) with tooltips in the active language. No domain-specific jargon appears in primary flows.
3. **Haptic guidance:** Turn-by-turn haptic patterns (short pulse = minor turn, long pulse = major turn, double pulse = arrived) reduce the need to read the screen during navigation, minimizing the cognitive load of learning the interface.
4. **Simulation mode:** Users can rehearse a full navigation session on any device without hardware, allowing safe exploration before real use. This significantly reduces time-to-competency.
5. **Consistent navigation structure:** A bottom shell navigation bar (`ShellPage`) gives persistent, labeled access to all five top-level screens, so discoverability requires no instruction.

The five key functions (destination selection, route start, turn-by-turn following, off-route recovery, session review) are all accessible from the first screen encounter and are reinforced by in-app labels in the user's language.

---

## 6. Session Event Logging with Timestamps

**Specification:** For each session, the system shall log timestamps for destination set, route start, each turn event, and arrival to support verification of time-based specifications.

**How it is met:**

The `SessionEventType` enum defines every required event type:

```dart
enum SessionEventType {
  destinationSet,          // → "DESTINATION_SET"
  routeComputationStart,   // → "ROUTE_COMPUTATION_START"
  routeStarted,            // → "ROUTE_STARTED"
  turnLeft,                // → "TURN_LEFT"
  turnRight,               // → "TURN_RIGHT"
  offRoute,                // → "OFF_ROUTE"
  arrived,                 // → "ARRIVED"
}
```

Each `SessionEvent` carries a **UTC `DateTime` timestamp** captured at the moment the event fires. Events are accumulated in a `NavigationSession` object and persisted via the `LogEventUsecase`. Sessions are reviewable in the **Session History** screen and exportable as structured JSON (including `millisecondsSinceEpoch` for each event) via the in-app export dialog.

This log structure directly supports verification of:
- **Haptic latency** (time from `turnLeft`/`turnRight` to haptic trigger)
- **Route computation time** (`routeComputationStart` → `routeStarted` delta)
- **End-to-end navigation time** (`routeStarted` → `arrived` delta)
- **Off-route frequency** (count of `offRoute` events per session)

> **Evidence files:** `lib/domain/entities/session_event.dart`, `lib/domain/entities/navigation_session.dart`, `lib/domain/usecases/log_event_usecase.dart`, `lib/presentation/pages/session_history/`.

---

*Report prepared based on codebase state as of April 2026.*
