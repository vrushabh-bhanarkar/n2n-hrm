import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../safe_cached_image.dart';

class MeetingParticipator extends StatelessWidget {
  final String image;

  MeetingParticipator(this.image);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: SafeCachedImage(
        imageUrl: image,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        borderRadius: 20,
      ),
    );
  }
}
