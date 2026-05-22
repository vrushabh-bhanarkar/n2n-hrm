import 'dart:convert';

import 'package:cnattendance/data/source/datastore/preferences.dart';
import 'package:cnattendance/utils/logging_middleware.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class Connect {
  Future<http.Response> getResponse(
      String url, Map<String, String> headers) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "langauge": language,
    }.entries);

    final http.Client client = await LoggingMiddleware.create();
    var uri = Uri.parse(await preferences.getAppUrl() + url);
    try {
      return await client.get(uri, headers: headers);
    } finally {
      client.close();
    }
  }

  Future<http.Response> postResponse(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "langauge": language,
    }.entries);

    final http.Client client = await LoggingMiddleware.create();
    var uri = Uri.parse(await preferences.getAppUrl() + url);
    try {
      return await client.post(uri, headers: headers, body: body);
    } finally {
      client.close();
    }
  }

  Future<http.Response> postResponseRaw(String url, Map<String, String> headers,
      Map<String, dynamic> body) async {
    Preferences preferences = Preferences();
    final storage = GetStorage();
    String language = storage.read("language") ?? "en";

    headers.addEntries({
      "langauge": language,
    }.entries);

    final http.Client client = await LoggingMiddleware.create();
    var uri = Uri.parse(await preferences.getAppUrl() + url);
    try {
      return await client.post(uri, headers: headers, body: jsonEncode(body));
    } finally {
      client.close();
    }
  }
}
