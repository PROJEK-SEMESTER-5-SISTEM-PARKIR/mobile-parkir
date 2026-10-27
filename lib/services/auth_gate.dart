import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import 'auth_service.dart';
import 'change_password_screen.dart';

enum _Hasil { login, koneksi, masuk }

/// Dipanggil saat aplikasi dibuka: kalau token masih valid langsung masuk,
/// kalau tidak baru ke layar login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<(_Hasil, Map<String, dynamic>?)> _future;

  @override
  void initState() {
    super.initState();
    _future = _periksa();
  }

  Future<(_Hasil, Map<String, dynamic>?)> _periksa() async {
    if (await AuthService.getToken() == null) return (_Hasil.login, null);

    final user = await AuthService.me();
    if (user != null) return (_Hasil.masuk, user);

    // me() menghapus token kalau server menolaknya (401/403).
    // Kalau token masih ada, berarti masalahnya hanya koneksi: jangan paksa login ulang.
    if (await AuthService.getToken() != null) return (_Hasil.koneksi, null);

    return (_Hasil.login, null);
  }

  void _ulang() => setState(() => _future = _periksa());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(_Hasil, Map<String, dynamic>?)>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0B1D33),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00C2A8)),
            ),
          );
        }

        final (hasil, user) = snap.data ?? (_Hasil.login, null);

        switch (hasil) {
          case _Hasil.masuk:
            return user!['must_change_password'] == true
                ? ChangePasswordScreen(user: user, wajib: true)
                : MainShell(user: user);
          case _Hasil.koneksi:
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Tidak bisa terhubung ke server.\nPeriksa WiFi lalu coba lagi.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _ulang,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          case _Hasil.login:
            return const LoginScreen();
        }
      },
    );
  }
}