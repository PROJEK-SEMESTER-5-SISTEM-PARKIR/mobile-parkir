import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/perpanjang_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/perpanjang_service.dart';
import 'login_screen.dart';
import 'dart:io';

/// Warna mengikuti dashboard_screen.dart.
class _Warna {
  static const navy = Color(0xFF0B1D33);
  static const navy2 = Color(0xFF132A47);
  static const teal = Color(0xFF00C2A8);
  static const tealGelap = Color(0xFF00857A);
  static const tealSoft = Color(0xFFD9F5F0);
  static const amber = Color(0xFFFFB100);
  static const amberSoft = Color(0xFFFFF3D6);
  static const paper = Color(0xFFF4F6F8);
  static const garis = Color(0xFFE4E9EE);
  static const muted = Color(0xFF5B6B7A);
  static const merah = Color(0xFFB42318);
  static const merahSoft = Color(0xFFFDE8E6);
}

const _bulan = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _rp(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return 'Rp $out';
}

String _waktu(DateTime d) {
  String dua(int v) => v.toString().padLeft(2, '0');
  return '${d.day} ${_bulan[d.month - 1]}, ${dua(d.hour)}.${dua(d.minute)}';
}

class PerpanjangScreen extends StatefulWidget {
  const PerpanjangScreen({super.key});

  @override
  State<PerpanjangScreen> createState() => _PerpanjangScreenState();
}

class _PerpanjangScreenState extends State<PerpanjangScreen> {
  PerpanjangData? _data;
  bool _memuat = true;
  String? _galat;

  int? _planId;
  int? _akunId;
  bool _kirim = false; // sedang buat tagihan / unggah / batal
  String? _fotoPath;
  bool _lewati = false; // sembunyikan hasil terakhir, mulai perpanjangan baru
  bool _sedangKeluar = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _muat();
    // Saat menunggu admin, cek berkala supaya status berubah sendiri
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_data?.tagihan?.status == 'waiting' && !_kirim) {
        _muat(diam: true);
      }
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _keLogin() async {
    if (_sedangKeluar) return;
    _sedangKeluar = true;
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _muat({bool diam = false}) async {
    if (!diam) setState(() => _memuat = true);
    try {
      final d = await PerpanjangService.ambil();
      if (!mounted) return;
      setState(() {
        _data = d;
        _galat = null;
        _memuat = false;
        if (d.paket.isNotEmpty && !d.paket.any((p) => p.id == _planId)) {
          _planId = d.paket
              .firstWhere((p) => p.populer, orElse: () => d.paket.first)
              .id;
        }
        if (d.metode.isNotEmpty && !d.metode.any((m) => m.id == _akunId)) {
          _akunId = d.metode.first.id;
        }
      });
    } on SesiBerakhirException {
      await _keLogin();
    } on PerpanjangException catch (e) {
      if (!mounted) return;
      if (!diam || _data == null) {
        setState(() {
          _galat = e.message;
          _memuat = false;
        });
      }
    }
  }

  void _info(String teks) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(teks)));
  }

  Future<void> _salin(String teks, String label) async {
    await Clipboard.setData(ClipboardData(text: teks));
    _info('$label disalin');
  }

  /// Bungkus aksi jaringan: tangani loading dan galat di satu tempat.
  Future<void> _aksi(Future<void> Function() f) async {
    setState(() => _kirim = true);
    try {
      await f();
    } on SesiBerakhirException {
      await _keLogin();
      return;
    } on PerpanjangException catch (e) {
      _info(e.message);
    }
    if (mounted) setState(() => _kirim = false);
  }

  Future<void> _buat() async {
    final plan = _planId, akun = _akunId;
    if (plan == null || akun == null) return;

    await _aksi(() async {
      await PerpanjangService.buatTagihan(plan, akun);
      _fotoPath = null;
      _lewati = false;
      await _muat(diam: true);
    });
  }

  Future<void> _pilihFoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (x != null && mounted) setState(() => _fotoPath = x.path);
    } catch (_) {
      _info('Tidak bisa membuka galeri.');
    }
  }

  Future<void> _kirimBukti(Tagihan t) async {
    final path = _fotoPath;
    if (path == null) {
      _info('Pilih foto bukti pembayaran dulu.');
      return;
    }
    await _aksi(() async {
      await PerpanjangService.unggahBukti(t.id, path);
      _fotoPath = null;
      await _muat(diam: true);
      _info('Bukti terkirim. Menunggu verifikasi petugas.');
    });
  }

  Future<void> _batalkan(Tagihan t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan tagihan?'),
        content: const Text(
            'Tagihan ini dibatalkan. Jika sudah membayar, jangan batalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Batalkan',
                style: TextStyle(color: _Warna.merah)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _aksi(() async {
      await PerpanjangService.batalkan(t.id);
      _fotoPath = null;
      await _muat(diam: true);
    });
  }

  // ───────────────────────────── Tampilan ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;
    final d = _data;

    String sub = 'Pilih paket dan metode pembayaran';
    final tg = d?.tagihan;
    if (tg?.status == 'pending') sub = 'Selesaikan pembayaran Anda';
    if (tg?.status == 'waiting') sub = 'Menunggu verifikasi petugas';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Warna.paper,
        body: RefreshIndicator(
          color: _Warna.tealGelap,
          edgeOffset: atas,
          onRefresh: () => _muat(diam: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _Kepala(atas: atas, sub: sub),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                child: _isi(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _isi() {
    if (_memuat) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator(color: _Warna.teal)),
      );
    }

    final d = _data;
    if (d == null) {
      return _Pesan(
        ikon: Icons.cloud_off,
        teks: _galat ?? 'Data tidak bisa dimuat.',
        tombol: 'Coba lagi',
        onTombol: _muat,
      );
    }

    final t = d.tagihan;
    if (t != null && t.status == 'pending') return _viewTagihan(t);
    if (t != null && t.status == 'waiting') return _viewMenunggu(t);

    final last = d.terakhir;
    if (!_lewati && last != null && last.status == 'approved') {
      return _viewSukses(last);
    }

    return _viewPilih(d, last != null && last.status == 'rejected' ? last : null);
  }

  // ───────── Pilih paket + metode ─────────

  Widget _viewPilih(PerpanjangData d, Tagihan? ditolak) {
    if (d.kendaraan.isEmpty) {
      return const _Pesan(
        ikon: Icons.directions_car_outlined,
        teks: 'Belum ada kendaraan terdaftar.\nHubungi petugas di pos parkir.',
      );
    }
    if (d.paket.isEmpty) {
      return const _Pesan(
        ikon: Icons.info_outline,
        teks: 'Belum ada paket yang tersedia.\nCoba lagi nanti.',
      );
    }
    if (d.metode.isEmpty) {
      return const _Pesan(
        ikon: Icons.account_balance_outlined,
        teks: 'Metode pembayaran belum diatur petugas.\nCoba lagi nanti.',
      );
    }

    final plan =
        d.paket.firstWhere((p) => p.id == _planId, orElse: () => d.paket.first);
    final total = plan.totalUntuk(d.kendaraan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ditolak != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _Warna.merahSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: _Warna.merah),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pembayaran sebelumnya ditolak'
                    '${(ditolak.alasanTolak ?? '').isEmpty ? '.' : ': ${ditolak.alasanTolak}'}'
                    '\nSilakan buat tagihan baru.',
                    style: const TextStyle(
                      color: _Warna.merah,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        const _Judul('1. Pilih paket'),
        for (final p in d.paket)
          _PilihKartu(
            terpilih: p.id == _planId,
            onTap: () => setState(() => _planId = p.id),
            ikon: Icons.workspace_premium_outlined,
            judul: p.nama,
            sub: '${p.hari} hari · ${d.kendaraan.length} kendaraan',
            kanan: _rp(p.totalUntuk(d.kendaraan)),
            lencana: p.populer ? 'Rekomendasi' : null,
          ),
        const SizedBox(height: 10),
        const _Judul('2. Bayar lewat'),
        for (final m in d.metode)
          _PilihKartu(
            terpilih: m.id == _akunId,
            onTap: () => setState(() => _akunId = m.id),
            ikon: m.qris ? Icons.qr_code_2_rounded : Icons.account_balance_outlined,
            judul: m.label,
            sub: m.qris ? 'Scan QRIS' : 'Transfer bank',
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _Warna.garis),
          ),
          child: Column(
            children: [
              _Baris('Paket', plan.nama),
              _Baris('Kendaraan', '${d.kendaraan.length}'),
              _Baris('Harga paket', _rp(total)),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kode unik 3 digit ditambahkan saat tagihan dibuat.',
                  style: TextStyle(color: _Warna.muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _TombolUtama(
          label: 'Buat tagihan',
          memuat: _kirim,
          onTap: _buat,
        ),
        if (last_approvedHint(d)) ...[
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  bool last_approvedHint(PerpanjangData d) => false;

  // ───────── Tagihan (belum bayar) ─────────

  Widget _viewTagihan(Tagihan t) {
    final m = t.metode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_Warna.navy, _Warna.navy2],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t.namaPaket} · ${t.hari} hari',
                style: const TextStyle(color: Colors.white70, fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              const Text(
                'Transfer tepat sebesar',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _rp(t.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _salin('${t.total}', 'Nominal'),
                    icon: const Icon(Icons.copy_rounded, color: _Warna.teal),
                    tooltip: 'Salin nominal',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x24FFB100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: _Warna.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Nominal harus sama persis, termasuk kode unik ${t.kode} '
                        '(${_rp(t.dasar)} + ${t.kode}).',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Bayar sebelum ${_waktu(t.kedaluwarsa)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (m != null) _kartuTujuan(m),
        const SizedBox(height: 16),
        _kartuBukti(t),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _kirim ? null : () => _batalkan(t),
          child: const Text(
            'Batalkan tagihan',
            style: TextStyle(color: _Warna.merah, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _kartuTujuan(MetodeBayar m) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.qris ? 'Scan QRIS' : 'Transfer ke ${m.label}',
            style: const TextStyle(
              color: _Warna.navy,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (m.qris) ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _Warna.garis),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.network(
                  '${ApiService.storageUrl}/storage/${m.qrisPath}',
                  width: 230,
                  height: 230,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    width: 230,
                    height: 230,
                    child: Center(
                      child: Text(
                        'Gambar QRIS tidak bisa dimuat',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _Warna.muted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Buka aplikasi bank atau e-wallet, scan kode ini, lalu masukkan nominal sesuai tagihan.',
              style: TextStyle(color: _Warna.muted, fontSize: 12.5, height: 1.4),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.nomor ?? '-',
                    style: const TextStyle(
                      color: _Warna.navy,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _salin(
                      (m.nomor ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                      'Nomor rekening'),
                  icon: const Icon(Icons.copy_rounded, color: _Warna.tealGelap),
                  tooltip: 'Salin nomor',
                ),
              ],
            ),
            Text(
              'a.n. ${m.atasNama ?? '-'}',
              style: const TextStyle(color: _Warna.muted, fontSize: 13.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuBukti(Tagihan t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Unggah bukti pembayaran',
            style: TextStyle(
              color: _Warna.navy,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Foto atau tangkapan layar bukti transfer.',
            style: TextStyle(color: _Warna.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _kirim ? null : _pilihFoto,
            child: Container(
              height: 190,
              decoration: BoxDecoration(
                color: _Warna.paper,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Warna.garis),
              ),
              clipBehavior: Clip.antiAlias,
              child: _fotoPath == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 38, color: _Warna.muted),
                        SizedBox(height: 8),
                        Text('Ketuk untuk memilih foto',
                            style: TextStyle(color: _Warna.muted)),
                      ],
                    )
                  : Image.file(File(_fotoPath!), fit: BoxFit.cover),
            ),
          ),
          if (_fotoPath != null)
            TextButton(
              onPressed: _kirim ? null : _pilihFoto,
              child: const Text('Ganti foto'),
            ),
          const SizedBox(height: 10),
          _TombolUtama(
            label: 'Kirim bukti',
            memuat: _kirim,
            onTap: () => _kirimBukti(t),
          ),
        ],
      ),
    );
  }

  // ───────── Menunggu admin ─────────

  Widget _viewMenunggu(Tagihan t) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _Warna.amberSoft,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: _Warna.amber,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Menunggu verifikasi',
            style: TextStyle(
              color: _Warna.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Petugas sedang mencocokkan pembayaran Anda. Paket akan diperpanjang setelah disetujui.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _Warna.muted, fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _Warna.garis),
          const SizedBox(height: 14),
          _Baris('Paket', '${t.namaPaket} · ${t.hari} hari'),
          _Baris('Nominal', _rp(t.total)),
          if (t.metode != null) _Baris('Tujuan', t.metode!.label),
          const SizedBox(height: 10),
          const Text(
            'Halaman ini diperbarui otomatis.',
            style: TextStyle(color: _Warna.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ───────── Disetujui ─────────

  Widget _viewSukses(Tagihan t) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _Warna.garis),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _Warna.tealSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 40, color: _Warna.tealGelap),
          ),
          const SizedBox(height: 16),
          const Text(
            'Paket diperpanjang',
            style: TextStyle(
              color: _Warna.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pembayaran ${_rp(t.total)} untuk paket ${t.namaPaket} sudah disetujui.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _Warna.muted, fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 20),
          _TombolUtama(
            label: 'Kembali ke beranda',
            memuat: false,
            onTap: () => Navigator.of(context).pop(true),
          ),
          TextButton(
            onPressed: () => setState(() => _lewati = true),
            child: const Text('Perpanjang lagi'),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Komponen ─────────────────────────────

class _Kepala extends StatelessWidget {
  final double atas;
  final String sub;
  const _Kepala({required this.atas, required this.sub});

  Widget _cahaya(double u, Color w) => Container(
        width: u,
        height: u,
        decoration: BoxDecoration(shape: BoxShape.circle, color: w),
      );

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
            child: _cahaya(220, const Color(0x2600C2A8)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _cahaya(180, const Color(0x14FFB100)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(8, atas + 6, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white),
                  tooltip: 'Kembali',
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perpanjang paket',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sub,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13.5),
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
}

class _Judul extends StatelessWidget {
  final String teks;
  const _Judul(this.teks);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          teks,
          style: const TextStyle(
            color: _Warna.navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _PilihKartu extends StatelessWidget {
  final bool terpilih;
  final VoidCallback onTap;
  final IconData ikon;
  final String judul;
  final String sub;
  final String? kanan;
  final String? lencana;

  const _PilihKartu({
    required this.terpilih,
    required this.onTap,
    required this.ikon,
    required this.judul,
    required this.sub,
    this.kanan,
    this.lencana,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: terpilih ? _Warna.teal : _Warna.garis,
                width: terpilih ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: terpilih ? _Warna.tealSoft : _Warna.paper,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    ikon,
                    color: terpilih ? _Warna.tealGelap : _Warna.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              judul,
                              style: const TextStyle(
                                color: _Warna.navy,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (lencana != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _Warna.amberSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                lencana!,
                                style: const TextStyle(
                                  color: Color(0xFF8A5A00),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: const TextStyle(
                            color: _Warna.muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (kanan != null)
                  Text(
                    kanan!,
                    style: const TextStyle(
                      color: _Warna.navy,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(
                  terpilih
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: terpilih ? _Warna.teal : _Warna.garis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  final String label;
  final String nilai;
  const _Baris(this.label, this.nilai);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(color: _Warna.muted, fontSize: 13.5)),
            const Spacer(),
            Flexible(
              child: Text(
                nilai,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: _Warna.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _TombolUtama extends StatelessWidget {
  final String label;
  final bool memuat;
  final VoidCallback onTap;
  const _TombolUtama({
    required this.label,
    required this.memuat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: memuat ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _Warna.teal,
        foregroundColor: _Warna.navy,
        disabledBackgroundColor: _Warna.tealSoft,
        elevation: 0,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      child: memuat
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: _Warna.navy,
              ),
            )
          : Text(label),
    );
  }
}

class _Pesan extends StatelessWidget {
  final IconData ikon;
  final String teks;
  final String? tombol;
  final VoidCallback? onTombol;

  const _Pesan({
    required this.ikon,
    required this.teks,
    this.tombol,
    this.onTombol,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _Warna.garis,
              shape: BoxShape.circle,
            ),
            child: Icon(ikon, size: 34, color: _Warna.muted),
          ),
          const SizedBox(height: 16),
          Text(
            teks,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _Warna.navy, fontSize: 15, height: 1.4),
          ),
          if (tombol != null) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onTombol,
              style: ElevatedButton.styleFrom(
                backgroundColor: _Warna.amber,
                foregroundColor: _Warna.navy,
                minimumSize: const Size(170, 48),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              child: Text(tombol!),
            ),
          ],
        ],
      ),
    );
  }
}