import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dashboard_data.dart';

class _Warna {
  static const navy = Color(0xFF0B1D33);
  static const navy2 = Color(0xFF132A47);
  static const teal = Color(0xFF00C2A8);
  static const amber = Color(0xFFFFB100);
  static const paper = Color(0xFFF8FAFC);
  static const garis = Color(0xFFE2E8F0);
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

String _format(DateTime d) =>
    '${d.day} ${_bulan[d.month - 1]} ${d.year}, '
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

/// Waktu sekarang, dibulatkan ke menit (detik dibuang).
DateTime _sekarang() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, n.hour, n.minute);
}

/// Hanya tanggalnya (jam 00.00).
DateTime _hanyaTanggal(DateTime d) => DateTime(d.year, d.month, d.day);

class IzinAksesScreen extends StatefulWidget {
  final KendaraanStatus kendaraan;
  const IzinAksesScreen({super.key, required this.kendaraan});

  @override
  State<IzinAksesScreen> createState() => _IzinAksesScreenState();
}

class _IzinAksesScreenState extends State<IzinAksesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _telp = TextEditingController();

  late DateTime _mulai;
  late DateTime _berakhir;
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mulai = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      0,
    ).add(const Duration(hours: 1));
    _berakhir = _mulai.add(const Duration(hours: 24));
  }

  @override
  void dispose() {
    _nama.dispose();
    _telp.dispose();
    super.dispose();
  }

  /// Memilih tanggal lalu jam.
  /// Tanggal & jam sebelum [minimal] tidak bisa dipilih:
  /// - tanggal sebelum [minimal] dinonaktifkan di kalender
  /// - jam yang masih sebelum [minimal] ditolak dengan pesan
  Future<DateTime?> _pilih(DateTime awal, DateTime minimal) async {
    final awalAman = awal.isBefore(minimal) ? minimal : awal;

    final tgl = await showDatePicker(
      context: context,
      initialDate: awalAman,
      firstDate: _hanyaTanggal(minimal),
      lastDate: _hanyaTanggal(minimal).add(const Duration(days: 365)),
    );
    if (tgl == null || !mounted) return null;

    final jam = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(awalAman),
    );
    if (jam == null) return null;

    final hasil = DateTime(tgl.year, tgl.month, tgl.day, jam.hour, jam.minute);
    if (hasil.isBefore(minimal)) {
      if (mounted) {
        _pesan(
          'Waktu tidak boleh sebelum ${_format(minimal)}.',
          galat: true,
        );
      }
      return null;
    }
    return hasil;
  }

  Future<void> _pilihMulai() async {
    // Mulai izin: tidak boleh sebelum waktu sekarang.
    final d = await _pilih(_mulai, _sekarang());
    if (d == null) return;
    setState(() {
      _mulai = d;
      if (!_berakhir.isAfter(_mulai)) {
        _berakhir = _mulai.add(const Duration(hours: 24));
      }
    });
  }

  Future<void> _pilihBerakhir() async {
    // Sampai: tidak boleh sebelum waktu sekarang maupun waktu mulai.
    final batasMulai = _mulai.add(const Duration(minutes: 1));
    final sekarang = _sekarang();
    final minimal = batasMulai.isAfter(sekarang) ? batasMulai : sekarang;

    final d = await _pilih(_berakhir, minimal);
    if (d == null) return;
    setState(() => _berakhir = d);
  }

  void _pesan(String teks, {bool galat = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor: galat ? _Warna.merah : null,
      ),
    );
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mulai.isBefore(_sekarang())) {
      _pesan(
        'Waktu mulai sudah lewat. Pilih ulang waktu mulai.',
        galat: true,
      );
      return;
    }
    if (!_berakhir.isAfter(_mulai)) {
      _pesan('Waktu berakhir harus setelah waktu mulai.', galat: true);
      return;
    }
    setState(() => _mengirim = true);
    try {
      // TODO: sambungkan ke backend nanti, mis.
      // await IzinTamuService.kirim(plat: ..., nama: ..., ...);
      await Future.delayed(const Duration(milliseconds: 600)); // simulasi
      if (!mounted) return;
      _pesan('Izin akses untuk ${_nama.text.trim()} berhasil dibuat.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _pesan(e.toString().replaceFirst('Exception: ', ''), galat: true);
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  InputDecoration _dekor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Warna.garis),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Warna.garis),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _Warna.navy2, width: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final atas = MediaQuery.of(context).padding.top;
    final k = widget.kendaraan;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _Warna.paper,
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              // ── Header ──
              Container(
                padding: EdgeInsets.fromLTRB(16, atas + 10, 16, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_Warna.navy, _Warna.navy2],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0x1AFFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Izin Akses Tamu',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x26FFFFFF)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0x33FFFFFF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              k.motor
                                  ? Icons.two_wheeler
                                  : Icons.directions_car,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: k.plat,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '  • ${k.motor ? 'Motor' : 'Mobil'}',
                                    style: const TextStyle(
                                      color: Color(0xFF99F6E4),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x3310B981),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0x4D6EE7B7),
                              ),
                            ),
                            child: const Text(
                              'VIP Aktif',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Form ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _Warna.garis),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text(
                            'Data Pengemudi Tamu',
                            style: TextStyle(
                              color: _Warna.navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '*Wajib diisi',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),
                      const _Label('Nama Lengkap Pengemudi'),
                      TextFormField(
                        controller: _nama,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _dekor('Masukkan nama tamu'),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Nama minimal 3 karakter'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _Label('Nomor WhatsApp'),
                      TextFormField(
                        controller: _telp,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(13),
                        ],
                        decoration: _dekor('812xxxxxxxx').copyWith(
                          prefixIcon: Container(
                            width: 56,
                            alignment: Alignment.center,
                            child: const Text(
                              '+62',
                              style: TextStyle(
                                color: _Warna.muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        validator: (v) {
                          var s = (v ?? '').trim();
                          if (s.startsWith('0')) s = s.substring(1);
                          return (s.length < 8 || s.length > 12)
                              ? 'Nomor tidak valid'
                              : null;
                        },
                      ),
                      const Divider(height: 32, color: Color(0xFFF1F5F9)),
                      const Row(
                        children: [
                          _Label('Rentang Waktu Izin Akses', bawah: 0),
                          Spacer(),
                          Text(
                            'WIB',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _KotakWaktu(
                              judul: 'Mulai Izin',
                              nilai: _format(_mulai),
                              onTap: _pilihMulai,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KotakWaktu(
                              judul: 'Sampai',
                              nilai: _format(_berakhir),
                              onTap: _pilihBerakhir,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Tombol ──
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: ElevatedButton.icon(
                  onPressed: _mengirim ? null : _kirim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Warna.amber,
                    foregroundColor: _Warna.navy,
                    minimumSize: const Size.fromHeight(56),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _mengirim
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: _Warna.navy,
                          ),
                        )
                      : const Icon(Icons.verified_user),
                  label: const Text(
                    'Beri Izin Akses Pengemudi Tamu',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String teks;
  final double bawah;
  const _Label(this.teks, {this.bawah = 6});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: bawah),
    child: Text(
      teks,
      style: const TextStyle(
        color: Color(0xFF475569),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _KotakWaktu extends StatelessWidget {
  final String judul;
  final String nilai;
  final VoidCallback onTap;
  const _KotakWaktu({
    required this.judul,
    required this.nilai,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(judul, style: const TextStyle(color: _Warna.muted, fontSize: 11)),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Warna.garis),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    nilai,
                    style: const TextStyle(
                      color: _Warna.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.calendar_month,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}