import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<UserEntity?> get onAuthStateChanged {
    // Use a StreamController to implement switchMap behaviour:
    // when Firebase Auth state changes, cancel the previous Firestore
    // subscription and start a new one watching the user document live.
    final controller = StreamController<UserEntity?>.broadcast();
    StreamSubscription? firestoreSub;

    _auth.authStateChanges().listen(
      (firebaseUser) {
        firestoreSub?.cancel();
        firestoreSub = null;

        if (firebaseUser == null) {
          controller.add(null);
          return;
        }

        // Garante que o documento existe antes de observar
        _ensureUserDocument(firebaseUser).then((_) {
          firestoreSub = _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .snapshots()
              .listen(
            (doc) {
              if (!doc.exists || doc.data() == null) {
                controller.add(UserEntity(
                  uid: firebaseUser.uid,
                  fullName: firebaseUser.displayName ?? 'Utilizador',
                  email: firebaseUser.email ?? '',
                  role: UserRole.visitante,
                  congregationId: 'visitor', // Sem congregação
                  isActive: true,
                  createdAt: DateTime.now(),
                ));
                return;
              }
              try {
                controller.add(
                  UserModel.fromMap(
                    Map<String, dynamic>.from(doc.data()!),
                    doc.id,
                  ),
                );
              } catch (_) {
                controller.add(UserEntity(
                  uid: firebaseUser.uid,
                  fullName: firebaseUser.displayName ?? 'Utilizador',
                  email: firebaseUser.email ?? '',
                  role: UserRole.visitante,
                  congregationId: 'visitor', // Sem congregação
                  isActive: true,
                  createdAt: DateTime.now(),
                ));
              }
            },
            onError: controller.addError,
          );
        }).catchError((error) {
          // Se houver erro ao garantir documento, continua sem interromper
          developer.log(
            'Erro ao garantir documento de utilizador',
            name: 'AuthRepositoryImpl',
            error: error,
          );
        });
      },
      onError: controller.addError,
    );

    return controller.stream;
  }

  Future<UserEntity?> _getUserFromFirestore(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, uid);
    }
    return null;
  }

  /// Cria o documento do utilizador no Firestore com valores padrão
  /// se não existir ainda
  Future<UserEntity?> _ensureUserDocument(User firebaseUser) async {
    try {
      final docRef = _firestore.collection('users').doc(firebaseUser.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        // Documento já existe, retorna
        return UserModel.fromMap(docSnapshot.data()!, firebaseUser.uid);
      }

      // Criar novo documento com valores padrão
      // Visitantes começam com congregationId = 'visitor' (sem congregação)
      final newUser = UserModel(
        uid: firebaseUser.uid,
        fullName: firebaseUser.displayName ?? 'Utilizador',
        email: firebaseUser.email ?? '',
        role: UserRole.visitante,
        congregationId: 'visitor', // Sentinela: "sem congregação"
        isActive: true,
        createdAt: DateTime.now(),
      );

      await docRef.set(newUser.toMap());
      return newUser;
    } catch (e) {
      developer.log(
        'Erro ao criar documento de utilizador',
        name: 'AuthRepositoryImpl',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<UserEntity?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Garante que o documento existe no Firestore
        return await _ensureUserDocument(user);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return await _getUserFromFirestore(user.uid);
    }
    return null;
  }
}
