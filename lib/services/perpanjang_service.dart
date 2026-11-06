import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/perpanjang_data.dart';
import 'api_service.dart';
import 'auth_service.dart';

class PerpanjangException implements Exception {
  final String message;
  PerpanjangException(this.message);
  @override
  String toString() => message;
}

class PerpanjangService {
  static Future<Map<String, String>> _header() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static String _pesan(dynamic body) {
    if (body is Map) {
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final pertama = errors.values.first;
        if (pertama is List && pertama.isNotEmpty) {
          return pertama.first.toString();
        }
      }
      if (body['message'] != null) return body['message'].toString();
    }
    return 'Terjadi kesalahan. Coba lagi.';
  }

  static dynamic _urai(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const SesiBerakhirException();
    }
    dynamic body;
    try {
      body = res.body.isEmpty ? {} : jsonDecode(res.body);
    } catch (_) {
      body = {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw PerpanjangException(_pesan(body));
  }

  static Future<T> _jalankan<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PerpanjangException {
      rethrow;
    } on SesiBerakhirException {
      rethrow;
    } catch (_) {
      throw PerpanjangException(
          'Tidak bisa terhubung ke server. Periksa sambungan Anda.');
    }
  }

  static Future<PerpanjangData> ambil() => _jalankan(() async {
        final res = await http
            .get(Uri.parse(ApiService.perpanjang), headers: await _header())
            .timeout(const Duration(seconds: 15));
        return PerpanjangData.fromJson(_urai(res) as Map<String, dynamic>);
      });

  static Future<bool> menunggu() => _jalankan(() async {
        final res = await http
            .get(Uri.parse(ApiService.perpanjangStatus),
                headers: await _header())
            .timeout(const Duration(seconds: 15));
        return (_urai(res) as Map<String, dynamic>)['menunggu'] == true;
      });

  static Future<Tagihan> buatTagihan(int planId, int akunId) =>
      _jalankan(() async {
        final res = await http
            .post(
              Uri.parse(ApiService.perpanjang),
              headers: {
                ...await _header(),
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'plan_id': planId, 'account_id': akunId}),
            )
            .timeout(const Duration(seconds: 15));
        final body = _urai(res) as Map<String, dynamic>;
        return Tagihan.fromJson(body['bill'] as Map<String, dynamic>);
      });

  static Future<void> unggahBukti(int id, String pathFoto) =>
      _jalankan(() async {
        final req = http.MultipartRequest(
            'POST', Uri.parse(ApiService.perpanjangBukti(id)))
          ..headers.addAll(await _header())
          ..files.add(await http.MultipartFile.fromPath('proof', pathFoto));
        final streamed = await req.send().timeout(const Duration(seconds: 60));
        _urai(await http.Response.fromStream(streamed));
      });

  static Future<void> batalkan(int id) => _jalankan(() async {
        final res = await http
            .delete(Uri.parse(ApiService.perpanjangItem(id)),
                headers: await _header())
            .timeout(const Duration(seconds: 15));
        _urai(res);
      });
}