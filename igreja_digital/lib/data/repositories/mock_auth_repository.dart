import 'dart:async';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<UserEntity?>();
  UserEntity? _currentUser;

  @override
  Stream<UserEntity?> get onAuthStateChanged => _controller.stream;

  @override
  Future<UserEntity?> signInWithGoogle() async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = UserEntity(
      uid: 'mock_admin_id',
      fullName: 'Administrador Local',
      email: 'admin@teste.com',
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _controller.add(_currentUser);
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    return _currentUser;
  }
}
