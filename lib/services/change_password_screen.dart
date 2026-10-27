import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:mobile_parkir/screens/login_screen.dart';
import 'package:mobile_parkir/screens/main_shell.dart';

/// Warna mengikuti dashboard_screen.dart.
class _Warna {
  static const navy = Color(0xFF0B1D33);
  static const navy2 = Color(0xFF132A47);
  static const teal = Color(0xFF00C2A8);
  static const tealGelap = Color(0xFF00857A);
  static const tealSoft = Color(0xFFD9F5F0);
  static const amber = Color(0xFFFFB100);
  static const paper = Color(0xFFF4F6F8);
  static const garis = Color(0xFFE4E9EE);
  static const muted = Color(0xFF5B6B7A);
  static const merah = Color(0xFFB42318);
  static const merahSoft = Color(0xFFFDE8E6);
}

/// [wajib] = true saat member baru di-reset admin (must_change_password).
/// Pada mode wajib tombol kembali dimatikan; satu-satunya jalan keluar
/// selain mengganti password adalah tombol "Keluar".
class ChangePasswordScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final bool wajib;

  const ChangePasswordScreen({
    super.key,
    required this.user,
    this.wajib = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _lihatLama = false;
  bool _lihatBaru = false;
  bool _lihatUlang = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _keLogin() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _submit() async {
    if (_current.text.isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      setState(() => _error = 'Semua kolom wajib diisi.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password baru minimal 8 karakter.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.changePassword(
        current: _current.text,
        password: _password.text,
        confirmation: _confirm.text,
      );
      if (!mounted) return;

      if (widget.wajib) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainShell(user: user)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diganti.')),
        );
        Navigator.of(context).pop(true);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on SesiBerakhirException {
      await _keLogin();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Kekuatan password: 0..4 (hanya saran, server hanya mewajibkan min. 8)
  int get _kekuatan {
    final p = _password.text;
    if (p.isEmpty) return 0;
    var skor = 0;
    if (p.length >= 8) skor++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) skor++;
    if (RegExp(r'\d').hasMatch(p)) skor++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p) || p.length >= 12) skor++;
    return skor;
  }

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;
    final nama = (widget.user['name'] ?? '').toString();

    return PopScope(
      canPop: !widget.wajib,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _Warna.paper,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  _Kepala(
                    atas: atas,
                    wajib: widget.wajib,
                    nama: nama,
                    onKeluar: _keLogin,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    child: _formulir(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulir() {
    final cocok = _confirm.text.isNotEmpty && _password.text == _confirm.text;
    final panjangOk = _password.text.length >= 8;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Warna.garis),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0B1D33),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Kolom(
            controller: _current,
            label: widget.wajib ? 'Password sementara' : 'Password saat ini',
            hint: widget.wajib
                ? 'Password dari petugas'
                : 'Masukkan password lama',
            ikon: Icons.lock_clock_outlined,
            tersembunyi: !_lihatLama,
            onLihat: () => setState(() => _lihatLama = !_lihatLama),
            aksi: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _Warna.garis),
          const SizedBox(height: 18),
          _Kolom(
            controller: _password,
            label: 'Password baru',
            hint: 'Minimal 8 karakter',
            ikon: Icons.lock_outline_rounded,
            tersembunyi: !_lihatBaru,
            onLihat: () => setState(() => _lihatBaru = !_lihatBaru),
            aksi: TextInputAction.next,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 10),
          _MeterKekuatan(skor: _kekuatan, kosong: _password.text.isEmpty),
          const SizedBox(height: 16),
          _Kolom(
            controller: _confirm,
            label: 'Ulangi password baru',
            hint: 'Ketik ulang password baru',
            ikon: Icons.verified_user_outlined,
            tersembunyi: !_lihatUlang,
            onLihat: () => setState(() => _lihatUlang = !_lihatUlang),
            aksi: TextInputAction.done,
            onSubmit: _loading ? null : _submit,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 16),
          _Syarat(ok: panjangOk, teks: 'Minimal 8 karakter'),
          const SizedBox(height: 8),
          _Syarat(ok: cocok, teks: 'Konfirmasi password sama'),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _Warna.merahSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 18, color: _Warna.merah),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: _Warna.merah,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Warna.teal,
              foregroundColor: _Warna.navy,
              disabledBackgroundColor: _Warna.tealSoft,
              elevation: 0,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _Warna.navy,
                    ),
                  )
                : const Text('Simpan password'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Header navy ─────────────────────────────

class _Kepala extends StatelessWidget {
  final double atas;
  final bool wajib;
  final String nama;
  final VoidCallback onKeluar;

  const _Kepala({
    required this.atas,
    required this.wajib,
    required this.nama,
    required this.onKeluar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_Warna.navy, _Warna.navy2],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _cahaya(230, const Color(0x2600C2A8)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _cahaya(190, const Color(0x14FFB100)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, atas + 8, 12, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      if (!wajib)
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          tooltip: 'Kembali',
                        ),
                      const Spacer(),
                      if (wajib)
                        TextButton.icon(
                          onPressed: onKeluar,
                          icon: const Icon(Icons.logout_rounded,
                              size: 18, color: Colors.white70),
                          label: const Text(
                            'Keluar',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x1FFFFFFF)),
                        ),
                        child: const Icon(Icons.lock_reset_rounded,
                            color: _Warna.teal, size: 30),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        wajib ? 'Buat password baru' : 'Ganti password',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wajib
                            ? (nama.isEmpty
                                ? 'Demi keamanan, ganti password sementara dari petugas sebelum memakai aplikasi.'
                                : 'Halo, $nama. Demi keamanan, ganti password sementara dari petugas sebelum memakai aplikasi.')
                            : 'Gunakan password yang kuat dan belum dipakai di tempat lain.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cahaya(double ukuran, Color warna) => Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(shape: BoxShape.circle, color: warna),
      );
}

// ───────────────────────────── Komponen form ─────────────────────────────

class _Kolom extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData ikon;
  final bool tersembunyi;
  final VoidCallback onLihat;
  final TextInputAction aksi;
  final VoidCallback? onSubmit;
  final ValueChanged<String>? onChanged;

  const _Kolom({
    required this.controller,
    required this.label,
    required this.hint,
    required this.ikon,
    required this.tersembunyi,
    required this.onLihat,
    required this.aksi,
    this.onSubmit,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder garis(Color warna, [double lebar = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: warna, width: lebar),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _Warna.navy,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: tersembunyi,
          textInputAction: aksi,
          autocorrect: false,
          enableSuggestions: false,
          onChanged: onChanged,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          style: const TextStyle(color: _Warna.navy, fontSize: 15.5),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9AA7B4)),
            filled: true,
            fillColor: _Warna.paper,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: Icon(ikon, size: 20, color: _Warna.muted),
            suffixIcon: IconButton(
              onPressed: onLihat,
              icon: Icon(
                tersembunyi
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: _Warna.muted,
              ),
            ),
            enabledBorder: garis(_Warna.garis),
            border: garis(_Warna.garis),
            focusedBorder: garis(_Warna.tealGelap, 1.8),
          ),
        ),
      ],
    );
  }
}

class _MeterKekuatan extends StatelessWidget {
  final int skor; // 0..4
  final bool kosong;
  const _MeterKekuatan({required this.skor, required this.kosong});

  @override
  Widget build(BuildContext context) {
    final (teks, warna) = switch (skor) {
      0 || 1 => ('Lemah', _Warna.merah),
      2 => ('Cukup', _Warna.amber),
      3 => ('Bagus', _Warna.tealGelap),
      _ => ('Sangat kuat', _Warna.teal),
    };

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    decoration: BoxDecoration(
                      color: !kosong && i < (skor == 0 ? 1 : skor)
                          ? warna
                          : _Warna.garis,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: 5),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 82,
          child: Text(
            kosong ? 'Kekuatan' : teks,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: kosong ? _Warna.muted : warna,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _Syarat extends StatelessWidget {
  final bool ok;
  final String teks;
  const _Syarat({required this.ok, required this.teks});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ok ? _Warna.teal : Colors.transparent,
            border: Border.all(color: ok ? _Warna.teal : _Warna.garis, width: 1.5),
          ),
          child: ok
              ? const Icon(Icons.check_rounded, size: 14, color: _Warna.navy)
              : null,
        ),
        const SizedBox(width: 10),
        Text(
          teks,
          style: TextStyle(
            color: ok ? _Warna.navy : _Warna.muted,
            fontSize: 13.5,
            fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}