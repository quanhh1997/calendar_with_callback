/// Model for calendar event data
class CalendarEvent {
  final String? title;
  final String? description;
  final String? location;
  final DateTime startDate;
  final DateTime endDate;
  final bool allDay;
  final Duration? reminder; // iOS only
  final List<String>? emailInvites; // Android only

  const CalendarEvent({
    required this.title,
    this.description,
    this.location,
    required this.startDate,
    required this.endDate,
    this.allDay = false,
    this.reminder,
    this.emailInvites,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'allDay': allDay,
      'reminder': reminder?.inMinutes,
      'emailInvites': emailInvites,
    };
  }
}

