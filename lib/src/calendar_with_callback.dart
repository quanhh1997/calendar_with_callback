import 'dart:async';
import 'package:flutter/services.dart';

import 'models/calendar_event.dart';
import 'models/calendar_event_result.dart';

/// Main class for adding events to calendar with callback
class CalendarWithCallback {
  static const MethodChannel _channel =
      MethodChannel('calendar_with_callback');

  /// Add event to calendar
  /// Opens the calendar app and returns result after user confirms/cancels
  /// 
  /// Returns [CalendarEventResult] with eventId if user confirmed,
  /// or success=false if user cancelled
  static Future<CalendarEventResult> addEvent(CalendarEvent event) async {
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>(
        'addEvent',
        event.toJson(),
      );

      if (result == null) {
        return const CalendarEventResult(
          success: false,
          errorMessage: 'No result returned from platform',
        );
      }

      return CalendarEventResult.fromJson(
        Map<String, dynamic>.from(result),
      );
    } on PlatformException catch (e) {
      return CalendarEventResult(
        success: false,
        errorMessage: e.message ?? 'Platform error: ${e.code}',
      );
    } catch (e) {
      return CalendarEventResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Delete event from calendar using eventId
  static Future<bool> deleteEvent(String eventId, String calendarId) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'deleteEvent',
        {
          'eventId': eventId,
          'calendarId': calendarId,
        },
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if calendar permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request calendar permission
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}

