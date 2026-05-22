import 'dart:convert';
import 'dart:io';

import 'package:cnattendance/provider/dashboardprovider.dart';
import 'package:cnattendance/provider/prefprovider.dart';
import 'package:cnattendance/utils/constant.dart';
import 'package:cnattendance/widget/attendance_bottom_sheet.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/customnfcdialog.dart';
import 'package:cnattendance/widget/profile/note_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:cnattendance/utils/fallback_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:one_clock/one_clock.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

// import 'package:qr_bar_code_scanner_dialog/qr_bar_code_scanner_dialog.dart';
import 'package:ripple_wave/ripple_wave.dart';

import '../customqrscanner.dart';

class CheckAttendance extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => CheckAttendanceState();
}

class CheckAttendanceState extends State<CheckAttendance> {
  String formattedDate =
      DateFormat('EEEE , MMMM d , yyyy').format(DateTime.now());

  String nepaliFormattedDate =
      NepaliDateFormat('EEE , MMMM d , yyyy').format(NepaliDateTime.now());
  bool _breakRequestDialogQueued = false;
  bool _breakRequestDialogVisible = false;
  bool _breakRequestDialogDismissed = false;
  bool _hasInitializedAttendanceState = false;
  String _lastCheckIn = '-';
  String _lastCheckOut = '-';

  int _attendanceMinutes(Map<String, dynamic> attendanceList, String key) {
    final value = attendanceList[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  bool _isBreakExceeded({
    required int allowedBreakMinutes,
    required int breakUsedMinutes,
    required int remainingBreakMinutes,
  }) {
    if (allowedBreakMinutes <= 0) {
      return false;
    }

    if (remainingBreakMinutes > 0) {
      return false;
    }

    if (remainingBreakMinutes == 0) {
      return breakUsedMinutes >= allowedBreakMinutes;
    }

    return true;
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0 min';

    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (hrs == 0) return '$mins min';
    if (mins == 0) return '$hrs hr';
    return '$hrs hr $mins min';
  }

  void showNFCScanner() {
    if (Platform.isAndroid) {
      showDialog(
        barrierDismissible: false,
        context: context,
        builder: (context) {
          return Dialog(
            child: CustomNfcDialog(NFCMODE.scan),
          );
        },
      );
    }

    if (Platform.isIOS) {
      NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
        onDiscovered: (NfcTag tag) async {
          var identifier = tag.toString();
          onAttendanceVerify("nfc", base64.encode(utf8.encode(identifier)));
          NfcManager.instance.stopSession();
        },
      );
    }
  }

  Future<void> scanQr() async {
    final result = await showCustomQrScanner(context);
    if (result != null && result.trim().isNotEmpty) {
      final provider = context.read<DashboardProvider>();
      if (provider.isNoteEnabled) {
        showModalBottomSheet(
            context: context,
            useRootNavigator: true,
            isScrollControlled: true,
            builder: (context) {
              return NoteBottomSheet(result, "qr");
            });
      } else {
        onAttendanceVerify("qr", result);
      }
    }
  }

  bool isWithinRadius(double lat1, double lon1, double lat2, double lon2,
      double radiusInMeters) {
    double distance = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    return distance <= radiusInMeters;
  }

  void onAttendanceVerify(String type, String identifier) async {
    final provider = context.read<DashboardProvider>();
    ;
    try {
      setState(() {
        EasyLoading.show(
            status: safeTranslate('loader.requesting'),
            maskType: EasyLoadingMaskType.black);
      });
      final response =
          await provider.verifyAttendanceApi(type, "", identifier: identifier);
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(response.message),
            );
          },
        );
      });
    } catch (e) {
      setState(() {
        EasyLoading.dismiss(animation: true);
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(e.toString()),
            );
          },
        );
      });
    }
  }

  void _maybeShowBreakRequestDialog({
    required int remainingBreakMinutes,
    required int breakUsedMinutes,
    required int allowedBreakMinutes,
    required bool canShowDialog,
  }) {
    if (!mounted) return;

    final isBreakExceeded = _isBreakExceeded(
      allowedBreakMinutes: allowedBreakMinutes,
      breakUsedMinutes: breakUsedMinutes,
      remainingBreakMinutes: remainingBreakMinutes,
    );

    if (!canShowDialog || !isBreakExceeded) {
      _breakRequestDialogQueued = false;
      _breakRequestDialogDismissed = false;
      return;
    }

    if (_breakRequestDialogDismissed) {
      return;
    }

    if (_breakRequestDialogQueued || _breakRequestDialogVisible) {
      return;
    }

    _breakRequestDialogQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _breakRequestDialogVisible) {
        return;
      }

      final attendanceList = context.read<DashboardProvider>().attendanceList;
      final checkIn = attendanceList['check-in']?.toString() ?? '-';
      final checkOut = attendanceList['check-out']?.toString() ?? '-';
      final isAttendanceActive = checkIn != '-' && checkOut == '-';
      final isOnBreak = attendanceList['is_on_break'] == true;
      final allowedBreakMinutes =
          _attendanceMinutes(attendanceList, 'allowed_break_time_minutes');
      final breakUsedMinutes =
          _attendanceMinutes(attendanceList, 'break_used_minutes');
      final remainingBreakMinutes =
          _attendanceMinutes(attendanceList, 'remaining_break_time_minutes');
      final isStillBreakExceeded = _isBreakExceeded(
        allowedBreakMinutes: allowedBreakMinutes,
        breakUsedMinutes: breakUsedMinutes,
        remainingBreakMinutes: remainingBreakMinutes,
      );

      if (!(isAttendanceActive || isOnBreak) || !isStillBreakExceeded) {
        _breakRequestDialogQueued = false;
        _breakRequestDialogDismissed = false;
        return;
      }

      _showBreakRequestDialog();
    });
  }

  Future<void> _showBreakRequestDialog() async {
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    setState(() {
      _breakRequestDialogQueued = false;
      _breakRequestDialogVisible = true;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty || reason.length > 500) {
                return;
              }

              setDialogState(() {
                isSubmitting = true;
              });

              try {
                final message = await context
                    .read<DashboardProvider>()
                    .submitBreakRequest(reason);
                if (!mounted) return;
                setState(() {
                  _breakRequestDialogDismissed = true;
                  _breakRequestDialogQueued = false;
                });
                Navigator.of(dialogContext).pop();
                showToast(message);
              } catch (e) {
                setDialogState(() {
                  isSubmitting = false;
                });
                if (!mounted) return;
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      child: CustomAlertDialog(e.toString()),
                    );
                  },
                );
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF10284A),
              title: const Text(
                'Break time exceeded',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter a reason for extending your break and send it for approval.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: reasonController,
                      maxLength: 500,
                      maxLines: 4,
                      enabled: !isSubmitting,
                      onChanged: (_) => setDialogState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Reason',
                        hintStyle: const TextStyle(color: Colors.white54),
                        counterStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          _breakRequestDialogDismissed = true;
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ||
                          reasonController.text.trim().isEmpty ||
                          reasonController.text.trim().length > 500
                      ? null
                      : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send'),
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _breakRequestDialogQueued = false;
        _breakRequestDialogVisible = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceList =
        Provider.of<DashboardProvider>(context).attendanceList;
    final checkIn = attendanceList['check-in']?.toString() ?? '-';
    final checkOut = attendanceList['check-out']?.toString() ?? '-';
    final isAttendanceActive = checkIn != '-' && checkOut == '-';
    final isOnBreak = attendanceList['is_on_break'] == true;
    final productionPercent =
        (attendanceList['production-time'] as num?)?.toDouble() ?? 0.0;
    final productionText =
        attendanceList['production_hour']?.toString() ?? '0 hr 0 min';
    final allowedBreakMinutes =
        (attendanceList['allowed_break_time_minutes'] as num?)?.toInt() ?? 0;
    final breakUsedMinutes =
        (attendanceList['break_used_minutes'] as num?)?.toInt() ?? 0;
    final remainingBreakPercent =
        (attendanceList['remaining_break_time_percent'] as num?)?.toDouble() ??
            0.0;
    final remainingBreakMinutes =
        (attendanceList['remaining_break_time_minutes'] as num?)?.toInt() ?? 0;
    final allowedBreakText = _formatDuration(allowedBreakMinutes);
    final breakUsedText = _formatDuration(breakUsedMinutes);
    final remainingBreakText = _formatDuration(remainingBreakMinutes);
    final isBreakExceeded = _isBreakExceeded(
      allowedBreakMinutes: allowedBreakMinutes,
      breakUsedMinutes: breakUsedMinutes,
      remainingBreakMinutes: remainingBreakMinutes,
    );

    final wasAttendanceActive = _lastCheckIn != '-' && _lastCheckOut == '-';
    final didJustCheckIn = _hasInitializedAttendanceState &&
        !wasAttendanceActive &&
        isAttendanceActive;

    _lastCheckIn = checkIn;
    _lastCheckOut = checkOut;
    _hasInitializedAttendanceState = true;

    final attandanceType = context.watch<PrefProvider>().attendanceType;
    final isAD = context.watch<DashboardProvider>().isAD;
    final animated = context.watch<DashboardProvider>().animated;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: double.infinity,
              child: Center(
                child: Stack(
                  children: [
                    Positioned(
                      top: 5,
                      left: 0,
                      child: DigitalClock(
                          showSeconds: true,
                          isLive: false,
                          textScaleFactor: .9,
                          format: "a",
                          padding: EdgeInsets.symmetric(vertical: 10),
                          digitalClockTextColor: Colors.white,
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          datetime: DateTime.now()),
                    ),
                    DigitalClock(
                        showSeconds: true,
                        isLive: false,
                        textScaleFactor: 2.2,
                        format: "HH:mm",
                        padding: EdgeInsets.symmetric(vertical: 10),
                        digitalClockTextColor: Colors.white,
                        decoration: const BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.rectangle,
                            borderRadius:
                                BorderRadius.all(Radius.circular(15))),
                        datetime: DateTime.now()),
                    Positioned(
                      top: 15,
                      right: 0,
                      child: DigitalClock(
                          showSeconds: true,
                          isLive: false,
                          textScaleFactor: .9,
                          format: "ss",
                          padding: EdgeInsets.zero,
                          digitalClockTextColor: Colors.white,
                          decoration: const BoxDecoration(
                              color: Colors.transparent,
                              shape: BoxShape.rectangle,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(15))),
                          datetime: DateTime.now()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
              child: Text(
            isAD ? formattedDate : nepaliFormattedDate,
            style: TextStyle(color: Colors.white),
          )),
          if (animated)
            Center(
              child: Container(
                width: 280,
                child: RippleWave(
                  color: isAttendanceActive
                      ? HexColor("#762150")
                      : HexColor("#225788"),
                  repeat: animated,
                  waveCount: 5,
                  child: SizedBox(
                    height: 180,
                    width: 180,
                    child: Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(90)),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          color: isAttendanceActive
                              ? HexColor("#762150")
                              : HexColor("#225788"),
                          child: IconButton(
                              iconSize: 70,
                              onPressed: () async {
                                /*Preferences preferences = Preferences();
                            final position = await LocationStatus()
                                .determinePosition(await preferences.getWorkSpace());
                            final value = isWithinRadius(position.latitude, position.longitude, 27.6810411, 85.3340921, 1000);

                            if(value){
                              print("inside");
                            }else{
                              print("outisde");
                            }*/
                                if (attandanceType == "QR") {
                                  scanQr();
                                } else if (attandanceType == "NFC") {
                                  bool isAvailable =
                                      await NfcManager.instance.isAvailable();
                                  if (!isAvailable) {
                                    showToast(
                                        "NFC is not present. Please enable NFC or try different method");
                                    return;
                                  }
                                  showNFCScanner();
                                } else {
                                  showModalBottomSheet(
                                      context: context,
                                      useRootNavigator: true,
                                      isScrollControlled: true,
                                      builder: (context) {
                                        return AttedanceBottomSheet();
                                      });
                                }
                              },
                              icon: Lottie.asset(
                                  attandanceType == "QR"
                                      ? 'assets/raw/qr.json'
                                      : attandanceType == "NFC"
                                          ? 'assets/raw/nfc.json'
                                          : 'assets/raw/fingerprint.json',
                                  width: 60,
                                  height: 60,
                                  repeat: animated)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!animated)
            Center(
              child: SizedBox(
                height: 180,
                width: 180,
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(90)),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: isAttendanceActive
                          ? HexColor("#762150")
                          : HexColor("#225788"),
                      child: IconButton(
                          iconSize: 70,
                          onPressed: () async {
                            /*Preferences preferences = Preferences();
                        final position = await LocationStatus()
                            .determinePosition(await preferences.getWorkSpace());
                        final value = isWithinRadius(position.latitude, position.longitude, 27.6810411, 85.3340921, 1000);

                        if(value){
                          print("inside");
                        }else{
                          print("outisde");
                        }*/
                            if (attandanceType == "QR") {
                              scanQr();
                            } else if (attandanceType == "NFC") {
                              bool isAvailable =
                                  await NfcManager.instance.isAvailable();
                              if (!isAvailable) {
                                showToast(
                                    "NFC is not present. Please enable NFC or try different method");
                                return;
                              }
                              showNFCScanner();
                            } else {
                              showModalBottomSheet(
                                  context: context,
                                  useRootNavigator: true,
                                  isScrollControlled: true,
                                  builder: (context) {
                                    return AttedanceBottomSheet();
                                  });
                            }
                          },
                          icon: Lottie.asset(
                              attandanceType == "QR"
                                  ? 'assets/raw/qr.json'
                                  : attandanceType == "NFC"
                                      ? 'assets/raw/nfc.json'
                                      : 'assets/raw/fingerprint.json',
                              width: 60,
                              height: 60,
                              repeat: animated)),
                    ),
                  ),
                ),
              ),
            ),
          Center(
              child: Text(
            "${safeTranslate('home_screen.check_in')} | ${safeTranslate('home_screen.check_out')}",
            style: TextStyle(color: Colors.white, fontSize: 15),
          )),
          SizedBox(
            height: 15,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Work time',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                productionText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Container(
            width: double.infinity,
            child: LinearPercentIndicator(
              animation: true,
              animationDuration: 1000,
              lineHeight: 24.0,
              padding: EdgeInsets.all(0),
              percent: productionPercent.clamp(0.0, 1.0),
              center: Text(
                '${(productionPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              barRadius: const Radius.circular(20),
              backgroundColor: HexColor("#3dFFFFFF"),
              progressColor: isAttendanceActive
                  ? HexColor("#e82e5f")
                  : HexColor("#3b98cc"),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total break allowed',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                allowedBreakText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Break used',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                breakUsedText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Remaining break time',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                remainingBreakText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Remaining break',
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 6),
          Container(
            width: double.infinity,
            child: LinearPercentIndicator(
              animation: true,
              animationDuration: 1000,
              lineHeight: 16.0,
              padding: EdgeInsets.all(0),
              percent: remainingBreakPercent.clamp(0.0, 1.0),
              center: Text(
                '${(remainingBreakPercent * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.white, fontSize: 11),
              ),
              barRadius: const Radius.circular(20),
              backgroundColor: HexColor("#2dFFFFFF"),
              progressColor: HexColor("#f5a623"),
            ),
          ),
          if ((isAttendanceActive || isOnBreak) && isBreakExceeded)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _breakRequestDialogVisible
                      ? null
                      : () {
                          _breakRequestDialogDismissed = false;
                          _showBreakRequestDialog();
                        },
                  icon: const Icon(Icons.send, size: 16, color: Colors.white),
                  label: const Text(
                    'Send break extension request',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.only(left: 10, right: 10, top: 10),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    checkIn,
                    style: TextStyle(color: Colors.white),
                  ),
                  Text(
                    checkOut,
                    style: TextStyle(color: Colors.white),
                  ),
                ]),
          ),
        ],
      ),
    );
  }

  Future<void> checkAd() async {
    final pref = Provider.of<PrefProvider>(context);
    if (await pref.getIsAd()) {
      formattedDate = DateFormat('EEEE , MMMM d , yyyy').format(DateTime.now());
    } else {
      formattedDate = NepaliDateFormat('EEE , MMMM d , yyyy')
          .format(DateTime.now().toNepaliDateTime());
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    checkAd();
  }
}
