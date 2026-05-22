import 'package:cnattendance/model/leave.dart';
import 'package:cnattendance/provider/leaveprovider.dart';
import 'package:cnattendance/utils/navigationservice.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/customalertdialog.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:intl/intl.dart';
import 'package:nepali_date_picker/nepali_date_picker.dart' as picker;
import 'package:nepali_date_picker/nepali_date_picker.dart';
import 'package:provider/provider.dart';

class IssueLeaveSheet extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => IssueLeaveSheetState();
}

class IssueLeaveSheetState extends State<IssueLeaveSheet> {
  Leave? selectedValue;

  bool isLoading = false;

  TextEditingController endDate = TextEditingController();
  TextEditingController reason = TextEditingController();
  TextEditingController startDate = TextEditingController();

  DateTime startNepaliDate = DateTime.now();
  DateTime endNepaliDate = DateTime.now();

  void issueLeave() async {
    if (endDate.text.isNotEmpty &&
        startDate.text.isNotEmpty &&
        reason.text.isNotEmpty &&
        selectedValue != null) {
      // Validate that the selected leave type is valid (exists in the provider's list)
      final provider = Provider.of<LeaveProvider>(context, listen: false);
      final isValidLeaveType =
          provider.leaveList.any((leave) => leave.id == selectedValue!.id);

      if (!isValidLeaveType) {
        NavigationService().showSnackBar("Invalid Leave Type",
            "Please select a valid leave type from the list");
        return;
      }

      // Prevent submitting Time Leave/Early Exit from this sheet
      if (selectedValue!.isEarlyLeave) {
        NavigationService().showSnackBar(
            "Time Leave",
            "Please use the Time Leave option to apply for time-based leave.");
        return;
      }

      try {
        final isAd = await provider.isAd();
        showLoader();
        isLoading = true;

        final response = await provider.issueLeave(
            isAd
                ? startDate.text
                : DateFormat('yyyy-MM-dd hh:mm:ss').format(startNepaliDate),
            isAd
                ? startDate.text
                : DateFormat('yyyy-MM-dd hh:mm:ss').format(startNepaliDate),
            isAd
                ? endDate.text
                : DateFormat('yyyy-MM-dd hh:mm:ss').format(endNepaliDate),
            reason.text,
            selectedValue!.id,
            0);

        if (!mounted) {
          return;
        }
        dismissLoader();
        Navigator.pop(context);
        isLoading = false;
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(response.message),
            );
          },
        );
      } catch (e) {
        dismissLoader();
        isLoading = false;

        String errorMessage = e.toString();
        if (errorMessage.toLowerCase().contains('unauthorized')) {
          errorMessage =
              'Unauthorized: Please check your leave type and try again';
        }

        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: CustomAlertDialog(errorMessage),
            );
          },
        );
      }
    } else {
      String missingField = "";
      if (startDate.text.isEmpty)
        missingField = "Start date";
      else if (endDate.text.isEmpty)
        missingField = "End date";
      else if (reason.text.isEmpty)
        missingField = "Reason";
      else if (selectedValue == null) missingField = "Leave type";

      NavigationService()
          .showSnackBar("Leave Status", "$missingField must not be empty");
    }
  }

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
    final provider = Provider.of<LeaveProvider>(context);

  // Only show regular (non time-leave) types that are enabled
  final availableLeaves = provider.leaveList
    .where((element) => element.status && !element.isEarlyLeave)
    .toList();

    return WillPopScope(
      onWillPop: () async {
        return !isLoading;
      },
      child: Container(
        decoration: RadialDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apply Leave',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.white,
                      )),
                ],
              ),
              Container(
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton2<Leave>(
                      isExpanded: true,
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: const [
                            Icon(
                              Icons.work_outline,
                              size: 18,
                              color: Colors.black54,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Select Leave Type',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      items: availableLeaves.isEmpty
                          ? [
                              DropdownMenuItem<Leave>(
                                value: null,
                                enabled: false,
                                child: Text(
                                  'No leave types available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              )
                            ]
                          : availableLeaves
                              .map((item) => DropdownMenuItem<Leave>(
                                    value: item,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                      selectedItemBuilder: availableLeaves.isEmpty
                          ? null
                          : (BuildContext context) {
                              return availableLeaves.map<Widget>((Leave item) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: Colors.green,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                      value: selectedValue,
                      onChanged: (value) {
                        setState(() {
                          selectedValue = value;
                        });
                      },
                      iconStyleData: IconStyleData(
                        icon: const Icon(
                          Icons.arrow_drop_down,
                        ),
                        iconSize: 24,
                        iconEnabledColor: Colors.black87,
                        iconDisabledColor: Colors.black38,
                      ),
                      buttonStyleData: ButtonStyleData(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          color: Colors.white,
                        ),
                        elevation: 0,
                      ),
                      dropdownStyleData: DropdownStyleData(
                        maxHeight: 250,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        elevation: 8,
                        scrollbarTheme: ScrollbarThemeData(
                          radius: const Radius.circular(40),
                          thickness: WidgetStateProperty.all(6),
                          thumbVisibility: WidgetStateProperty.all(true),
                        ),
                      ),
                      menuItemStyleData: MenuItemStyleData(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  )),
              gaps(10),
              TextField(
                controller: startDate,
                style: TextStyle(color: Colors.white),
                //editing controller of this TextField
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Select Start Date',
                  hintStyle: TextStyle(color: Colors.white),
                  prefixIcon: Icon(Icons.calendar_month, color: Colors.white),
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
                readOnly: true,
                //set it true, so that user will not able to edit text
                onTap: () async {
                  final pickedDate = await provider.isAd()
                      ? await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1950),
                          //DateTime.now() - not to allow to choose before today.
                          lastDate: DateTime(2100))
                      : await picker.showNepaliDatePicker(
                          context: context,
                          initialDate: NepaliDateTime.now(),
                          firstDate: NepaliDateTime(2000),
                          lastDate: NepaliDateTime(2090),
                          initialDatePickerMode: DatePickerMode.day,
                        );

                  if (pickedDate != null) {
                    if (!(await provider.isAd())) {
                      String formattedDate =
                          NepaliDateFormat('yyyy-MM-dd hh:mm:ss')
                              .format((pickedDate as NepaliDateTime));
                      startNepaliDate = (pickedDate).toDateTime();
                      startDate.text = formattedDate;
                    } else {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd hh:mm:ss').format(pickedDate);
                      setState(() {
                        startDate.text =
                            formattedDate; //set output date to TextField value.
                      });
                    }
                  } else {}
                },
              ),
              gaps(10),
              TextField(
                controller: endDate,
                style: TextStyle(color: Colors.white),
                //editing controller of this TextField
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  hintText: 'Select End Date',
                  hintStyle: TextStyle(color: Colors.white),
                  prefixIcon: Icon(Icons.calendar_month, color: Colors.white),
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
                readOnly: true,
                //set it true, so that user will not able to edit text
                onTap: () async {
                  final pickedDate = await provider.isAd()
                      ? await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(1950),
                          //DateTime.now() - not to allow to choose before today.
                          lastDate: DateTime(2100))
                      : await picker.showNepaliDatePicker(
                          context: context,
                          initialDate: NepaliDateTime.now(),
                          firstDate: NepaliDateTime(2000),
                          lastDate: NepaliDateTime(2090),
                          initialDatePickerMode: DatePickerMode.day,
                        );

                  if (pickedDate != null) {
                    print(
                        pickedDate); //pickedDate output format => 2021-03-10 00:00:00.000

                    if (!(await provider.isAd())) {
                      String formattedDate =
                          NepaliDateFormat('yyyy-MM-dd hh:mm:ss')
                              .format((pickedDate as NepaliDateTime));
                      endNepaliDate = (pickedDate).toDateTime();
                      endDate.text = formattedDate;
                    } else {
                      String formattedDate =
                          DateFormat('yyyy-MM-dd hh:mm:ss').format(pickedDate);
                      setState(() {
                        endDate.text =
                            formattedDate; //set output date to TextField value.
                      });
                    }
                  } else {}
                },
              ),
              gaps(10),
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
                  hintText: 'Reason',
                  hintStyle: TextStyle(color: Colors.white),
                  prefixIcon: Icon(Icons.edit_note, color: Colors.white),
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
              gaps(20),
              Container(
                width: MediaQuery.of(context).size.width,
                padding: EdgeInsets.only(left: 5),
                child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: HexColor("#036eb7"),
                      padding: EdgeInsets.zero,
                      shape: ButtonBorder(),
                    ),
                    onPressed: isLoading ? null : () {
                      issueLeave();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Request Leave',
                        style: TextStyle(color: Colors.white),
                      ),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget gaps(double value) {
    return SizedBox(
      height: value,
    );
  }
}
