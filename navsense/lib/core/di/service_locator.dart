import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';

import '../../data/datasources/local_session_datasource.dart';
import '../../data/datasources/floor_route_datasource.dart';
import '../../data/repositories/route_repository_impl.dart';
import '../../data/repositories/session_repository_impl.dart';
import '../../domain/repositories/route_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/usecases/compute_route_usecase.dart';
import '../../domain/usecases/log_event_usecase.dart';
import '../../domain/usecases/start_navigation_usecase.dart';
import '../../services/ble/ble_service.dart';
import '../../services/ble/mock_ble_service.dart';
import '../../services/ble/real_ble_service.dart';
import '../../services/haptic/haptic_service.dart';
import '../../services/haptic/haptic_service_impl.dart';
import '../../services/haptic/udp_wearable_haptic_service.dart';
import '../../services/haptic/wearable_haptic_service.dart';
import '../../services/logging/session_logging_service.dart';
import '../../services/logging/session_logging_service_impl.dart';
import '../../services/routing/mock_route_service.dart';
import '../../services/routing/route_service.dart';
import '../../services/uwb/uwb_service.dart';
import '../../services/uwb/mock_uwb_service.dart';
import '../../services/uwb/real_uwb_service.dart';
import '../../services/positioning_service.dart';

final sl = GetIt.instance;

/// Registers all dependencies (SR-ARCH-03: dependency injection).
/// Only this file imports concrete implementations — all other code
/// depends on abstract interfaces.
Future<void> setupServiceLocator() async {
  // Datasources
  sl.registerLazySingleton<LocalSessionDatasource>(
      () => LocalSessionDatasource());
  sl.registerLazySingleton<FloorRouteDatasource>(() => FloorRouteDatasource());

  // Repositories
  sl.registerLazySingleton<RouteRepository>(
    () => RouteRepositoryImpl(sl<FloorRouteDatasource>()),
  );
  sl.registerLazySingleton<SessionRepository>(
    () => SessionRepositoryImpl(sl<LocalSessionDatasource>()),
  );

  // Use Cases
  sl.registerLazySingleton(() => ComputeRouteUseCase(sl<RouteRepository>()));
  sl.registerLazySingleton(() => LogEventUseCase(sl<SessionRepository>()));
  sl.registerLazySingleton(
      () => StartNavigationUseCase(sl<SessionRepository>()));

  // Services
  sl.registerLazySingleton<BleService>(
    () => kIsWeb ? MockBleService() : RealBleService(),
  );

  // UWB Service - uses mock on web, real on mobile
  sl.registerLazySingleton<UwbService>(
    () => kIsWeb ? MockUwbService() : RealUwbService(),
  );

  // Positioning Service - fuses UWB + BLE data
  sl.registerLazySingleton<PositioningService>(
    () => PositioningService(
        uwbService: sl<UwbService>(), bleService: sl<BleService>()),
  );

  sl.registerLazySingleton<HapticService>(() => HapticServiceImpl());
  sl.registerLazySingleton<WearableHapticService>(
      () => UdpWearableHapticService());
  sl.registerLazySingleton<RouteService>(
    () => MockRouteService(sl<FloorRouteDatasource>()),
  );
  sl.registerLazySingleton<SessionLoggingService>(
    () => SessionLoggingServiceImpl(sl<SessionRepository>()),
  );
}
