import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get onAuthStateChanged;
  Future<UserEntity?> signInWithGoogle();
  Future<void> signOut();
  Future<UserEntity?> getCurrentUser();
}
