# FCM Notification Test Script
# Usage: .\test_fcm_notification.ps1

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  FCM Notification Test Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for Server Key
Write-Host "Step 1: Get Server Key" -ForegroundColor Yellow
Write-Host "Go to: Firebase Console > Project Settings > Cloud Messaging" -ForegroundColor Gray
Write-Host "Copy the 'Server key' from Cloud Messaging API (Legacy)" -ForegroundColor Gray
Write-Host ""
$serverKey = Read-Host "Enter your Firebase Server Key"

if ([string]::IsNullOrWhiteSpace($serverKey)) {
    Write-Host "Error: Server key is required!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Get FCM Token" -ForegroundColor Yellow
Write-Host "Run your app and:" -ForegroundColor Gray
Write-Host "1. Look for yellow bug icon in app header" -ForegroundColor Gray
Write-Host "2. Tap bug icon > Copy Token" -ForegroundColor Gray
Write-Host "OR check console logs for 'FCM Token: ...'" -ForegroundColor Gray
Write-Host ""
$fcmToken = Read-Host "Enter the FCM Token"

if ([string]::IsNullOrWhiteSpace($fcmToken)) {
    Write-Host "Error: FCM token is required!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Choose notification type" -ForegroundColor Yellow
Write-Host "1. Simple Notification (title + body only)" -ForegroundColor White
Write-Host "2. Chat Notification (with navigation)" -ForegroundColor White
Write-Host "3. Project Chat Notification (group chat)" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Enter your choice (1-3)"

# Prepare notification payload
$headers = @{
    "Authorization" = "key=$serverKey"
    "Content-Type"  = "application/json"
}

$notification = @{
    title = ""
    body  = ""
}

$data = @{}
$priority = "high"

switch ($choice) {
    "1" {
        # Simple notification
        Write-Host ""
        $notification.title = Read-Host "Enter notification title"
        $notification.body = Read-Host "Enter notification body"
        
        $body = @{
            to           = $fcmToken
            notification = $notification
            priority     = $priority
            android      = @{
                notification = @{
                    channel_id = "chat_channel"
                }
            }
        }
    }
    "2" {
        # Chat notification
        Write-Host ""
        $senderName = Read-Host "Enter sender name"
        $message = Read-Host "Enter message"
        $senderUsername = Read-Host "Enter sender username"
        
        $notification.title = $senderName
        $notification.body = $message
        
        $data = @{
            type              = "chat"
            sender_name       = $senderName
            sender_username   = $senderUsername
            conversation_id   = "123"
            sender_image      = ""
        }
        
        $body = @{
            to           = $fcmToken
            notification = $notification
            data         = $data
            priority     = $priority
            android      = @{
                notification = @{
                    channel_id = "chat_channel"
                }
            }
        }
    }
    "3" {
        # Project chat notification
        Write-Host ""
        $projectName = Read-Host "Enter project name"
        $message = Read-Host "Enter message"
        $projectId = Read-Host "Enter project ID"
        
        $notification.title = "New message in $projectName"
        $notification.body = $message
        
        $data = @{
            type         = "project_chat"
            project_name = $projectName
            project_id   = $projectId
        }
        
        $body = @{
            to           = $fcmToken
            notification = $notification
            data         = $data
            priority     = $priority
            android      = @{
                notification = @{
                    channel_id = "chat_channel"
                }
            }
        }
    }
    default {
        Write-Host "Invalid choice!" -ForegroundColor Red
        exit 1
    }
}

# Convert to JSON
$jsonBody = $body | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "  Sending Notification..." -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Payload:" -ForegroundColor Yellow
Write-Host $jsonBody -ForegroundColor Gray
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "https://fcm.googleapis.com/fcm/send" `
        -Method Post `
        -Headers $headers `
        -Body $jsonBody `
        -ErrorAction Stop
    
    Write-Host "✅ SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Yellow
    $response | ConvertTo-Json -Depth 10 | Write-Host -ForegroundColor Gray
    Write-Host ""
    Write-Host "Check your device for the notification!" -ForegroundColor Green
    Write-Host ""
    
    # Check if message was successful
    if ($response.success -eq 1) {
        Write-Host "Message ID: $($response.results[0].message_id)" -ForegroundColor Green
    } elseif ($response.failure -eq 1) {
        Write-Host "Error: $($response.results[0].error)" -ForegroundColor Red
    }
}
catch {
    Write-Host "❌ ERROR!" -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.ErrorDetails.Message) {
        Write-Host ""
        Write-Host "Details:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# Ask if user wants to send another
$again = Read-Host "Send another notification? (y/n)"
if ($again -eq "y" -or $again -eq "Y") {
    & $MyInvocation.MyCommand.Path
}
