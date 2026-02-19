enum RegistrationState {
  unavailable,
  registering,
  registered,
  unregistering;

  static RegistrationState fromString(String value) {
    return RegistrationState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RegistrationState.unavailable,
    );
  }
}
