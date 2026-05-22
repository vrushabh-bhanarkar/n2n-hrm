# Prompt for AI Assistant to Apply Similar Fixes

Copy and paste this prompt to an AI assistant when working on another Flutter app that needs similar fixes:

---

## Prompt Start

I need help fixing several issues in my Flutter app with Firebase Cloud Messaging (FCM) notifications and API operations. Please implement the following fixes:

### 1. Fix Notification Navigation When App is Killed/Terminated

**Problem**: When the app is completely killed and user taps a notification, it doesn't navigate to the correct screen. The navigation works fine when app is in foreground or background, but fails when terminated.

**Required Fix**: 
- Implement deferred notification handling pattern
- In NotificationService, capture the initial message from `FirebaseMessaging.instance.getInitialMessage()` but don't process it immediately
- Store it in a `_pendingInitialMessage` field
- Add a `processPendingNotification()` method that should be called AFTER user authentication is complete
- Ensure the notification data payload is parsed correctly and navigation happens based on the `type` field in the data
- The backend sends notification data like `{type: 'chat', conversation_id: '123'}` - use this to route to appropriate screens

Please update:
1. `lib/services/notification_service.dart` - Add pending message handling
2. `lib/services/fcm_service.dart` - Ensure background handler is set up correctly
3. Main app initialization - Call `processPendingNotification()` after authentication
4. Show me where to add the navigation logic based on notification type

### 2. Fix Delete API Endpoint Method

**Problem**: Delete operations are failing with HTML 404 responses instead of JSON. The backend expects POST method but the app is using GET.

**Required Fix**:
- Find all delete operations in repository files (search for "delete" methods)
- Change HTTP method from `getResponse()` to `postResponse()` 
- Pass empty body `{}` as the third parameter
- Add proper error handling for HTML responses
- Add user confirmation dialogs before delete operations
- Show success/error toast messages

Please update repository methods that perform delete operations and ensure they use POST method.

### 3. Fix List Not Refreshing After Create/Update

**Problem**: After creating a new item (complaint, TADA, etc.), the user has to manually pull-to-refresh to see the new item in the list. The list should auto-refresh when returning from the create screen.

**Required Fix**:
- In create/edit screens: Use `Get.back(result: true)` to return a success flag when operation succeeds
- In list screens: When navigating to create screen, add `.then((value) { if (value == true) { reset page to 1; refresh list } })`
- When returning from detail screen: Always refresh the list
- Ensure pull-to-refresh still works manually

Please find screens with:
- FloatingActionButton that opens create screens
- List items that navigate to detail screens
- Apply the refresh pattern to all of them

### 4. Handle Backend 500 Errors Gracefully

**Problem**: Backend sometimes returns 500 status with error message "Attempt to read property id on null" but the operation actually succeeds (data is saved). Users see error message even though it worked.

**Required Fix**:
- In repository methods, detect when response is 500 AND message contains specific error text
- Treat these known backend bugs as successful operations
- Replace the confusing error message with "Operation completed successfully" or similar
- Still return success (true) to the caller

Example pattern:
```dart
final isKnownBackendBug = response.statusCode == 500 && 
    message.toLowerCase().contains('attempt to read property "id"');
final friendlyMessage = isKnownBackendBug ? "Submitted successfully" : message;
if (response.statusCode == 200 || isKnownBackendBug) {
  return (true, friendlyMessage);
}
```

### 5. Improve User Feedback

**Required Fix**:
- All operations should show loading spinner using EasyLoading
- All operations should show toast/snackbar on success or failure
- Add confirmation dialogs for destructive actions (delete)
- Ensure loading states are dismissed even if operation fails

### Additional Context

- App uses GetX for state management
- Repository classes handle API calls using `Connect()` helper
- Controllers call repository methods and update UI
- Firebase Messaging is already set up, just needs proper handling
- The app structure has: lib/repositories/, lib/services/, lib/screen/, lib/provider/ (controllers)

Please analyze the codebase, find the relevant files, and implement these fixes. Show me the changes you're making and explain any important decisions.

## Prompt End

---

**Usage Instructions:**
1. Copy everything between "Prompt Start" and "Prompt End"
2. Paste it when starting a new chat with an AI assistant
3. The AI will search your codebase and implement the fixes
4. Review and test the changes before committing
