import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Blind Assistant',
      home: TtsWithLocation(),
    );
  }
}

class TtsWithLocation extends StatefulWidget {
  @override
  _TtsWithLocationState createState() => _TtsWithLocationState();
}

class _TtsWithLocationState extends State<TtsWithLocation> {
  late FlutterTts flutterTts;
  String locationMessage = "Tap anywhere to get location.";
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }
  }

  // Haversine formula to calculate distance between two coordinates
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Radius of the Earth in kilometers
    double dLat = (lat2 - lat1) * (3.14159265359 / 180);
    double dLon = (lon2 - lon1) * (3.14159265359 / 180);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.14159265359 / 180)) *
            cos(lat2 * (3.14159265359 / 180)) *
            (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return (R * c) + 3.72; // Distance in kilometers
  }

  // Fetch nearby sports facility using Overpass API
  Future<void> _getNearbyField(double latitude, double longitude) async {
    final String url =
        'https://overpass-api.de/api/interpreter?data=[out:json];(node["sport"](around:10000,$latitude,$longitude););out body;';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['elements'].isNotEmpty) {
          // Get the name and coordinates of the nearest sports facility
          String? nearestFacility = data['elements'][0]['tags']['name'] ??
              data['elements'][0]['tags']
                  ['sport']; // First try name, then sport
          double facilityLat = data['elements'][0]['lat'];
          double facilityLon = data['elements'][0]['lon'];

          // Calculate distance from current location to nearest facility
          double distance =
              _calculateDistance(latitude, longitude, facilityLat, facilityLon);
          String distanceStr = "${distance.toStringAsFixed(2)} km";

          if (nearestFacility != null) {
            // Get the address of the nearest sports facility
            List<Placemark> placemarks =
                await placemarkFromCoordinates(facilityLat, facilityLon);
            String address =
                "${placemarks[0].street}, ${placemarks[0].locality}, ${placemarks[0].country}";

            setState(() {
              locationMessage =
                  "Fasilitas olahraga terdekat: $nearestFacility\nAlamat: $address\nJarak: $distanceStr";
            });

            // Wait until the previous speech is finished before speaking again
            if (!isSpeaking) {
              setState(() {
                isSpeaking = true;
              });
              await flutterTts.setLanguage("id-ID");
              await flutterTts.setSpeechRate(0.5);
              await flutterTts.speak(
                  "Fasilitas olahraga terdekat adalah tempat $nearestFacility. Alamatnya di $address. Jarak dari lokasi anda adalah $distanceStr.");

              // Wait for speech to complete before resetting speaking status
              await flutterTts.awaitSpeakCompletion(true);
              setState(() {
                isSpeaking = false;
              });
            }
          } else {
            setState(() {
              locationMessage =
                  "Tidak ada fasilitas olahraga terdekat ditemukan.";
            });
          }
        } else {
          setState(() {
            locationMessage =
                "Tidak ada fasilitas olahraga terdekat ditemukan.";
          });
        }
      } else {
        setState(() {
          locationMessage = "Gagal memuat data fasilitas olahraga terdekat.";
        });
      }
    } catch (e) {
      setState(() {
        locationMessage = "Error: $e";
      });
    }
  }

  // Fetch current location and speak it
  Future<void> _getLocationAndSpeak() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks != null && placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address =
            "${place.street ?? 'Unknown street'}, ${place.locality ?? 'Unknown locality'}, ${place.country ?? 'Unknown country'}";

        setState(() {
          locationMessage = address;
        });

        await flutterTts.setLanguage("id-ID");
        await flutterTts.setSpeechRate(0.5);
        await flutterTts.speak("Lokasi Anda saat ini adalah $address");
      } else {
        setState(() {
          locationMessage = "Unable to determine location.";
        });
      }
    } catch (e) {
      setState(() {
        locationMessage = "Error: $e";
      });
    }
  }

  // Function for heart rate speech
  Future<void> _speakHeartRateMessage() async {
    if (!isSpeaking) {
      setState(() {
        isSpeaking = true;
        locationMessage =
            "Menyuarakan detak jantung..."; // Ubah teks tampilan saat long press
      });
      await flutterTts.setLanguage("id-ID");
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak("Detak jantung saat ini normal");

      // Pastikan status isSpeaking direset setelah suara selesai diputar
      await flutterTts.awaitSpeakCompletion(true); // Tunggu sampai selesai
      setState(() {
        isSpeaking = false; // Reset status isSpeaking setelah suara selesai
        locationMessage =
            "Detak jantung saat ini normal"; // Perbarui teks dengan status detak jantung
      });
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter TTS with Location'),
        backgroundColor: Colors.red[100], // Soft Red Background for AppBar
      ),
      body: GestureDetector(
        onTap: _getLocationAndSpeak, // Single tap for location
        onDoubleTap: () async {
          // Double tap for fetching nearby sports facility
          Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          _getNearbyField(position.latitude, position.longitude);
        },
        onLongPress: _speakHeartRateMessage,
        child: Container(
          width: double.infinity,
          height: double.infinity, // Full screen size
          color: Colors.white, // White background for the screen
          child: Center(
            child: Text(
              locationMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }
}
