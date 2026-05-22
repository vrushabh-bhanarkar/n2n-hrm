import 'package:cnattendance/data/source/network/model/warningresponse/warningresponse.dart';
import 'package:cnattendance/screen/warningscreen/warningcontroller.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:hexcolor/hexcolor.dart';

class WarningBottomSheet extends StatefulWidget {
  final Warning warning;

  WarningBottomSheet(this.warning);

  @override
  State<StatefulWidget> createState() => WarningBottomSheetState();
}

class WarningBottomSheetState extends State<WarningBottomSheet> {
  final reason = TextEditingController();

  void dismissLoader() {
    setState(() {
      EasyLoading.dismiss(animation: true);
    });
  }

  void showLoader() {
    setState(() {
      EasyLoading.show(
          status: "Requesting...", maskType: EasyLoadingMaskType.black);
    });
  }

  @override
  Widget build(BuildContext context) {
    final WarningController model = Get.find();
    return Container(
      decoration: RadialDecoration(),
      padding: EdgeInsets.only(
          top: 20,
          right: 20,
          left: 20,
          bottom: (MediaQuery.of(context).viewInsets.bottom) + 10),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.warning.subject,
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5.0),
              child: Container(
                width: double.infinity,
                child: Text(
                  widget.warning.message,
                  style: TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
            ),
            if (widget.warning.response.isEmpty)
              SizedBox(
                height: 10,
              ),
            if (widget.warning.response.isEmpty)
              TextField(
                textAlignVertical: TextAlignVertical.top,
                controller: reason,
                maxLines: 3,
                onTapOutside: (event) {
                  FocusScopeNode currentFocus = FocusScope.of(context);
                  if (!currentFocus.hasPrimaryFocus &&
                      currentFocus.focusedChild != null) {
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                },
                style: TextStyle(color: Colors.white),
                //editing controller of this TextField
                cursorColor: Colors.white,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Write a response..',
                  hintStyle: TextStyle(color: Colors.white70),
                  labelStyle: TextStyle(color: Colors.white),
                  fillColor: Colors.white24,
                  filled: true,
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(10))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(10))),
                  focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(10))),
                  errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(10),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(0),
                          bottomRight: Radius.circular(10))),
                ),
              ),
            if (widget.warning.response.isEmpty)
              SizedBox(
                height: 10,
              ),
            if (widget.warning.response.isNotEmpty)
            Card(
              elevation: 0,
              color: Colors.white24,
              shape: ButtonBorder(),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    widget.warning.response,
                    style: TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (widget.warning.response.isEmpty)
              Container(
                width: MediaQuery.of(context).size.width,
                margin: EdgeInsets.symmetric(vertical: 10),
                child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: widget.warning.response.isNotEmpty
                          ? HexColor("#036eb7").withValues(alpha: .5)
                          : HexColor("#036eb7"),
                      padding: EdgeInsets.zero,
                      shape: ButtonBorder(),
                    ),
                    onPressed: widget.warning.response.isNotEmpty
                        ? null
                        : () {
                            sendResponse(model);
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        widget.warning.response.isEmpty
                            ? 'Response'
                            : "Already Responsed",
                        style: TextStyle(color: Colors.white),
                      ),
                    )),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> sendResponse(WarningController model) async {
    if (reason.text.isEmpty) {
      showToast("Response can't be empty");
      return;
    }
    try {
      showLoader();
      var (status, message) =
          await model.saveResponseWarining(reason.text, widget.warning.id);
      dismissLoader();
      
      if (status) {
        // Success - show confirmation and refresh
        showToast("Response submitted successfully!");
        // Shorten the pause so UI feels responsive while still showing feedback
        await Future.delayed(Duration(milliseconds: 500));
        Get.back();
        model.page = 1;
        model.getWarnings();
      } else {
        // Error received - first check if backend actually recorded the response
        debugPrint('Warning Response Error - ID: ${widget.warning.id}, Message: $message');

        try {
          await model.getWarnings();
          Warning? updated;
          try {
            updated = model.warningList
                .firstWhere((w) => w.id == widget.warning.id);
          } catch (_) {
            updated = null;
          }

          if (updated != null && updated.response.isNotEmpty) {
            // Backend recorded response; refresh list, inform user, and close
            model.page = 1;
            await model.getWarnings();
            showToast("Response submitted successfully!");
            // Short pause to allow toast visibility without blocking too long
            await Future.delayed(Duration(milliseconds: 400));
            Get.back();
            return;
          }
        } catch (e) {
          debugPrint('Failed to refresh warnings after error: $e');
        }

        // If we reach here, the response is not recorded; show the mapped message
        showToast(message);

        // Provide additional guidance for specific errors
        if (message.contains("already responded")) {
          debugPrint('Duplicate response attempt for warning ID: ${widget.warning.id}');
        } else if (message.contains("invalid") || message.contains("deleted") || message.contains("administrator")) {
          debugPrint('Data integrity issue for warning ID: ${widget.warning.id}');
        } else if (message.contains("Server error")) {
          debugPrint('Server error for warning ID: ${widget.warning.id}, please retry');
        }
      }
    } catch (e) {
      dismissLoader();
      debugPrint('Exception sending warning response: $e');
      showToast("Failed to send response: ${e.toString()}");
    }
  }
}
