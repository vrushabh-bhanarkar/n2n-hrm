import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/data/source/network/connect.dart';
import 'package:cnattendance/data/source/network/model/about/Aboutresponse.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:flutter/material.dart';

class AboutRepository {
  // Extract only the content inside <body>...</body> if present, otherwise return original
  String _extractBody(String html) {
    try {
      final lower = html.toLowerCase();
      final bodyOpen = lower.indexOf('<body');
      if (bodyOpen == -1) return html;
      final bodyTagEnd = html.indexOf('>', bodyOpen);
      if (bodyTagEnd == -1) return html;
      final bodyClose = lower.lastIndexOf('</body>');
      if (bodyClose == -1 || bodyClose <= bodyTagEnd) return html;
      return html.substring(bodyTagEnd + 1, bodyClose).trim();
    } catch (_) {
      return html;
    }
  }
  Future<Aboutresponse> getContent(String value) async {
    Preferences preferences = Preferences();
    String token = await preferences.getToken();

    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token'
    };

    try {
      // New dedicated endpoints for about and terms (return full HTML documents)
      if (value == 'about-us' || value == 'terms-and-conditions') {
        final path = "/api/$value";
        debugPrint('Fetching content from: $path');
        final response = await Connect().getResponse(path, headers);
        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Response body: ${response.body.toString()}');

        final Map<String, dynamic> responseData = json.decode(response.body);

        if (response.statusCode == 200 && (responseData['status'] == true)) {
          // Extract HTML from specific key
          String title = value == 'about-us' ? 'About Us' : 'Terms and Conditions';
          String html = '';
          if (value == 'about-us') {
            html = (responseData['data']?['about_us'] ?? '').toString();
          } else {
            html = (responseData['data']?['terms_conditions'] ?? '').toString();
          }

          // Sanitize: pick only body content if full document provided
          html = _extractBody(html);

          // Normalize to existing Aboutresponse model shape
          final normalized = {
            'status': true,
            'message': 'Data Found',
            'status_code': 200,
            'data': {
              'title': title,
              'content_type': 'html',
              'description': html,
            }
          };

          return Aboutresponse.fromJson(normalized);
        } else {
          final msg = responseData['message'] ?? 'Content not available';
          throw msg;
        }
      }

      // Fallback: legacy static page content endpoint
      debugPrint('Fetching content from legacy endpoint: ${Constant.CONTENT_URL}/$value/');
      final response = await Connect()
          .getResponse("${Constant.CONTENT_URL}/$value/", headers);
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body.toString()}');

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final dashboardResponse = Aboutresponse.fromJson(responseData);
        return dashboardResponse;
      } else {
        var errorMessage = responseData['message'] ?? 'API request failed';
        debugPrint('API Error: $errorMessage');
        // Make error message more user-friendly
        if (errorMessage.toString().toLowerCase().contains('not found')) {
          throw 'Content not available. Please contact your administrator to add this content.';
        }
        throw errorMessage;
      }
    } catch (e) {
      debugPrint('Exception in getContent: ${e.toString()}');
      throw unknownError(e);
    }
  }
}
