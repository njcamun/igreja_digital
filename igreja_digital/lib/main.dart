import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/main_navigation_screen.dart';
import 'presentation/services/notification_service.dart';

// Flag para evitar registro duplicado do handler em background
bool _backgroundHandlerRegistered = false;

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyC9KEUXB4a4JLi3uG0RJsbBEGMov1zsHi0',
  appId: '1:755775079358:web:a10b598c6e811ed8662fef',
  messagingSenderId: '755775079358',
  projectId: 'igreja-digita',
  authDomain: 'igreja-digita.firebaseapp.com',
  storageBucket: 'igreja-digita.firebasestorage.app',
  measurementId: 'G-ETKB51X5VG',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: _webFirebaseOptions);
  } else {
    await Firebase.initializeApp();
  }

  // Registrar handler de mensagens em background apenas uma vez
  if (!kIsWeb && !_backgroundHandlerRegistered) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _backgroundHandlerRegistered = true;
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    // Inicializar notificações quando o usuário está logado
    ref.watch(notificationInitializerProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Igreja Digital',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: authState.when(
        data: (user) {
          if (user == null) return const LoginScreen();
          return const MainNavigationScreen();
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) =>
            Scaffold(body: Center(child: Text('Erro: $err'))),
      ),
    );
  }
}
