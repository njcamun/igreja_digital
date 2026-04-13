import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Conta')),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'Como utilizamos o Login com Google, a sua palavra-passe é gerida pela sua conta Google. Se tiver problemas em entrar, tente recuperar o acesso através da página de recuperação de conta da Google.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
