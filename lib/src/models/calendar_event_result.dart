/// Result returned after user adds event to calendar
class CalendarEventResult {
  final bool success;
  final String? eventId; // Calendar event ID (can be used to delete later)
  final String? calendarId; // Calendar ID where event was added
  final String? errorMessage;

  const CalendarEventResult({
    required this.success,
    this.eventId,
    this.calendarId,
    this.errorMessage,
  });

  factory CalendarEventResult.fromJson(Map<String, dynamic> json) {
    return CalendarEventResult(
      success: json['success'] as bool? ?? false,
      eventId: json['eventId'] as String?,
      calendarId: json['calendarId'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'eventId': eventId,
      'calendarId': calendarId,
      'errorMessage': errorMessage,
    };
  }
}

