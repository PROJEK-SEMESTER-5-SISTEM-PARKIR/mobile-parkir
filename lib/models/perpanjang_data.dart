int _int(dynamic v) {
  if (v is num) return v.toInt();
  return double.tryParse('${v ?? ''}')?.round() ?? 0;
}

class KendaraanPerpanjang {
  final String plat;
  final bool motor;
  KendaraanPerpanjang(this.plat, this.motor);

  factory KendaraanPerpanjang.fromJson(Map<String, dynamic> j) =>
      KendaraanPerpanjang(
        (j['plate'] ?? '').toString(),
        j['type'] == 'motor',
      );
}

class PaketPilihan {
  final int id;
  final String nama;
  final int hari;
  final int hargaMobil;
  final int hargaMotor;
  final bool populer;

  PaketPilihan({
    required this.id,
    required this.nama,
    required this.hari,
    required this.hargaMobil,
    required this.hargaMotor,
    required this.populer,
  });

  factory PaketPilihan.fromJson(Map<String, dynamic> j) => PaketPilihan(
        id: _int(j['id']),
        nama: (j['name'] ?? '').toString(),
        hari: _int(j['duration_days']),
        hargaMobil: _int(j['price_mobil']),
        hargaMotor: _int(j['price_motor']),
        populer: j['is_popular'] == true,
      );

  int totalUntuk(List<KendaraanPerpanjang> k) =>
      k.fold(0, (t, e) => t + (e.motor ? hargaMotor : hargaMobil));
}

class MetodeBayar {
  final int id;
  final String tipe; // bank | qris
  final String label;
  final String? nomor;
  final String? atasNama;
  final String? qrisPath;

  MetodeBayar({
    required this.id,
    required this.tipe,
    required this.label,
    this.nomor,
    this.atasNama,
    this.qrisPath,
  });

  bool get qris => tipe == 'qris';

  factory MetodeBayar.fromJson(Map<String, dynamic> j) => MetodeBayar(
        id: _int(j['id']),
        tipe: (j['type'] ?? 'bank').toString(),
        label: (j['label'] ?? '').toString(),
        nomor: j['account_number']?.toString(),
        atasNama: j['account_name']?.toString(),
        qrisPath: j['qris_path']?.toString(),
      );
}

class Tagihan {
  final int id;
  final String status; // pending | waiting | approved | rejected | expired
  final String namaPaket;
  final int hari;
  final int jumlahKendaraan;
  final int dasar;
  final int kode;
  final int total;
  final String? alasanTolak;
  final DateTime kedaluwarsa;
  final bool adaBukti;
  final MetodeBayar? metode;

  Tagihan({
    required this.id,
    required this.status,
    required this.namaPaket,
    required this.hari,
    required this.jumlahKendaraan,
    required this.dasar,
    required this.kode,
    required this.total,
    required this.alasanTolak,
    required this.kedaluwarsa,
    required this.adaBukti,
    required this.metode,
  });

  factory Tagihan.fromJson(Map<String, dynamic> j) => Tagihan(
        id: _int(j['id']),
        status: (j['status'] ?? '').toString(),
        namaPaket: (j['plan_name'] ?? '-').toString(),
        hari: _int(j['plan_days']),
        jumlahKendaraan: _int(j['vehicle_count']),
        dasar: _int(j['base_amount']),
        kode: _int(j['unique_code']),
        total: _int(j['total_amount']),
        alasanTolak: j['reject_reason']?.toString(),
        kedaluwarsa: DateTime.parse(j['expires_at'].toString()).toLocal(),
        adaBukti: j['has_proof'] == true,
        metode: j['account'] is Map<String, dynamic>
            ? MetodeBayar.fromJson(j['account'] as Map<String, dynamic>)
            : null,
      );
}

class PerpanjangData {
  final List<PaketPilihan> paket;
  final List<KendaraanPerpanjang> kendaraan;
  final List<MetodeBayar> metode;
  final Tagihan? tagihan; // pending / waiting
  final Tagihan? terakhir; // rejected / approved (tanpa tagihan aktif)

  PerpanjangData({
    required this.paket,
    required this.kendaraan,
    required this.metode,
    required this.tagihan,
    required this.terakhir,
  });

  factory PerpanjangData.fromJson(Map<String, dynamic> j) {
    List<T> daftar<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();

    Tagihan? satu(String k) => j[k] is Map<String, dynamic>
        ? Tagihan.fromJson(j[k] as Map<String, dynamic>)
        : null;

    return PerpanjangData(
      paket: daftar('plans', PaketPilihan.fromJson),
      kendaraan: daftar('vehicles', KendaraanPerpanjang.fromJson),
      metode: daftar('accounts', MetodeBayar.fromJson),
      tagihan: satu('bill'),
      terakhir: satu('last'),
    );
  }
}