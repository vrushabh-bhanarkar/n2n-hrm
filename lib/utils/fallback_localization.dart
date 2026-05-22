import 'package:flutter_translate/flutter_translate.dart';

/// Safe translate function that falls back to English if translations aren't initialized
/// Use this instead of translate() when in fallback mode
String safeTranslate(String key, {Map<String, String>? namedParameters}) {
  try {
    // Try to use flutter_translate's translate function
    return translate(key);
  } catch (e) {
    // If translate fails (e.g., LateInitializationError, or no LocalizedApp context),
    // fall back to English translations
    // Remove any nested keys and just get the base key
    String baseKey = key.split('.').last.toLowerCase();
    String fallback = fallbackTranslations[baseKey] ?? key;

    // If we have named parameters, do simple replacement
    if (namedParameters != null && namedParameters.isNotEmpty) {
      namedParameters.forEach((paramKey, paramValue) {
        fallback = fallback.replaceAll('{$paramKey}', paramValue);
      });
    }

    return fallback;
  }
}

/// Global fallback translations map for when localization is not initialized
/// This will be used by safeTranslate() calls when flutter_translate fails
final Map<String, String> fallbackTranslations = {
  // Common UI strings
  'email': 'Email',
  'password': 'Password',
  'login': 'Login',
  'logout': 'Logout',
  'submit': 'Submit',
  'cancel': 'Cancel',
  'save': 'Save',
  'delete': 'Delete',
  'edit': 'Edit',
  'home': 'Home',
  'settings': 'Settings',
  'profile': 'Profile',
  'dashboard': 'Dashboard',
  'attendance': 'Attendance',
  'error': 'Error',
  'success': 'Success',
  'loading': 'Loading',
  'no_data': 'No data available',
  'please_enter_email': 'Please enter email',
  'please_enter_password': 'Please enter password',
  'invalid_email': 'Invalid email',
  'invalid_password': 'Invalid password',
  'login_failed': 'Login failed',
  'welcome': 'Welcome',
  'name': 'Name',
  'date': 'Date',
  'time': 'Time',
  'status': 'Status',
  'present': 'Present',
  'absent': 'Absent',
  'leave': 'Leave',
  'reports': 'Reports',
  'logout_pending': 'Logout Pending',
  'confirm': 'Confirm',
  'ok': 'OK',
  'yes': 'Yes',
  'no': 'No',
  'hello_there': 'Hello there',
  'check_in': 'Check In',
  'check_out': 'Check Out',
  'my_team': 'My Team',
  'view_all': 'View All',
  'show_all': 'Show All',
  'overview': 'Overview',
  'holidays': 'Holidays',
  'event': 'Event',
  'projects': 'Projects',
  'task': 'Task',
  'awards': 'Awards',
  'training': 'Training',
  'office_events': 'Office Events',
  'weekly': 'Weekly',
  'sun': 'Sun',
  'mon': 'Mon',
  'tue': 'Tue',
  'wed': 'Wed',
  'thu': 'Thu',
  'fri': 'Fri',
  'sat': 'Sat',
  'upcoming_holiday': 'Upcoming Holiday',
  'recent_award': 'Recent Award',
  // Loader/Loading messages
  'signing_in': 'Signing in...',
  'requesting': 'Requesting...',
  // Welcome/Login screen specific
  'skip': 'Skip',
  'verify_button': 'Verify',
  'username': 'Username',
  'forget_password': 'Forget Password?',
  'go_back': 'Go Back',
  // Common messages
  'note': 'Note',
  'edit_profile': 'Edit Profile',
  'job_position': 'Job Position',
  'branch': 'Branch',
  'department': 'Department',
  'employment_type': 'Employment Type',
  'joined_date': 'Joined Date',
  'select_language': 'Select Language',
  'phone_number': 'Phone Number',
  'dob': 'Date of Birth',
  'gender': 'Gender',
  'address': 'Address',
  'bank_name': 'Bank Name',
  'account_number': 'Account Number',
  'account_type': 'Account Type',
  'attendance_summary': 'Attendance Summary',
  'attendance_history': 'Attendance History',
  'present_days': 'Present Days',
  'day': 'Day',
  'start_time': 'Start Time',
  'end_time': 'End Time',
  'worked_hours': 'Worked Hours',
  'overtime': 'Overtime',
  'undertime': 'Undertime',
  'venue': 'Venue',
  'log_out': 'Log Out',
  'more': 'More',
};
