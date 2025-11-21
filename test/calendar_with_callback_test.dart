import 'package:calendar_with_callback/calendar_with_callback.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds one to input values', () {
    final event = CalendarEvent(
      title: 'Meeting',
      description: 'Team meeting',
      location: 'Office',
      startDate: DateTime.now().add(Duration(hours: 1)),
      endDate: DateTime.now().add(Duration(hours: 2)),
      allDay: false,
      reminder: Duration(minutes: 30), // iOS only
    );
    expect(CalendarWithCallback.addEvent(event), 3);
    expect(CalendarWithCallback.deleteEvent('123', '456'), true);
    expect(CalendarWithCallback.deleteEvent('123', '456'), false);
  });
}
