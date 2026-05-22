import 'package:cnattendance/repositories/aboutrepository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:get/get.dart';

class AboutController extends GetxController {
  AboutRepository repository = AboutRepository();

  var isLoading = false.obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;

  var _content = <String, String>{
    'title': '',
    'description': '',
  }.obs;

  Map<String, String> get content {
    return _content;
  }

  Future<void> getContent(String value) async {
    // Reset state
    hasError.value = false;
    errorMessage.value = '';

    try {
      isLoading.value = true;
      EasyLoading.show(
          status: translate('loader.loading'),
          maskType: EasyLoadingMaskType.black);

      debugPrint('AboutController: Fetching content for: $value');
      final response = await repository.getContent(value);

      debugPrint('AboutController: API Response - Status: ${response.status}');
      debugPrint(
          'AboutController: API Response - Message: ${response.message}');
      debugPrint(
          'AboutController: API Response - StatusCode: ${response.statusCode}');
      debugPrint('AboutController: Content Title: ${response.data.title}');
      debugPrint(
          'AboutController: Content Description length: ${response.data.description.length}');

      _content.value = {
        'title': response.data.title,
        'description': response.data.description,
      };

      debugPrint('AboutController: Content updated in observable');

      // Check if content is actually loaded
      if (_content['title']?.isEmpty ?? true) {
        debugPrint('AboutController: Title is empty, setting error state');
        hasError.value = true;
        errorMessage.value = 'No content available';
        isLoading.value = false;
        EasyLoading.dismiss(animation: true);
        return;
      }

      isLoading.value = false;
      EasyLoading.dismiss(animation: true);
      debugPrint('AboutController: Content loaded successfully');
    } catch (e) {
      isLoading.value = false;
      hasError.value = true;
      errorMessage.value = e.toString();
      EasyLoading.dismiss(animation: true);

      debugPrint('AboutController: Error loading content: ${e.toString()}');
      debugPrint('AboutController: Error type: ${e.runtimeType}');

      Get.snackbar(
        'Error',
        'Failed to load content. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
      );
    }
  }

  @override
  void onClose() {
    EasyLoading.dismiss();
    super.onClose();
  }
}
