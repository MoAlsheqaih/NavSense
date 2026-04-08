import 'package:flutter/material.dart';

import '../../../domain/entities/route_plan.dart';
import '../../../domain/entities/waypoint.dart';
import '../../../domain/usecases/compute_route_usecase.dart';
import '../../../services/routing/route_service.dart';

enum HomeState { idle, loading, error }

class HomeViewModel extends ChangeNotifier {
  final ComputeRouteUseCase _computeRoute;
  final RouteService _routeService;

  HomeViewModel(this._computeRoute, this._routeService);

  HomeState _state = HomeState.idle;
  List<Waypoint> _destinations = [];
  Waypoint? _origin;
  Waypoint? _selected;
  String? _errorMessage;

  HomeState get state => _state;
  List<Waypoint> get destinations => _destinations;
  Waypoint? get selectedOrigin => _origin;
  Waypoint? get selectedDestination => _selected;
  String? get errorMessage => _errorMessage;

  bool get canStart =>
      _origin != null && _selected != null && _origin!.id != _selected!.id;

  Future<void> loadDestinations() async {
    _state = HomeState.loading;
    notifyListeners();
    try {
      _destinations = await _routeService.getAvailableDestinations();
      _state = HomeState.idle;
    } catch (e) {
      _errorMessage = e.toString();
      _state = HomeState.error;
    }
    notifyListeners();
  }

  void selectOrigin(Waypoint waypoint) {
    _origin = waypoint;
    if (_selected?.id == waypoint.id) _selected = null;
    notifyListeners();
  }

  void selectDestination(Waypoint waypoint) {
    _selected = waypoint;
    if (_origin?.id == waypoint.id) _origin = null;
    notifyListeners();
  }

  Future<RoutePlan?> startNavigation() async {
    if (!canStart) return null;
    _state = HomeState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final plan = await _computeRoute(_origin!, _selected!);
      _state = HomeState.idle;
      notifyListeners();
      return plan;
    } catch (e) {
      _errorMessage = e.toString();
      _state = HomeState.error;
      notifyListeners();
      return null;
    }
  }
}
