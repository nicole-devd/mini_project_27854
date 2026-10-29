
import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  Future<Map<String, dynamic>> getWeather() async {
    final url = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '-1.9441',
        'longitude': '30.0619',
        'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m',
      },
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Weather API returned status ${response.statusCode}: '
              '${response.body}',
        );
      }

      final data = jsonDecode(response.body);

      if (data['current'] == null) {
        throw Exception('Weather data was not found in the response.');
      }

      return Map<String, dynamic>.from(data['current']);
    } catch (e) {
      throw Exception('Weather request failed: $e');
    }
  }
}
