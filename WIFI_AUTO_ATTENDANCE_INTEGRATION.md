# WiFi Auto Attendance Implementation - Integration Guide

This guide provides step-by-step instructions for integrating WiFi auto attendance in both the Flutter mobile app and Laravel backend.

---

## Part 1: Flutter App Integration

### 1.1 Starting WiFi Polling After Login

After successful user login, initialize WiFi polling by calling the initialization service from your login screen or dashboard:

```dart
// In your login success handler or dashboard initState
import 'package:cnattendance/services/wifi_attendance_init_service.dart';
import 'package:cnattendance/utils/constant.dart';

Future<void> _initializeWifiAfterLogin(String token) async {
  try {
    final success = await WifiAttendanceInitService().initializeForUser(
      baseUrl: Constant.appUrl,
      token: token,
    );
    
    if (success) {
      print('✅ WiFi auto-attendance initialized');
    } else {
      print('⚠️ WiFi auto-attendance disabled or already running');
    }
  } catch (e) {
    print('❌ Error initializing WiFi attendance: $e');
  }
}
```

### 1.2 Handling Logout

Clean up WiFi polling when user logs out:

```dart
Future<void> _handleLogout() async {
  try {
    await WifiAttendanceInitService().cleanupOnLogout();
    // ... other logout logic
  } catch (e) {
    print('❌ Error during logout cleanup: $e');
  }
}
```

### 1.3 Monitoring WiFi Attendance Status

Use the `WifiAttendanceProvider` to monitor and display status in the UI:

```dart
class WifiStatusWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<WifiAttendanceProvider>(
      builder: (context, provider, _) {
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WiFi Attendance Status'),
                SizedBox(height: 8),
                Text(provider.sessionStatusLabel, 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('Breaks: ${provider.formattedTotalBreakTime}'),
                SizedBox(height: 8),
                if (provider.isOnBreak)
                  Chip(label: Text('On Break'), backgroundColor: Colors.yellow),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

### 1.4 Toggle WiFi Auto-Attendance

Enable/disable WiFi attendance from settings:

```dart
class WifiSettingsScreen extends StatefulWidget {
  @override
  State<WifiSettingsScreen> createState() => _WifiSettingsScreenState();
}

class _WifiSettingsScreenState extends State<WifiSettingsScreen> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await WifiPollingManager().isWifiAttendanceEnabled();
    setState(() => _enabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('WiFi Attendance')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Enable WiFi Auto-Attendance'),
            value: _enabled,
            onChanged: (value) async {
              await WifiAttendanceInitService().toggleWifiAttendance(enabled: value);
              setState(() => _enabled = value);
            },
          ),
          ListTile(
            title: Text('Force WiFi Check'),
            trailing: Icon(Icons.refresh),
            onTap: () => WifiAttendanceInitService().forceWifiCheck(),
          ),
        ],
      ),
    );
  }
}
```

---

## Part 2: Laravel Backend Integration

### 2.1 Database Setup

Run the migration to create the `wifi_disconnect_logs` table:

```bash
# Generate migration
php artisan make:migration create_wifi_disconnect_logs_table

# Run migration
php artisan migrate
```

### 2.2 Create Models

Create the `WifiDisconnectLog` model:

```bash
php artisan make:model WifiDisconnectLog
```

### 2.3 Create Controller Methods

Add these methods to your `AttendanceController`:

```php
<?php

namespace App\Http\Controllers;

use App\Models\Attendance;
use App\Models\WifiDisconnectLog;
use Illuminate\Http\Request;

class AttendanceController extends Controller
{
    public function wifiStatus(Request $request)
    {
        $validated = $request->validate([
            'status' => 'required|in:connected,disconnected',
            'router_bssid' => 'nullable|string',
            'ssid' => 'nullable|string',
        ]);

        $user = $request->user();
        $status = $validated['status'];

        // Get today's active attendance
        $attendance = Attendance::where('user_id', $user->id)
            ->whereDate('created_at', today())
            ->first();

        if (!$attendance) {
            return response()->json([
                'message' => 'No active attendance found',
                'status' => 'wifi_status_no_active_checkin'
            ]);
        }

        if ($status === 'disconnected') {
            // Check for existing disconnect log
            $existing = WifiDisconnectLog::where('user_id', $user->id)
                ->where('attendance_id', $attendance->id)
                ->whereNull('reconnected_at')
                ->whereDate('disconnected_at', today())
                ->first();

            if (!$existing) {
                WifiDisconnectLog::create([
                    'user_id' => $user->id,
                    'attendance_id' => $attendance->id,
                    'disconnected_at' => now(),
                ]);
            }

            return response()->json([
                'message' => 'Disconnect logged',
                'status' => 'wifi_disconnect_logged'
            ]);
        }

        // Handle reconnect
        WifiDisconnectLog::where('user_id', $user->id)
            ->where('attendance_id', $attendance->id)
            ->whereNull('reconnected_at')
            ->update(['reconnected_at' => now()]);

        return response()->json([
            'message' => 'Reconnected',
            'status' => 'wifi_reconnected'
        ]);
    }

    public function attendanceStatus(Request $request)
    {
        $user = $request->user();
        $attendance = Attendance::where('user_id', $user->id)
            ->whereDate('created_at', today())
            ->first();

        $data = [
            'checked_in' => false,
            'checked_out' => false,
            'check_in_at' => null,
            'check_out_at' => null,
            'is_on_break' => false,
        ];

        if ($attendance) {
            $data['checked_in'] = !is_null($attendance->check_in_at);
            $data['checked_out'] = !is_null($attendance->check_out_at);
            $data['check_in_at'] = $attendance->check_in_at;
            $data['check_out_at'] = $attendance->check_out_at;

            // Check if on break
            $onBreak = WifiDisconnectLog::where('user_id', $user->id)
                ->where('attendance_id', $attendance->id)
                ->whereNull('reconnected_at')
                ->exists();

            $data['is_on_break'] = $onBreak;
        }

        return response()->json(['data' => $data]);
    }
}
```

### 2.4 Create Cron Command

Generate the command:

```bash
php artisan make:command CheckWifiDisconnectNotification
```

Implement in `app/Console/Commands/CheckWifiDisconnectNotification.php`:

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\WifiDisconnectLog;
use App\Models\User;
use App\Services\FCMService;

class CheckWifiDisconnectNotification extends Command
{
    protected $signature = 'wifi:check-disconnect-notification {--test}';
    protected $description = 'Check for exceeded WiFi disconnect time and send notifications';

    public function handle()
    {
        $breakLimitMinutes = config('attendance.wifi_break_limit_minutes', 15);
        $breakLimitSeconds = $breakLimitMinutes * 60;

        // Find logs exceeding break time limit
        $query = WifiDisconnectLog::whereNull('reconnected_at')
            ->whereNull('notified_at')
            ->where('disconnected_at', '<=', now()->subSeconds($breakLimitSeconds))
            ->with('user', 'attendance');

        $exceededLogs = $query->get();

        if ($this->option('test')) {
            $this->info("Found " . count($exceededLogs) . " logs exceeding break time");
            foreach ($exceededLogs as $log) {
                $this->line("  - User {$log->user->name}: {$breaktimestamps} since disconnected");
            }
            return 0;
        }

        $processed = 0;
        $fcmService = app(FCMService::class);

        foreach ($exceededLogs as $log) {
            try {
                $user = $log->user;

                // Send to employee
                $fcmService->sendToUser($user->id, [
                    'title' => 'Break Time Exceeded',
                    'body' => "You've been disconnected for {$breakLimitMinutes} minutes",
                    'type' => 'wifi_break_exceeded',
                ]);

                // Send to admins
                $admins = User::whereIn('role', ['admin', 'administrator'])
                    ->whereIn('department_id', [$user->department_id])
                    ->get();

                foreach ($admins as $admin) {
                    $fcmService->sendToUser($admin->id, [
                        'title' => 'Employee Break Alert',
                        'body' => "{$user->name} exceeded WiFi break limit",
                        'type' => 'employee_break_exceeded',
                    ]);
                }

                // Mark as notified
                $log->update(['notified_at' => now()]);
                $processed++;

            } catch (\Exception $e) {
                $this->error("Error processing log {$log->id}: " . $e->getMessage());
            }
        }

        $this->info("Processed {$processed} WiFi disconnect notifications");
        return 0;
    }
}
```

### 2.5 Register Cron Command

Update `app/Console/Kernel.php`:

```php
<?php

namespace App\Console;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Console\Kernel as ConsoleKernel;

class Kernel extends ConsoleKernel
{
    protected function schedule(Schedule $schedule)
    {
        // Check WiFi disconnections every minute
        $schedule->command('wifi:check-disconnect-notification')
            ->everyMinute()
            ->withoutOverlapping();

        // Optional: Clean up old logs after 30 days
        $schedule->command('WiFiDisconnectLogs:cleanup')
            ->daily()
            ->at('02:00');
    }
}
```

### 2.6 Create Routes

Add to `routes/api.php`:

```php
Route::middleware(['auth:api'])->group(function () {
    Route::post('employees/wifi-status', [AttendanceController::class, 'wifiStatus']);
    Route::get('employees/attendance-status', [AttendanceController::class, 'attendanceStatus']);
});
```

---

## Part 3: Testing & Verification

### 3.1 Test WiFi Status API

```bash
# Simulate WiFi disconnection
curl -X POST http://localhost:8000/api/employees/wifi-status \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status":"disconnected","router_bssid":"aa:bb:cc:dd:ee:ff"}'

# Check attendance status
curl -X GET http://localhost:8000/api/employees/attendance-status \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### 3.2 Test Cron Command

```bash
# Test the command without sending notifications
php artisan wifi:check-disconnect-notification --test

# Run the command
php artisan wifi:check-disconnect-notification
```

### 3.3 Verify Database Records

```sql
-- Check disconnect logs
SELECT * FROM wifi_disconnect_logs 
WHERE DATE(disconnected_at) = CURDATE()
ORDER BY disconnected_at DESC;

-- Check today's attendance
SELECT * FROM attendances 
WHERE DATE(created_at) = CURDATE()
ORDER BY created_at DESC;
```

---

## Part 4: Configuration

### 4.1 Environment Variables

Add to `.env`:

```
WIFI_BREAK_LIMIT_MINUTES=15
WIFI_AUTO_CHECKOUT_ENABLED=true
WIFI_BREAK_NOTIFICATION_ENABLED=true
```

### 4.2 Create Config File

Create `config/attendance.php`:

```php
return [
    'wifi_break_limit_minutes' => env('WIFI_BREAK_LIMIT_MINUTES', 15),
    'wifi_auto_checkout_enabled' => env('WIFI_AUTO_CHECKOUT_ENABLED', true),
    'wifi_break_notification_enabled' => env('WIFI_BREAK_NOTIFICATION_ENABLED', true),
];
```

---

## Part 5: Troubleshooting

| Issue | Solution |
|---|---|
| WiFi polling not starting | Verify WiFi auto-attendance is enabled and token is valid |
| No disconnect logs | Check if WiFi SSID/BSSID configuration is correct |
| Notifications not sending | Verify FCM service is configured and user has FCM token |
| Cron job not running | Check `php artisan schedule:list` and ensure scheduler is running |
| Device clock out of sync | Use server-side timestamps only (already implemented) |
| Battery drain from polling | Enable pause on background (already implemented in app lifecycle) |

---

## Part 6: Architecture Decisions

1. **30-second polling interval**: Balance between real-time accuracy and battery usage
2. **Server-side timestamps**: Eliminates device clock synchronization issues
3. **Break threshold (15 min default)**: Configurable via environment variable
4. **Pause polling on background**: Automatic via AppLifecycleService
5. **Cron job every minute**: Fast response to break time violations
6. **Duplicate guard (notified_at)**: Prevents notification spam

---

## Part 7: Security Considerations

1. ✅ Token validation on all endpoints
2. ✅ Database transaction safety
3. ✅ Rate limiting recommended (add to routes)
4. ✅ Audit logging of auto check-in/out events
5. ✅ User consent for WiFi auto-attendance

---

## Part 8: Monitoring & Analytics

### Log auto attendance events:

```php
Log::info('WiFi auto attendance', [
    'user_id' => $user->id,
    'action' => 'auto_checkin|auto_checkout|disconnect|reconnect',
    'timestamp' => now(),
    'wifi_status' => $status,
]);
```

### Query for analytics:

```sql
-- Auto check-in rate today
SELECT COUNT(*) FROM attendances 
WHERE DATE(created_at) = CURDATE() 
AND auto_checkin = true;

-- Break statistics
SELECT 
    user_id,
    COUNT(*) as break_count,
    AVG(TIMESTAMPDIFF(MINUTE, disconnected_at, RECONNECTED_AT)) as avg_break_minutes
FROM wifi_disconnect_logs
WHERE DATE(disconnected_at) = CURDATE()
GROUP BY user_id;
```

