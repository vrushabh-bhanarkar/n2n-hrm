import 'package:cnattendance/model/month.dart';
import 'package:cnattendance/provider/payslipprovider.dart';
import 'package:cnattendance/screen/profile/payslipdetailscreen.dart';
import 'package:cnattendance/widget/buttonborder.dart';
import 'package:cnattendance/widget/radialDecoration.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:provider/provider.dart';

class PaySlipScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => PaySlipScreenState();
}

class PaySlipScreenState extends State<PaySlipScreen> {
  bool showAll = true;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    if (!_isInitialized) {
      context.read<PaySlipProvider>().getBS();

      if (showAll) {
        // Schedule the async operation after the build phase completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          getAllValues();
        });
      }

      _isInitialized = true;
    }
    super.didChangeDependencies();
  }

  Future<void> getAllValues() async {
    try {
      await context.read<PaySlipProvider>().getPaySlipData(null, null);
    } catch (error) {
      print('❌ Error loading all payslips: $error');
      // Show error to user if context is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load payslips: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void clearPaySlip() async {
    context.read<PaySlipProvider>().clearPaySlip();
  }

  @override
  Widget build(BuildContext context) {
    final month = context.watch<PaySlipProvider>().month;
    final year = context.watch<PaySlipProvider>().year;

    var selectedMonth = context.watch<PaySlipProvider>().selectedMonth;
    var selectedYear = context.watch<PaySlipProvider>().selectedYear;
    return Container(
      decoration: RadialDecoration(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(translate('payslip_screen.payslip'),
              style: TextStyle(color: Colors.white)),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: [
                      Text(
                        "Show All",
                        style: TextStyle(color: Colors.white),
                      ),
                      Spacer(),
                      Switch(
                        activeThumbColor: Colors.blueAccent,
                        padding: EdgeInsets.zero,
                        value: showAll,
                        onChanged: (value) {
                          showAll = value;
                          setState(() {});
                          if (value) {
                            getAllValues();
                          } else {
                            clearPaySlip();
                          }
                        },
                      )
                    ],
                  ),
                ),
                if (!showAll)
                  Card(
                    shape: ButtonBorder(),
                    margin: EdgeInsets.zero,
                    color: HexColor("#20FFFFFF"),
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 5,
                          ),
                          Row(
                            children: [
                              Consumer(
                                builder: (context, value, child) {
                                  return year.isEmpty
                                      ? SizedBox.shrink()
                                      : Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2(
                                              isExpanded: true,
                                              items: (year)
                                                  .map((item) =>
                                                      DropdownMenuItem<int>(
                                                        value: item,
                                                        child: Text(
                                                          item.toString(),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ))
                                                  .toList(),
                                              value: selectedYear,
                                              onChanged: (value) {
                                                setState(() {
                                                  print(value);
                                                  context
                                                          .read<PaySlipProvider>()
                                                          .selectedYear =
                                                      value as int;
                                                });
                                              },
                                              iconStyleData: IconStyleData(
                                                icon: const Icon(
                                                  Icons
                                                      .arrow_forward_ios_outlined,
                                                ),
                                                iconSize: 14,
                                                iconEnabledColor: Colors.black,
                                                iconDisabledColor: Colors.grey,
                                              ),
                                              buttonStyleData: ButtonStyleData(
                                                height: 50,
                                                width: 160,
                                                padding: const EdgeInsets.only(
                                                    left: 14, right: 14),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                          topLeft: Radius
                                                              .circular(10),
                                                          topRight:
                                                              Radius.circular(
                                                                  0),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  0),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  10)),
                                                  color: HexColor("#FFFFFF"),
                                                ),
                                                elevation: 0,
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 200,
                                                padding: null,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                          topLeft: Radius
                                                              .circular(0),
                                                          topRight:
                                                              Radius.circular(
                                                                  10),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  10),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  10)),
                                                  color: HexColor("#FFFFFF"),
                                                ),
                                                elevation: 8,
                                              ),
                                              menuItemStyleData:
                                                  MenuItemStyleData(
                                                height: 40,
                                                padding: const EdgeInsets.only(
                                                    left: 14, right: 14),
                                              ),
                                            ),
                                          ),
                                        );
                                },
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Consumer(
                                builder: (context, value, child) {
                                  return month.isEmpty
                                      ? SizedBox.shrink()
                                      : Expanded(
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton2(
                                              isExpanded: true,
                                              items: (month)
                                                  .map((item) =>
                                                      DropdownMenuItem<Month>(
                                                        value: item,
                                                        child: Text(
                                                          item.name,
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ))
                                                  .toList(),
                                              value: month[selectedMonth],
                                              onChanged: (value) {
                                                print((value as Month).index);
                                                setState(() {
                                                  context
                                                          .read<PaySlipProvider>()
                                                          .selectedMonth =
                                                      (value).index;
                                                });
                                              },
                                              iconStyleData: IconStyleData(
                                                icon: const Icon(
                                                  Icons
                                                      .arrow_forward_ios_outlined,
                                                ),
                                                iconSize: 14,
                                                iconEnabledColor: Colors.black,
                                                iconDisabledColor: Colors.grey,
                                              ),
                                              buttonStyleData: ButtonStyleData(
                                                height: 50,
                                                width: 160,
                                                padding: const EdgeInsets.only(
                                                    left: 14, right: 14),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                          topLeft: Radius
                                                              .circular(10),
                                                          topRight:
                                                              Radius.circular(
                                                                  0),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  0),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  10)),
                                                  color: HexColor("#FFFFFF"),
                                                ),
                                                elevation: 0,
                                              ),
                                              dropdownStyleData:
                                                  DropdownStyleData(
                                                maxHeight: 200,
                                                padding: null,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.only(
                                                          topLeft: Radius
                                                              .circular(0),
                                                          topRight:
                                                              Radius.circular(
                                                                  10),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                  10),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  10)),
                                                  color: HexColor("#FFFFFF"),
                                                ),
                                                elevation: 8,
                                              ),
                                              menuItemStyleData:
                                                  MenuItemStyleData(
                                                height: 40,
                                                padding: const EdgeInsets.only(
                                                    left: 14, right: 14),
                                              ),
                                            ),
                                          ),
                                        );
                                },
                              ),
                            ],
                          ),
                          SizedBox(
                            height: 10,
                          ),
                          TextButton(
                              style: TextButton.styleFrom(
                                  backgroundColor: HexColor("#036eb7"),
                                  shape: ButtonBorder()),
                              onPressed: () async {
                                try {
                                  setState(() {
                                    EasyLoading.show(
                                        status: "Loading",
                                        maskType: EasyLoadingMaskType.black);
                                  });
                                  await context
                                      .read<PaySlipProvider>()
                                      .getPaySlipData(
                                          selectedYear, selectedMonth + 1);
                                  setState(() {
                                    EasyLoading.dismiss(animation: true);
                                  });
                                } catch (error) {
                                  setState(() {
                                    EasyLoading.dismiss(animation: true);
                                  });
                                  // Show error to user
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error.toString()),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(2.0),
                                child: Center(
                                  child: Text(
                                    translate('payslip_screen.request_payslip'),
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ))
                        ],
                      ),
                    ),
                  ),
                if (!showAll &&
                    context.watch<PaySlipProvider>().payslips.isNotEmpty)
                  SizedBox(
                    height: 10,
                  ),
                if (!showAll &&
                    context.watch<PaySlipProvider>().payslips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Text(
                      translate('payslip_screen.result'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                // Show message when no payslips found
                if (!showAll &&
                    context.watch<PaySlipProvider>().payslips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No payslips found',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Select a month and year to search for payslips',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ListView.builder(
                  primary: false,
                  shrinkWrap: true,
                  itemCount: context.watch<PaySlipProvider>().payslips.length,
                  itemBuilder: (context, index) {
                    final payslip =
                        context.read<PaySlipProvider>().payslips[index];
                    return InkWell(
                      onTap: () {
                        Navigator.of(context).pushNamed(
                            PaySlipDetailScreen.routeName,
                            arguments: payslip.id);
                      },
                      child: Card(
                        shape: ButtonBorder(),
                        margin: EdgeInsets.symmetric(vertical: 10),
                        color: Colors.white12,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      payslip.payslip_id,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 18),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Card(
                                            margin: EdgeInsets.zero,
                                            color: Colors.green,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8.0,
                                                      vertical: 2),
                                              child: Text(
                                                payslip.salary_cycle,
                                                style: TextStyle(
                                                    color: Colors.white),
                                              ),
                                            )),
                                        SizedBox(width: 8),
                                        InkWell(
                                          onTap: () {
                                            Navigator.of(context).pushNamed(
                                                PaySlipDetailScreen.routeName,
                                                arguments: payslip.id);
                                          },
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.picture_as_pdf,
                                                    color: Colors.white,
                                                    size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'PDF',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 10,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  children: [
                                    Text(
                                      payslip.duration,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    Spacer(),
                                    Text(
                                      payslip.salary_from,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      " - ",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    Text(
                                      payslip.salary_to,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5.0),
                                child: Divider(
                                  indent: 10,
                                  endIndent: 10,
                                  color: Colors.white54,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      translate('common.total'),
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 18),
                                    ),
                                    Text(
                                      context
                                              .watch<PaySlipProvider>()
                                              .currency +
                                          " " +
                                          payslip.net_salary,
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontFamily: "",
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Show message when "Show All" is enabled but no payslips exist
                if (showAll &&
                    context.watch<PaySlipProvider>().payslips.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 80,
                            color: Colors.white54,
                          ),
                          SizedBox(height: 20),
                          Text(
                            'No payslips available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 40.0),
                            child: Text(
                              'No payslips have been generated for your account yet. Please contact HR or administration.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
