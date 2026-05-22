import 'package:cached_network_image/cached_network_image.dart';
import 'package:cnattendance/provider/profileprovider.dart';
import 'package:cnattendance/screen/profile/editprofilescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';

class Heading extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => HeadingState();
}

class HeadingState extends State<Heading> {
  @override
  Widget build(BuildContext context) {
    bool isLoading = false;

    final profile = Provider.of<ProfileProvider>(context).profile;

    // Debug: Print avatar URL to console
    print('Profile Avatar URL: "${profile.avatar}"');

    // Check if avatar URL is valid
    bool isValidUrl = profile.avatar.isNotEmpty &&
        profile.avatar != 'null' &&
        (profile.avatar.startsWith('http://') ||
            profile.avatar.startsWith('https://'));

    return WillPopScope(
      onWillPop: () async {
        return !isLoading;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 15),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10)),
              child: isValidUrl
                  ? CachedNetworkImage(
                      imageUrl: profile.avatar,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 50, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) {
                        print('Error loading profile image: $error');
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey[700],
                          child: const Icon(Icons.person, size: 60, color: Colors.white70),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[700],
                      child: const Icon(Icons.person, size: 60, color: Colors.white70),
                    ),
            ),
            SizedBox(
              width: 15,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  child: Text(
                    profile.username,
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
                Text(
                  profile.name,
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: Text(
                    profile.email,
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context)
                        .pushNamed(EditProfileScreen.routeName);
                  },
                  child: Card(
                    margin: EdgeInsets.only(top: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomRight: Radius.circular(10)),
                    ),
                    color: HexColor("#036eb7"),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        translate('edit_profile_screen.edit_profile'),
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
