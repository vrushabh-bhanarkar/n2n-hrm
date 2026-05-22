# WiFi Auto Attendance - Laravel Backend Implementation Guide

This guide provides step-by-step instructions to implement the WiFi status polling system and auto check-in/check-out functionality in the Laravel backend.

---

## 1. Database Schema & Migrations

### 1.1 Create Attendance Check-in/Check-out Fields

If not already present, add these fields to the `attendances` table:

```php
Schema::table('attendances', function (Blueprint $table) {
    $table->boolean('auto_checkin')->default(false)->comment('Auto checked in via WiFi');
    $table->boolean('auto_checkout')->default(false)->comment('Auto checked out via WiFi');
    $table->string('checkin_method')->default('manual')->comment('manual, wifi, nfc, qr, biometric');
    $table->string('checkout_method')->default('manual')->comment('manual, wifi, nfc, qr, biometric');
});
```

### 1.2 Create WiFi Disconnect Logs Table

```php
Schema::create('wifi_disconnect_logs', function (Blueprint $table) {
    $table->id();
    $table->unsignedBigInteger('user_id');
    $table->unsignedBigInteger('attendance_id')->nullable();
    $table->timestamp('disconnected_at');
    $table->timestamp('reconnected_at')->nullable();
    $table->timestamp('notified_at')->nullable()->comment('When break time limit notification was sent');
    $table->string('reason')->nullable();
    $table->timestamps();

    $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
    $table->foreign('attendance_id')->references('id')->on('attendances')->onDelete('set null');
    $table->index(['user_id', 'disconnected_at']);
});
```

### 1.3 Create Router WiFi Configuration Table

If not already present:

```php
Schema::create('router_wifi_networks', function (Blueprint $table) {
    $table->id();
    $table->string('name');
    $table->string('ssid')->nullable();
    $table->string('bssid')->nullable();
    $table->string('router_bssid')->nullable();
    $table->boolean('is_active')->default(true);
    $table->text('description')->nullable();
    $table->timestamps();
});
```

---

## 2. API Endpoints

### 2.1 POST `/api/employees/wifi-status`

**Purpose**: Receive WiFi connection status updates from mobile app

**Controller Method**:

```php
// app/Http/Controllers/AttendanceController.php

public function wifiStatus(Request $request)
{
    $validated = $request->validate([
        'status' => 'required|in:connected,disconnected',
        'router_bssid' => 'nullable|string',
        'ssid' => 'nullable|string',
    ]);

    $user = Auth::user();
    $status = $validated['status'];
    
    // Try to find today's active attendance record
    $attendance = Attendance::where('user_id', $user->id)
        ->whereDate('created_at', today())
        ->first();

    if (!$attendance) {
        return response()->json([
            'message' => 'No active attendance found',
            'status' => 'wifi_status_no_active_checkin'
        ]);
    }

    // If disconnected, log the disconnect event
    if ($status === 'disconnected') {
        // Check if already logged today
        $existingLog = WifiDisconnectLog::where('user_id', $user->id)
            ->where('attendance_id', $attendance->id)
            ->whereNull('reconnected_at')
            ->whereDate('disconnected_at', today())
            ->first();

        if (!$existingLog) {
            WifiDisconnectLog::create([
                'user_id' => $user->id,
                'attendance_id' => $attendance->id,
                'disconnected_at' => now(),
            ]);
            
            return response()->json([
                'message' => 'Disconnect logged',
                'status' => 'wifi_disconnect_logged'
            ]);
        }

        return response()->json([
            'message' => 'Disconnect already logged',
            'status' => 'wifi_disconnect_logged'
        ]);
    }

    // If connected, close any open disconnect logs
    WifiDisconnectLog::where('user_id', $user->id)
        ->where('attendance_id', $attendance->id)
        ->whereNull('reconnected_at')
        ->update(['reconnected_at' => now()]);

    return response()->json([
        'message' => 'Reconnected',
        'status' => 'wifi_reconnected'
    ]);
}
```

### 2.2 GET `/api/employees/attendance-status`

**Purpose**: Get current attendance status for the employee

**Controller Method**:

```php
public function attendanceStatus(Request $request)
{
    $user = Auth::user();
    
    $attendance = Attendance::where('user_id', $user->id)
        ->whereDate('created_at', today())
        ->first();

    $data = [
        'checked_in' => false,
        'checked_out' => false,
        'check_in_at' => null,
        'check_out_at' => null,
        'is_on_break' => false,
        'attendance_id' => null,
    ];

    if ($attendance) {
        $data['checked_in'] = !is_null($attendance->check_in_at);
        $data['check_in_at'] = $attendance->check_in_at;
        $data['check_out_at'] = $attendance->check_out_at;
        $data['checked_out'] = !is_null($attendance->check_out_at);
        $data['attendance_id'] = $attendance->id;
        
        // Check if on break (disconnected but not checked out yet)
        $latestDisconnect = WifiDisconnectLog::where('user_id', $user->id)
            ->where('attendance_id', $attendance->id)
            ->whereNull('reconnected_at')
            ->latest('disconnected_at')
            ->first();
            
        $data['is_on_break'] = !is_null($latestDisconnect);
    }

    return response()->json([
        'data' => $data
    ]);
}
```

### 2.3 POST `/api/employees/check-in` (Enhanced)

**Purpose**: Handle auto check-in requests

**Controller Updates**:

```php
public function checkIn(Request $request)
{
    $validated = $request->validate([
        'latitude' => 'required|numeric',
        'longitude' => 'required|numeric',
        'auto_checkin' => 'boolean',
    ]);

    $user = Auth::user();
    $isAutoCheckin = $request->boolean('auto_checkin', false);

    // Check if already checked in today
    $existing = Attendance::where('user_id', $user->id)
        ->whereDate('created_at', today())
        ->first();

    if ($existing && $existing->check_in_at) {
        return response()->json([
            'message' => 'Already checked in',
            'attendance' => $existing
        ], 200);
    }

    $attendance = Attendance::create([
        'user_id' => $user->id,
        'check_in_at' => now(),
        'latitude' => $validated['latitude'],
        'longitude' => $validated['longitude'],
        'auto_checkin' => $isAutoCheckin,
        'checkin_method' => $isAutoCheckin ? 'wifi' : 'manual',
    ]);

    return response()->json([
        'message' => 'Checked in successfully',
        'attendance' => $attendance
    ]);
}
```

### 2.4 POST `/api/employees/check-out` (Enhanced)

**Purpose**: Handle auto check-out requests

**Controller Updates**:

```php
public function checkOut(Request $request)
{
    $validated = $request->validate([
        'latitude' => 'required|numeric',
        'longitude' => 'required|numeric',
        'auto_checkout' => 'boolean',
        'break_reason' => 'nullable|string',
    ]);

    $user = Auth::user();
    $isAutoCheckout = $request->boolean('auto_checkout', false);

    $attendance = Attendance::where('user_id', $user->id)
        ->whereDate('created_at', today())
        ->whereNull('check_out_at')
        ->first();

    if (!$attendance) {
        return response()->json([
            'message' => 'No active attendance found',
        ], 422);
    }

    $attendance->update([
        'check_out_at' => now(),
        'latitude_out' => $validated['latitude'],
        'longitude_out' => $validated['longitude'],
        'auto_checkout' => $isAutoCheckout,
        'checkout_method' => $isAutoCheckout ? 'wifi' : 'manual',
    ]);

    // Close any open disconnect logs
    WifiDisconnectLog::where('user_id', $user->id)
        ->where('attendance_id', $attendance->id)
        ->whereNull('reconnected_at')
        ->update(['reconnected_at' => now()]);

    return response()->json([
        'message' => 'Checked out successfully',
        'attendance' => $attendance
    ]);
}
```

---

## 3. Scheduled Commands (Cron Jobs)

### 3.1 Create CheckWifiDisconnectNotification Command

```bash
php artisan make:command CheckWifiDisconnectNotification
```

**Implementation** (`app/Console/Commands/CheckWifiDisconnectNotification.php`):

```php
<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\WifiDisconnectLog;
use App\Models\User;
use App\Services\FCMService;

class CheckWifiDisconnectNotification extends Command
{
    protected $signature = 'wifi:check-disconnect-notification';
    protected $description = 'Check for exceeded WiFi disconnect time and send notifications';

    public function handle()
    {
        $breakLimitMinutes = config('attendance.wifi_break_limit_minutes', 15);
        $breakLimitSeconds = $breakLimitMinutes * 60;

        // Find logs that have exceeded the break time limit
        $exceededLogs = WifiDisconnectLog::whereNull('reconnected_at')
            ->whereNull('notified_at')
            ->where('disconnected_at', '<=', now()->subSeconds($breakLimitSeconds))
            ->with('user', 'attendance')
            ->get();

        $fcmService = app(FCMService::class);

        foreach ($exceededLogs as $log) {
            try {
                $user = $log->user;

                // Send notification to employee
                $fcmService->sendToUser($user->id, [
                    'title' => 'Break Time Exceeded',
                    'body' => "You've been disconnected from office WiFi for {$breakLimitMinutes} minutes",
                    'type' => 'wifi_break_exceeded',
                    'data' => [
                        'disconnect_log_id' => $log->id,
                        'disconnected_at' => $log->disconnected_at->toIso8601String(),
                    ]
                ]);

                // Send notification to admins
                $admins = User::whereIn('role', ['admin', 'administrator'])
                    ->whereIn('department_id', $user->department_id ?? [])
                    ->get();

                foreach ($admins as $admin) {
                    $fcmService->sendToUser($admin->id, [
                        'title' => 'Employee Break Time Alert',
                        'body' => "{$user->name} has exceeded the WiFi break time limit",
                        'type' => 'employee_break_exceeded',
                        'data' => [
                            'user_id' => $user->id,
                            'user_name' => $user->name,
                            'disconnect_log_id' => $log->id,
                        ]
                    ]);
                }

                // Mark as notified
                $log->update(['notified_at' => now()]);

                $this->info("Notification sent for user {$user->name}");

            } catch (\Exception $e) {
                $this->error("Error processing disconnect log {$log->id}: " . $e->getMessage());
            }
        }

        $this->info("Processed " . count($exceededLogs) . " exceeded WiFi disconnect logs");
    }
}
```

### 3.2 Register Command in Schedule

Update `app/Console/Kernel.php`:

```php
protected function schedule(Schedule $schedule)
{
    // Check WiFi disconnect notifications every minute
    $schedule->command('wifi:check-disconnect-notification')->everyMinute();

    // Cleanup old disconnect logs (optional, after 30 days)
    $schedule->command('wifi:cleanup-old-logs')->daily()->at('02:00');
}
```

---

## 4. Models

### 4.1 WifiDisconnectLog Model

```php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class WifiDisconnectLog extends Model
{
    protected $table = 'wifi_disconnect_logs';

    protected $fillable = [
        'user_id',
        'attendance_id',
        'disconnected_at',
        'reconnected_at',
        'notified_at',
        'reason',
    ];

    protected $casts = [
        'disconnected_at' => 'datetime',
        'reconnected_at' => 'datetime',
        'notified_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function attendance(): BelongsTo
    {
        return $this->belongsTo(Attendance::class);
    }

    public function getDurationMinutesAttribute(): int
    {
        $end = $this->reconnected_at ?? now();
        return $this->disconnected_at->diffInMinutes($end);
    }
}
```

### 4.2 Update Attendance Model

```php
class Attendance extends Model
{
    protected $fillable = [
        // ... existing fields ...
        'auto_checkin',
        'auto_checkout',
        'checkin_method',
        'checkout_method',
    ];

    public function wifiDisconnectLogs()
    {
        return $this->hasMany(WifiDisconnectLog::class);
    }
}
```

---

## 5. Configuration

Create `config/attendance.php`:

```php
return [
    'wifi_break_limit_minutes' => env('WIFI_BREAK_LIMIT_MINUTES', 15),
    'wifi_break_notification_enabled' => env('WIFI_BREAK_NOTIFICATION_ENABLED', true),
    'auto_checkout_enabled' => env('WIFI_AUTO_CHECKOUT_ENABLED', true),
];
```

---

## 6. Routes

Add to `routes/api.php`:

```php
Route::middleware(['auth:api'])->group(function () {
    // WiFi Status
    Route::post('employees/wifi-status', [AttendanceController::class, 'wifiStatus']);
    Route::get('employees/attendance-status', [AttendanceController::class, 'attendanceStatus']);
    
    // Enhanced Check-in/Check-out
    Route::post('employees/check-in', [AttendanceController::class, 'checkIn']);
    Route::post('employees/check-out', [AttendanceController::class, 'checkOut']);
});
```

---

## 7. Key Design Decisions

| Decision | Reason |
|---|---|
| **Polling instead of events** | Mobile OS WiFi events are unreliable; polling is consistent |
| **Server-side timestamps** | No reliance on device clock accuracy |
| **Duplicate guard on disconnect** | Prevents DB flooding from repeated 30s polls |
| **Break threshold before checkout** | Allows flexible break management before forced checkout |
| **Notified flag** | Prevents re-sending same notification every minute |
| **Soft delete for logs** | Maintains audit trail while cleaning up display |

---

## 8. Testing

### Manual API Testing with cURL

```bash
# Test WiFi status - disconnected
curl -X POST http://localhost:8000/api/employees/wifi-status \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"status":"disconnected","router_bssid":"aa:bb:cc:dd:ee:ff","ssid":"OfficeWiFi"}'

# Test WiFi status - connected
curl -X POST http://localhost:8000/api/employees/wifi-status \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{"status":"connected","router_bssid":"aa:bb:cc:dd:ee:ff","ssid":"OfficeWiFi"}'

# Get attendance status
curl -X GET http://localhost:8000/api/employees/attendance-status \
  -H "Authorization: Bearer {token}"
```

### Database Queries for Verification

```sql
-- Check disconnect logs for a user
SELECT * FROM wifi_disconnect_logs 
WHERE user_id = 1 
ORDER BY disconnected_at DESC;

-- Check today's attendance
SELECT * FROM attendances 
WHERE user_id = 1 
AND DATE(created_at) = CURDATE();

-- Check pending notifications
SELECT * FROM wifi_disconnect_logs 
WHERE notified_at IS NULL 
AND reconnected_at IS NULL;
```

---

## 9. Troubleshooting

| Issue | Solution |
|---|---|
| No check-in/check-out happening | Verify WiFi SSID/BSSID is configured in router_wifi_networks |
| Notifications not sending | Check FCM service is configured and user has FCM tokens |
| Break logs not appearing | Ensure cron job is running: `php artisan schedule:work` |
| Duplicate disconnect logs | Run migration to add unique constraint or check app logic |
| API returning 404 | Verify route is registered and controller method exists |

