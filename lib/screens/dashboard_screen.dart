import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/dashboard_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';
import 'izin_akses_screen.dart';
import 'login_screen.dart';

/// Warna mengikuti web ParkVisi (sama dengan layar login).
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
}

const _bulan = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _tanggal(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

String _jam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

String _durasi(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final j = d.inHours;
  final m = d.inMinutes % 60;
  return j > 0 ? '${j}j ${m}m' : '${m}m';
}

String _sapaan() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Selamat pagi';
  if (h < 15) return 'Selamat siang';
  if (h < 18) return 'Selamat sore';
  return 'Selamat malam';
}

Widget _cahaya(double ukuran, Color warna) {
  return Container(
    width: ukuran,
    height: ukuran,
    decoration: BoxDecoration(shape: BoxShape.circle, color: warna),
  );
}

// ───────────────────────────── Layar utama ─────────────────────────────

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = DashboardService.ambil();
  }

  Future<void> _muatUlang() async {
    final baru = DashboardService.ambil();
    setState(() => _future = baru);
    try {
      await baru;
    } catch (_) {
      // Galat ditampilkan oleh FutureBuilder, di sini cukup menutup spinner.
    }
  }

  bool _sedangKeluar = false;

  /// Dipakai saat server menolak token (sesi habis / akun dinonaktifkan).
  Future<void> _keLogin() async {
    if (_sedangKeluar) return;
    _sedangKeluar = true;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String get _nama =>
      (widget.user['name'] ?? widget.user['phone'] ?? '').toString();

  // ───────── Panggil petugas ─────────

  bool _memanggil = false;

  Future<void> _panggilPetugas() async {
    if (_memanggil) return;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.support_agent, size: 36, color: _Warna.amber),
        title: const Text('Panggil petugas?'),
        content: const Text(
          'Bel di gerbang akan berbunyi dan pesan WhatsApp dikirim ke petugas. '
          'Gunakan hanya jika Anda butuh bantuan.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _Warna.amber,
              foregroundColor: _Warna.navy,
              elevation: 0,
            ),
            child: const Text('Ya, panggil'),
          ),
        ],
      ),
    );
    if (yakin != true || !mounted) return;

    setState(() => _memanggil = true);
    String pesan;
    try {
      final token = await AuthService.getToken();
      final res = await http
          .post(
            Uri.parse(ApiService.panggilPetugas),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      pesan = body['message']?.toString() ?? 'Permintaan dikirim.';
    } catch (_) {
      pesan = 'Tidak bisa terhubung ke server. Coba lagi.';
    }

    if (!mounted) return;
    setState(() => _memanggil = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pesan)));
  }

  // ───────── Perpanjang ─────────

  Future<void> _perpanjang() async {
    final berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _PerpanjangSementara()),
    );
    // Setelah kembali dari layar perpanjang, muat ulang supaya status terbaru tampil
    if (berhasil == true) _muatUlang();
  }

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Warna.paper,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _memanggil ? null : _panggilPetugas,
          backgroundColor: _memanggil ? _Warna.garis : _Warna.amber,
          foregroundColor: _Warna.navy,
          elevation: 3,
          icon: _memanggil
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _Warna.navy,
                  ),
                )
              : const Icon(Icons.support_agent),
          label: Text(
            _memanggil ? 'Memanggil...' : 'Panggil petugas',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: RefreshIndicator(
          color: _Warna.tealGelap,
          edgeOffset: atas,
          onRefresh: _muatUlang,
          child: FutureBuilder<DashboardData>(
            future: _future,
            builder: (context, snap) {
              Widget halaman({required Widget? paket, required Widget isi}) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    _Kepala(nama: _nama, atas: atas, paket: paket),
                    Padding(
                      // bawah diberi ruang supaya tombol melayang tidak menutupi kartu terakhir
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 110),
                      child: isi,
                    ),
                  ],
                );
              }

              if (snap.connectionState != ConnectionState.done) {
                return halaman(
                  paket: const _PaketMemuat(),
                  isi: const SizedBox.shrink(),
                );
              }

              if (snap.hasError) {
                if (snap.error is SesiBerakhirException) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _keLogin(),
                  );
                  return halaman(
                    paket: const _PaketMemuat(),
                    isi: const SizedBox.shrink(),
                  );
                }
                return halaman(paket: null, isi: _Galat(onUlang: _muatUlang));
              }

              final data = snap.requireData;
              return halaman(
                paket: _KartuPaket(
                  paket: data.paket,
                  menunggu: false, // nanti diisi dari API (ada pembayaran menunggu admin)
                  onPerpanjang: _perpanjang,
                ),
                isi: _DaftarKendaraan(kendaraan: data.kendaraan),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Layar perpanjang (sementara) ─────────────────────────────

/// Placeholder. Nanti diganti layar Perpanjang yang sebenarnya
/// (pilih paket, tagihan, metode bayar, unggah bukti).
class _PerpanjangSementara extends StatelessWidget {
  const _PerpanjangSementara();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Warna.paper,
      appBar: AppBar(
        title: const Text('Perpanjang paket'),
        backgroundColor: Colors.white,
        foregroundColor: _Warna.navy,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Layar perpanjang segera hadir',
          style: TextStyle(color: _Warna.muted),
        ),
      ),
    );
  }
}

// ───────────────────────────── Header navy ─────────────────────────────

class _Kepala extends StatelessWidget {
  final String nama;
  final double atas;
  final Widget? paket;
  const _Kepala({required this.nama, required this.atas, required this.paket});

  @override
  Widget build(BuildContext context) {
    final inisial = nama.isEmpty ? '?' : nama[0].toUpperCase();

    return Container(
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
            child: _cahaya(240, const Color(0x2600C2A8)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _cahaya(200, const Color(0x14FFB100)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, atas + 18, 20, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _Warna.teal,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        inisial,
                        style: const TextStyle(
                          color: _Warna.navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _sapaan(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (paket != null) ...[const SizedBox(height: 22), paket!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Kartu paket (kaca) ─────────────────────────────

class _Kaca extends StatelessWidget {
  final Widget child;
  final Color? warna;
  const _Kaca({required this.child, this.warna});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: warna ?? const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: child,
    );
  }
}

class _PaketMemuat extends StatelessWidget {
  const _PaketMemuat();

  @override
  Widget build(BuildContext context) {
    return const _Kaca(
      child: SizedBox(
        height: 110,
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: _Warna.teal,
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuPaket extends StatelessWidget {
  final PaketAktif? paket;
  final bool menunggu;
  final VoidCallback onPerpanjang;
  const _KartuPaket({
    required this.paket,
    required this.menunggu,
    required this.onPerpanjang,
  });

  @override
  Widget build(BuildContext context) {
    final p = paket;

    // Belum berlangganan
    if (p == null) {
      return _Kaca(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0x1AFFFFFF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.workspace_premium_outlined,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada paket aktif',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Hubungi petugas untuk berlangganan.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final sisa = p.sisaHari;
    final habis = sisa < 0;
    final hampir = !habis && sisa <= 7;
    final aksen = habis ? const Color(0xFFFF9A9A) : _Warna.teal;

    return _Kaca(
      warna: habis ? const Color(0x40E5484D) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                habis ? 'PAKET BERAKHIR' : 'PAKET AKTIF',
                style: TextStyle(
                  color: aksen,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.workspace_premium,
                color: _Warna.amber,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nama,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      habis
                          ? 'Berakhir ${_tanggal(p.berakhir)}'
                          : 'Berlaku sampai ${_tanggal(p.berakhir)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (habis)
                    const Text(
                      'Kedaluwarsa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else if (sisa == 0)
                    const Text(
                      'Hari terakhir',
                      style: TextStyle(
                        color: _Warna.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else ...[
                    Text(
                      '$sisa',
                      style: const TextStyle(
                        color: _Warna.teal,
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'hari lagi',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (!habis && p.progres != null) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.progres,
                minHeight: 6,
                backgroundColor: const Color(0x26FFFFFF),
                color: _Warna.teal,
              ),
            ),
          ],
          if (menunggu) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x2600C2A8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x4D00C2A8)),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: _Warna.teal,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pembayaran sedang diverifikasi petugas. Paket akan diperpanjang setelah disetujui.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (habis || hampir) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: habis
                    ? const Color(0x26FFFFFF)
                    : const Color(0x24FFB100),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: habis ? Colors.white : _Warna.amber,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          habis
                              ? 'Paket sudah habis. Perpanjang agar bisa masuk lagi.'
                              : 'Paket segera berakhir. Perpanjang sebelum habis.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: onPerpanjang,
                    icon: const Icon(Icons.autorenew_rounded, size: 20),
                    label: const Text('Perpanjang sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _Warna.amber,
                      foregroundColor: _Warna.navy,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onPerpanjang,
                icon: const Icon(
                  Icons.autorenew_rounded,
                  size: 16,
                  color: Colors.white70,
                ),
                label: const Text(
                  'Perpanjang lebih awal',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Daftar kendaraan ─────────────────────────────

class _DaftarKendaraan extends StatelessWidget {
  final List<KendaraanStatus> kendaraan;
  const _DaftarKendaraan({required this.kendaraan});

  @override
  Widget build(BuildContext context) {
    final didalam = kendaraan.where((k) => k.didalam).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Kendaraan saya',
              style: TextStyle(
                color: _Warna.navy,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (kendaraan.isNotEmpty)
              Text(
                '$didalam dari ${kendaraan.length} di dalam',
                style: const TextStyle(color: _Warna.muted, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (kendaraan.isEmpty)
          const _KosongKendaraan()
        else
          for (final k in kendaraan) _KartuKendaraan(kendaraan: k),
      ],
    );
  }
}

class _KartuKendaraan extends StatelessWidget {
  final KendaraanStatus kendaraan;
  const _KartuKendaraan({required this.kendaraan});

  @override
  Widget build(BuildContext context) {
    final k = kendaraan;
    final masuk = k.masukSejak;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Warna.garis),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0B1D33),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: k.didalam ? _Warna.tealSoft : _Warna.paper,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  k.motor ? Icons.two_wheeler : Icons.directions_car,
                  color: k.didalam ? _Warna.tealGelap : _Warna.muted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k.plat,
                      style: const TextStyle(
                        color: _Warna.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      k.motor ? 'Motor' : 'Mobil',
                      style: const TextStyle(color: _Warna.muted, fontSize: 13),
                    ),
                    if (masuk != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 15,
                            color: _Warna.tealGelap,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'Masuk ${_jam(masuk)} · ${_durasi(DateTime.now().difference(masuk))}',
                              style: const TextStyle(
                                color: _Warna.tealGelap,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _LencanaStatus(didalam: k.didalam),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IzinAksesScreen(kendaraan: k),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Beri akses tamu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Warna.navy,
                side: const BorderSide(color: _Warna.garis),
                minimumSize: const Size.fromHeight(42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LencanaStatus extends StatelessWidget {
  final bool didalam;
  const _LencanaStatus({required this.didalam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: didalam ? _Warna.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: didalam ? _Warna.teal : _Warna.garis),
      ),
      child: Text(
        didalam ? 'Di dalam' : 'Di luar',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: didalam ? _Warna.navy : _Warna.muted,
        ),
      ),
    );
  }
}

class _KosongKendaraan extends StatelessWidget {
  const _KosongKendaraan();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _Warna.paper,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_outlined,
              size: 28,
              color: _Warna.muted,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum ada kendaraan terdaftar.\nDaftarkan kendaraan Anda di pos petugas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Warna.muted, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Galat memuat ─────────────────────────────

class _Galat extends StatelessWidget {
  final VoidCallback onUlang;
  const _Galat({required this.onUlang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _Warna.garis,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_off, size: 34, color: _Warna.muted),
          ),
          const SizedBox(height: 16),
          const Text(
            'Data tidak bisa dimuat.\nPeriksa sambungan Anda lalu coba lagi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Warna.navy, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onUlang,
            style: ElevatedButton.styleFrom(
              backgroundColor: _Warna.amber,
              foregroundColor: _Warna.navy,
              minimumSize: const Size(170, 48),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}