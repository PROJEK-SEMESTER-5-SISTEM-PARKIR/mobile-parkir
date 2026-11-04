import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'auth_service.dart';

class PetugasService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null) {
      throw AuthException('Sesi habis. Silakan login ulang.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _pesan(http.Response res, String fallback) {
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['message']?.toString() ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Panggil petugas: buzzer di gerbang menyala + WhatsApp ke petugas.
  /// Return pesan dari server, atau lempar AuthException.
  static Future<String> panggil({String? catatan}) async {
    final headers = await _headers();
    try {
      final res = await http
          .post(
            Uri.parse(ApiService.panggilPetugas),
            headers: headers,
            body: jsonEncode({if (catatan != null) 'note': catatan}),
          )
          .timeout(const Duration(seconds: 15));

      final pesan = _pesan(res, 'Petugas sedang dipanggil.');
      if (res.statusCode == 200) return pesan;
      throw AuthException(pesan);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('Tidak bisa terhubung ke server. Cek koneksi Anda.');
    }
  }

  /// Batalkan panggilan (mematikan buzzer).
  static Future<void> batal() async {
    final headers = await _headers();
    try {
      await http
          .delete(Uri.parse(ApiService.panggilPetugas), headers: headers)
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw AuthException('Gagal membatalkan panggilan. Coba lagi.');
    }
  }
}