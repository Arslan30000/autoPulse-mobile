enum UserRole { carOwner, mechanic }

class RoleService {
  static final RoleService _instance = RoleService._();
  factory RoleService() => _instance;
  RoleService._();

  UserRole _currentRole = UserRole.carOwner;

  UserRole get currentRole => _currentRole;

  void setRole(UserRole role) {
    _currentRole = role;
  }

  bool get isCarOwner => _currentRole == UserRole.carOwner;
  bool get isMechanic => _currentRole == UserRole.mechanic;

  void switchRole() {
    _currentRole = _currentRole == UserRole.carOwner
        ? UserRole.mechanic
        : UserRole.carOwner;
  }
}
