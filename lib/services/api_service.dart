class ApiService {
  static const String serverIp = "192.168.1.16";
  static const String serverPort = "8000";
  // Emulator Android: ganti serverIp jadi "10.0.2.2"

  static const String baseUrl = "http://$serverIp:$serverPort/api";
  static const String storageUrl = "http://$serverIp:$serverPort";

  // Auth
  static const String login = "$baseUrl/login";
  static const String me = "$baseUrl/me";
  static const String logout = "$baseUrl/logout";
  static String get passwordChange => '$baseUrl/password/change';

  // Menu aplikasi
  static String get beranda => '$baseUrl/beranda';
  static String get riwayat => '$baseUrl/riwayat';
  static String get profil => '$baseUrl/profil';
  static String get profilFoto => '$baseUrl/profil/foto';
  static String get notifikasi => '$baseUrl/notifikasi';
  static String notifikasiBuzzer(int id) => '$baseUrl/notifikasi/$id/buzzer';
  static String notifikasiRespon(int id) => '$baseUrl/notifikasi/$id/respon';
  static String get panggilPetugas => '$baseUrl/panggil-petugas';
  static String get perpanjang => '$baseUrl/perpanjang';
  static String get perpanjangStatus => '$baseUrl/perpanjang/status';
  static String perpanjangBukti(int id) => '$baseUrl/perpanjang/$id/bukti';
  static String perpanjangItem(int id) => '$baseUrl/perpanjang/$id';
}