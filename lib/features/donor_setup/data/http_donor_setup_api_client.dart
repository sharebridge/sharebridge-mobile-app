import 'dart:convert';
import 'dart:io';

import 'donor_setup_api_client.dart';

class HttpDonorSetupApiClient implements DonorSetupApiClient {
  HttpDonorSetupApiClient({
    required this.baseUrl,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String baseUrl;
  final HttpClient _httpClient;

  @override
  Future<Map<String, dynamic>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    final uri = Uri.parse('$baseUrl/v1/donor-setup/suggest-vendors');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;

    final payload = <String, dynamic>{
      'query_text': queryText,
      'location_precision': lat != null && lng != null ? 'gps' : 'manual_area',
      'client_platform': 'flutter-mobile',
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (manualArea != null && manualArea.trim().isNotEmpty)
        'manual_area': manualArea,
    };

    request.write(jsonEncode(payload));
    final response = await request.close();
    final body = await utf8.decodeStream(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Suggest vendors failed with status ${response.statusCode}: $body',
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('API must return a JSON object');
    }
    return decoded;
  }

  @override
  Future<void> savePresets(List<Map<String, dynamic>> payload) async {
    final uri = Uri.parse('$baseUrl/v1/donor-setup/preferences');
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(<String, dynamic>{'presets': payload}));

    final response = await request.close();
    final body = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Save presets failed with status ${response.statusCode}: $body',
      );
    }
  }
}
