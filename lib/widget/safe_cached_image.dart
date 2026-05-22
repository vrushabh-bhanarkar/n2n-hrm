import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A safe wrapper for CachedNetworkImage that handles empty URLs and errors gracefully
class SafeCachedImage extends StatelessWidget {
  final String imageUrl;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;

  const SafeCachedImage({
    Key? key,
    required this.imageUrl,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Handle empty or invalid URLs - more defensive checks
    final trimmedUrl = imageUrl.trim();
    if (trimmedUrl.isEmpty ||
        !trimmedUrl.startsWith('http://') &&
            !trimmedUrl.startsWith('https://') ||
        trimmedUrl.length < 10) {
      // Minimum valid URL length
      return _buildErrorWidget();
    }

    // URL-encode the image URL to handle spaces and special characters in filenames
    String encodedUrl = _encodeImageUrl(trimmedUrl);

    Widget imageWidget = CachedNetworkImage(
      imageUrl: encodedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _buildPlaceholder(),
      errorWidget: (context, url, error) {
        // Silently show fallback widget without logging errors
        return errorWidget ?? _buildErrorWidget();
      },
      // Disable console error logging
      errorListener: (error) {
        // Suppress error logging to avoid console spam
      },
    );

    if (borderRadius > 0) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// URL-encode only the filename part to handle spaces and special characters
  String _encodeImageUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      List<String> pathSegments = uri.pathSegments;

      if (pathSegments.isNotEmpty) {
        // Encode only the last path segment (filename)
        String filename = pathSegments.last;
        String encodedFilename = Uri.encodeComponent(filename);

        // Rebuild the URL with encoded filename
        pathSegments[pathSegments.length - 1] = encodedFilename;

        Uri newUri = uri.replace(pathSegments: pathSegments);
        return newUri.toString();
      }

      return url;
    } catch (e) {
      // If encoding fails, return original URL
      return url;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/dummy_avatar.png',
          width: width,
          height: height,
          fit: fit ?? BoxFit.cover,
        ),
      ),
    );
  }
}
