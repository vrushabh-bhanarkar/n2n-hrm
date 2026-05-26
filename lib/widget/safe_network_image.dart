import 'package:flutter/material.dart';

/// Simple wrapper around Image.network that logs URL and error when decoding fails.
class SafeNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget? placeholder;

  const SafeNetworkImage(
    this.url, {
    Key? key,
    this.width,
    this.height,
    this.fit,
    this.placeholder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return placeholder ?? const SizedBox.shrink();
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Log the failing URL and error to console for diagnosis
        debugPrint('⚠️ SafeNetworkImage failed for $url: $error');
        return placeholder ?? const SizedBox.shrink();
      },
    );
  }
}
