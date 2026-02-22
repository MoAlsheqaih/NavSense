import '../repositories/session_repository.dart';

class StartNavigationUseCase {
  final SessionRepository _repository;

  const StartNavigationUseCase(this._repository);

  /// Creates a new anonymous session and returns its ID.
  Future<String> call() {
    // User ID is anonymized — never store PII.
    const anonymizedUserId = 'anon-user';
    return _repository.startSession(anonymizedUserId);
  }
}
