import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class CustomHttpClient {
  // Note: We don't cache clients anymore to avoid "Client is already closed" errors
  
  static Future<http.Client> getClient() async {
    // Always create a new client instead of reusing to avoid "Client is already closed" errors
    try {
      // Load custom certificate for both debug and release builds
      final certData = await rootBundle.load('assets/ca/lets-encrypt-r3.pem');
      final certBytes = certData.buffer.asUint8List();

      SecurityContext context = SecurityContext.defaultContext;
      context.setTrustedCertificatesBytes(certBytes);

      HttpClient httpClient = HttpClient(context: context);
      
      // Set reasonable timeouts
      httpClient.connectionTimeout = Duration(seconds: 30);
      httpClient.idleTimeout = Duration(seconds: 30);

      // Certificate validation strategy based on build mode
      httpClient.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        if (kDebugMode) {
          // In debug mode, be more lenient but still log warnings
          print('⚠️ Certificate warning for $host:$port');
          return true;
        } else {
          // In release mode, check specific trusted hosts
          final trustedHosts = [
            'firestore.googleapis.com',
            'firebase.googleapis.com',
            'googleapis.com',
            'n2nhostings.com',
            // Allow local development hosts and common emulator/device IPs.
            // Notes:
            // - Android emulator (default) -> use 10.0.2.2 to reach host 127.0.0.1 on the host machine
            // - Genymotion emulator -> use 10.0.3.2
            // - Physical devices on same LAN -> use host machine LAN IP (e.g., 192.168.x.x)
            // - Some code or stray literals may show '127.0.0.1' but emulators usually need the mappings below
            'localhost',
            '10.0.2.2', // Android emulator (default)
            '10.0.3.2', // Genymotion
            '192.168.', // prefix match for local LAN addresses
            '127.0.0.1',
            // Keep original host (production) as trusted
            'n2n.n2nhostings.com',
            // Add your API endpoints here
          ];
          
          for (String trustedHost in trustedHosts) {
            // If the trustedHost is a suffix/prefix or contains a dot, use contains check.
            // For entries like '192.168.' we'll do a startsWith/contains check as appropriate.
            if (trustedHost.endsWith('.') ? host.startsWith(trustedHost) : host.contains(trustedHost)) {
              return true;
            }
          }
          
          print('❌ Certificate rejected for $host:$port in release mode');
          return false;
        }
      };

      return IOClient(httpClient);
    } catch (e) {
      print('Error loading custom certificate: $e');
      // Create a more robust fallback client
      HttpClient httpClient = HttpClient();
      httpClient.connectionTimeout = Duration(seconds: 30);
      httpClient.idleTimeout = Duration(seconds: 30);
      
      // Fallback certificate callback
      httpClient.badCertificateCallback = 
          (X509Certificate cert, String host, int port) {
        print('⚠️ Using fallback certificate validation for $host:$port');
        return kDebugMode; // Only allow in debug mode
      };
      
      return IOClient(httpClient);
    }
  }
}
