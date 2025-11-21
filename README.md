# calendar_with_callback

[![pub package](https://img.shields.io/pub/v/calendar_with_callback.svg)](https://pub.dev/packages/calendar_with_callback)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A Flutter plugin that opens the native calendar app to add events and returns event information (including event ID) via callback after the user confirms. This provides a better user experience compared to programmatically creating events, as users can review and edit the event details before saving.

## ✨ Features

- ✅ **Native Calendar UI**: Opens the native calendar event editor (similar to `add_2_calendar`)
- ✅ **Event ID Callback**: Returns event ID and calendar ID after user confirms
- ✅ **Cross-Platform**: Supports both iOS and Android
- ✅ **Event Deletion**: Delete events using the returned event ID
- ✅ **Permission Handling**: Automatic permission requests and status checking
- ✅ **Flexible Date Format**: Handles various ISO8601 date formats
- ✅ **All-Day Events**: Support for all-day events
- ✅ **Reminders**: Set reminders (iOS only)
- ✅ **Location & Description**: Full event details support

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  calendar_with_callback:
    git:
      url: https://github.com/yourusername/calendar_with_callback.git
      ref: main
```

Or if published on pub.dev:

```yaml
dependencies:
  calendar_with_callback: ^0.0.1
```

### iOS Setup

Add the following to your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_EVENTS=1',
        'PERMISSION_EVENTS_FULL_ACCESS=1',
      ]
    end
  end
end
```

Then run:

```bash
cd ios && pod install
```

### Android Setup

No additional setup required. Permissions are automatically added.

## 🚀 Usage

### Add Event to Calendar

```dart
import 'package:calendar_with_callback/calendar_with_callback.dart';

// Create an event
final event = CalendarEvent(
  title: 'Team Meeting',
  description: 'Discuss project progress',
  location: 'Conference Room A',
  startDate: DateTime.now().add(Duration(hours: 1)),
  endDate: DateTime.now().add(Duration(hours: 2)),
  allDay: false,
  reminder: Duration(minutes: 30), // iOS only
);

// Add event to calendar
final result = await CalendarWithCallback.addEvent(event);

if (result.success) {
  print('Event added successfully!');
  print('Event ID: ${result.eventId}');
  print('Calendar ID: ${result.calendarId}');
  
  // Save these IDs to your database for later deletion
  await saveEventIds(result.eventId!, result.calendarId!);
} else {
  print('Failed to add event: ${result.errorMessage}');
  // User may have cancelled or permission was denied
}
```

### Delete Event

```dart
// Delete event using saved IDs
final deleted = await CalendarWithCallback.deleteEvent(
  eventId,
  calendarId,
);

if (deleted) {
  print('Event deleted successfully');
} else {
  print('Failed to delete event');
}
```

### Check and Request Permissions

```dart
// Check if permission is granted
final hasPermission = await CalendarWithCallback.hasPermission();

if (!hasPermission) {
  // Request permission
  final granted = await CalendarWithCallback.requestPermission();
  
  if (granted) {
    print('Permission granted');
  } else {
    print('Permission denied');
  }
}
```

### All-Day Event

```dart
final allDayEvent = CalendarEvent(
  title: 'Holiday',
  startDate: DateTime(2025, 12, 25),
  endDate: DateTime(2025, 12, 25),
  allDay: true,
);

final result = await CalendarWithCallback.addEvent(allDayEvent);
```

## 📋 API Reference

### CalendarEvent

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `title` | `String?` | Yes | Event title |
| `description` | `String?` | No | Event description |
| `location` | `String?` | No | Event location |
| `startDate` | `DateTime` | Yes | Event start date/time |
| `endDate` | `DateTime` | Yes | Event end date/time |
| `allDay` | `bool` | No | Whether event is all-day (default: `false`) |
| `reminder` | `Duration?` | No | Reminder duration before event (iOS only) |
| `emailInvites` | `List<String>?` | No | Email addresses to invite (Android only) |

### CalendarEventResult

| Property | Type | Description |
|----------|------|-------------|
| `success` | `bool` | Whether the event was added successfully |
| `eventId` | `String?` | The event ID (for deletion) |
| `calendarId` | `String?` | The calendar ID where event was added |
| `errorMessage` | `String?` | Error message if failed |

### Methods

#### `addEvent(CalendarEvent event)`
Opens the native calendar editor and returns the result after user confirms or cancels.

**Returns:** `Future<CalendarEventResult>`

#### `deleteEvent(String eventId, String calendarId)`
Deletes an event from the calendar.

**Returns:** `Future<bool>`

#### `hasPermission()`
Checks if calendar permission is granted.

**Returns:** `Future<bool>`

#### `requestPermission()`
Requests calendar permission.

**Returns:** `Future<bool>`

## 🔧 Platform Requirements

### Android
- **Minimum SDK**: 21
- **Permissions**: 
  - `READ_CALENDAR`
  - `WRITE_CALENDAR`
  
  These are automatically added to your `AndroidManifest.xml`.

### iOS
- **Minimum iOS**: 13.0
- **Info.plist entries** (automatically added):
  - `NSCalendarsUsageDescription`
  - `NSCalendarsWriteOnlyAccessUsageDescription`

## 🔍 How It Works

### iOS
1. Uses `EKEventEditViewController` to present the native calendar event editor
2. User can review and edit the event details
3. When user saves, the `EKEventEditViewDelegate` callback returns the event ID
4. The event ID and calendar ID are returned to Flutter

### Android
1. Uses `Intent.ACTION_INSERT` to open the native calendar app
2. User can review and edit the event details
3. After user saves, the plugin queries the calendar to find the newly created event
4. The event ID and calendar ID are returned to Flutter

## 🐛 Troubleshooting

### Permission Issues

**iOS**: Make sure you've added the permission keys to `Info.plist`:
```xml
<key>NSCalendarsUsageDescription</key>
<string>This app needs access to your calendar to add events.</string>
<key>NSCalendarsWriteOnlyAccessUsageDescription</key>
<string>This app needs access to your calendar to add events.</string>
```

**Android**: Permissions are automatically added. Make sure your `minSdkVersion` is at least 21.

### Event Not Appearing

- Check if permission is granted
- Verify the event was actually saved (check `result.success`)
- On Android, there might be a slight delay before the event appears

### Date Format Issues

The plugin handles various ISO8601 date formats automatically. If you encounter issues, ensure your `DateTime` objects are valid.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by `add_2_calendar` package
- Built with Flutter

## 📮 Support

If you encounter any issues or have questions, please file an issue on the [GitHub repository](https://github.com/yourusername/calendar_with_callback/issues).

---

Made with ❤️ for the Flutter community
