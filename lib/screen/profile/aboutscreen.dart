import 'package:cnattendance/provider/aboutcontroller.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:get/get.dart';

class AboutScreen extends StatelessWidget {
  static const routeName = '/about';

  final String title;

  AboutScreen(this.title, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final model = Get.put(AboutController(), tag: title);

    // Load content when screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint(
          'AboutScreen: PostFrameCallback - Checking if content needs to be loaded');
      debugPrint(
          'AboutScreen: Current title in model: ${model.content['title']}');
      debugPrint('AboutScreen: IsLoading: ${model.isLoading.value}');

      if (!model.isLoading.value && (model.content['title']?.isEmpty ?? true)) {
        debugPrint('AboutScreen: Loading content for: $title');
        model.getContent(title);
      } else {
        debugPrint('AboutScreen: Content already loaded or loading');
      }
    });

    return Obx(
      () => Container(
        decoration: RadialDecoration(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
                model.content['title']?.isNotEmpty == true
                    ? model.content['title']!
                    : _getDefaultTitle(title),
                style: TextStyle(color: Colors.white)),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          body: SafeArea(
            child: _buildBody(model),
          ),
        ),
      ),
    );
  }

  String _getDefaultTitle(String slug) {
    switch (slug) {
      case 'about-us':
        return 'About Us';
      case 'terms-and-conditions':
        return 'Terms and Conditions';
      default:
        return 'Information';
    }
  }

  Widget _buildBody(AboutController model) {
    if (model.isLoading.value) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Loading...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    if (model.hasError.value) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 64, color: Colors.orange[300]),
              SizedBox(height: 16),
              Text('Content Not Available',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                  model.errorMessage.value.contains('Data not Found') ||
                          model.errorMessage.value.contains('Data Not Found')
                      ? 'The ${_getDefaultTitle(title)} content has not been added to the system yet. Please contact your administrator.'
                      : model.errorMessage.value,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  model.getContent(title);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (model.content['description']?.isEmpty ?? true) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text('No content available',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                model.getContent(title);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Html(
          style: {
            "body": Style(color: Colors.white, fontSize: FontSize.medium),
            "p": Style(color: Colors.white),
            "div": Style(color: Colors.white),
            "span": Style(color: Colors.white),
            "h1": Style(color: Colors.white),
            "h2": Style(color: Colors.white),
            "h3": Style(color: Colors.white),
            "h4": Style(color: Colors.white),
            "h5": Style(color: Colors.white),
            "h6": Style(color: Colors.white),
            "li": Style(color: Colors.white),
            "ul": Style(color: Colors.white),
            "ol": Style(color: Colors.white),
          },
          data: model.content['description']!,
        ),
      ),
    );
  }
}
