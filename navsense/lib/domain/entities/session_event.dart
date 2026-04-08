enum SessionEventType {
  destinationSet, routeComputationStart, routeStarted,
  turnLeft, turnRight, offRoute, arrived,
}
extension SessionEventTypeLabel on SessionEventType {
  String get jsonKey {
    switch (this) {
      case SessionEventType.destinationSet:
        return 'DESTINATION_SET';
      case SessionEventType.routeComputationStart:
        return 'ROUTE_COMPUTATION_START';
      case SessionEventType.routeStarted:
        return 'ROUTE_STARTED';
      case SessionEventType.turnLeft:
        return 'TURN_LEFT';
      case SessionEventType.turnRight:
        return 'TURN_RIGHT';
      case SessionEventType.offRoute:
        return 'OFF_ROUTE';
      case SessionEventType.arrived:
        return 'ARRIVED';
    }
  }
}
class SessionEvent {
  final SessionEventType type; final DateTime timestamp; // always UTC

  const SessionEvent({
    required this.type, required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.jsonKey, 'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
