# How to Apply Timeout Fix to All Screens

## ✅ Already Fixed Files
- ✅ `lib/model/auth.dart` - Login
- ✅ `lib/screen/auth/login_screen.dart` - Login screen
- ✅ `lib/services/logout_status_service.dart` - Logout check
- ✅ `lib/provider/dashboardprovider.dart` - Dashboard (GET only)
- ✅ `lib/provider/morescreenprovider.dart` - Logout
- ✅ `lib/provider/supportcontroller.dart` - Support messages

## 📋 Files Still Need Updating

### High Priority (User-facing screens)
1. `lib/provider/leaveprovider.dart` - Leave requests (6 API calls)
2. `lib/provider/profileprovider.dart` - Profile updates (2 API calls)
3. `lib/provider/dashboardprovider.dart` - POST requests (3 remaining)
4. `lib/provider/payslipprovider.dart` - Payslip viewing
5. `lib/provider/payslipdetailprovider.dart` - Payslip details

### Medium Priority (Secondary screens)
6. `lib/provider/holidaycontroller.dart` - Holiday list
7. `lib/provider/meetingcontroller.dart` - Meeting list
8. `lib/provider/noticecontroller.dart` - Notice list
9. `lib/provider/notificationcontroller.dart` - Notifications
10. `lib/provider/leavecalendarcontroller.dart` - Leave calendar (2 calls)
11. `lib/provider/supportlistcontroller.dart` - Support list
12. `lib/provider/employeedetailcontroller.dart` - Employee details
13. `lib/provider/projectdashboardcontroller.dart` - Project dashboard
14. `lib/provider/edittadacontroller.dart` - TA/DA editing (2 calls)

## 🔧 How to Fix Each File

### Step 1: Add Imports
```dart
import 'dart:async';  // Add at top
import 'package:cnattendance/utils/http_client.dart';  // Add this

// Remove or keep http import if used elsewhere
// import 'package:http/http.dart' as http;
```

### Step 2: Replace HTTP Calls

#### GET Request
**Before:**
```dart
final response = await http.get(uri, headers: headers);
```

**After:**
```dart
final response = await TimeoutHttpClient.get(
  uri, 
  headers: headers,
  timeout: Duration(seconds: 30),
);
```

#### POST Request
**Before:**
```dart
final response = await http.post(uri, headers: headers, body: body);
```

**After:**
```dart
final response = await TimeoutHttpClient.post(
  uri, 
  headers: headers, 
  body: body,
  timeout: Duration(seconds: 30),
);
```

### Step 3: Add Timeout Handling

**Before:**
```dart
try {
  final response = await http.get(uri, headers: headers);
  // handle response
} catch (e) {
  // handle error
}
```

**After:**
```dart
try {
  final response = await TimeoutHttpClient.get(uri, headers: headers);
  // handle response
} on TimeoutException {
  // Handle timeout specifically
  showError('Connection timeout. Please check your internet and try again.');
} catch (e) {
  // Handle other errors
  showError(TimeoutHttpClient.getErrorMessage(e));
}
```

### Step 4: Ensure Loading Dismissal

**Always use finally block:**
```dart
try {
  EasyLoading.show(status: 'Loading...');
  final response = await TimeoutHttpClient.get(uri, headers: headers);
  // handle response
} on TimeoutException {
  // handle timeout
} catch (e) {
  // handle error
} finally {
  EasyLoading.dismiss(animation: true);
}
```

## 🚀 Quick Fix Script

For files using GetX (most providers), use this pattern:

```dart
// At top of file
import 'dart:async';
import 'package:cnattendance/utils/http_client.dart';

// In the try-catch block
try {
  EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black);
  
  final response = await TimeoutHttpClient.get(
    uri, 
    headers: headers,
    timeout: Duration(seconds: 30),
  );
  
  // Your existing response handling code
  
} on TimeoutException {
  Get.snackbar(
    'Timeout',
    'Connection timeout. Please check your internet and try again.',
    backgroundColor: Colors.orange,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: Duration(seconds: 4),
  );
} catch (e) {
  Get.snackbar(
    'Error',
    TimeoutHttpClient.getErrorMessage(e),
    backgroundColor: Colors.red,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    duration: Duration(seconds: 4),
  );
} finally {
  EasyLoading.dismiss(animation: true);
}
```

## 📊 Timeout Recommendations by Operation

- **GET requests (list/view)**: 30 seconds
- **POST requests (create/update)**: 30 seconds
- **File uploads**: 120 seconds (2 minutes)
- **File downloads**: 180 seconds (3 minutes)
- **Quick status checks**: 15 seconds

## ✅ Testing Checklist

After updating each file:
1. [ ] Imports added correctly
2. [ ] All http.* calls replaced with TimeoutHttpClient.*
3. [ ] TimeoutException handling added
4. [ ] finally block ensures loading dismissal
5. [ ] User-friendly error messages shown
6. [ ] File compiles without errors
7. [ ] Test with airplane mode (should timeout after 30s)
8. [ ] Test with no internet (should show error immediately)
9. [ ] Test with slow network (should handle gracefully)

## 🎯 Priority Order

Apply fixes in this order for maximum impact:

1. **Login/Auth** ✅ DONE
2. **Dashboard** ✅ DONE (GET), TODO (POST)
3. **Leave Management** - High user interaction
4. **Profile Updates** - Critical user data
5. **Support/Help** ✅ DONE
6. **Payslips** - Financial data (important)
7. **All other screens** - As time permits

## 📝 Bulk Update Script (PowerShell)

```powershell
# Find all providers that need updating
Get-ChildItem "lib\provider\" -Filter "*.dart" -Recurse | 
  Select-String "http\.(get|post|put|delete)" | 
  Select-Object Path -Unique | 
  Format-Table -AutoSize
```

## 🔍 Verification

After updating all files, run:
```bash
flutter analyze
```

Should show no critical errors related to HTTP calls.

## 📚 Reference

See complete examples in:
- `lib/provider/supportcontroller.dart` - GetX pattern with timeout
- `lib/model/auth.dart` - ChangeNotifier pattern with timeout
- `lib/screen/auth/login_screen.dart` - UI error handling with timeout

---
Updated: November 11, 2025
