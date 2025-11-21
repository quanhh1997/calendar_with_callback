import 'dart:io';

import 'package:calendar_with_callback/calendar_with_callback.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar with Callback Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const CalendarTestPage(),
    );
  }
}

class CalendarTestPage extends StatefulWidget {
  const CalendarTestPage({super.key});

  @override
  State<CalendarTestPage> createState() => _CalendarTestPageState();
}

class _CalendarTestPageState extends State<CalendarTestPage> {
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  // Date/time controllers
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  bool _allDay = false;
  int? _reminderMinutes; // iOS only

  // State
  bool _isLoading = false;
  bool _hasPermission = false;
  String? _eventId;
  String? _calendarId;
  String? _lastMessage;
  bool _lastSuccess = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermission();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Check and automatically request permission if not granted
  Future<void> _checkAndRequestPermission() async {
    try {
      _addLog('Checking permission...');
      final hasPermission = await _checkPermissionStatus();

      if (!hasPermission) {
        _addLog('Permission not granted, requesting...');
        setState(() {
          _hasPermission = false;
        });
        // Auto request permission on app start
        await _requestPermission();
      } else {
        setState(() {
          _hasPermission = true;
          _addLog('Permission already granted');
        });
      }
    } catch (e) {
      _addLog('Error checking/requesting permission: $e');
    }
  }

  /// Check calendar permission status using permission_handler
  Future<bool> _checkPermissionStatus() async {
    try {
      // Check using permission_handler first
      final status = await Permission.calendar.status;
      _addLog('Permission status (permission_handler): $status');

      if (status.isGranted) {
        return true;
      }

      // Also check using CalendarWithCallback for consistency
      final hasPermission = await CalendarWithCallback.hasPermission();
      _addLog('Permission status (CalendarWithCallback): $hasPermission');

      return hasPermission;
    } catch (e) {
      _addLog('Error checking permission: $e');
      // Fallback to CalendarWithCallback
      return await CalendarWithCallback.hasPermission();
    }
  }

  /// Request calendar permission using permission_handler
  Future<void> _requestPermission() async {
    try {
      _addLog('Requesting permission using permission_handler...');

      // Request permission using permission_handler
      final status = await Permission.calendar.request();
      _addLog(
        'Calendar permission status: $status (Platform: ${Platform.operatingSystem})',
      );

      final granted = status.isGranted;

      // Also update using CalendarWithCallback for consistency
      if (granted) {
        // Double check with CalendarWithCallback
        final hasPermission = await CalendarWithCallback.hasPermission();
        _addLog('Double check with CalendarWithCallback: $hasPermission');
      }

      setState(() {
        _hasPermission = granted;
        _lastMessage = granted ? 'Permission granted' : 'Permission denied';
        _lastSuccess = granted;
      });
      _addLog('Permission request result: ${granted ? "Granted" : "Denied"}');

      if (!granted) {
        if (status.isPermanentlyDenied) {
          _showSnackBar(
            'Permission permanently denied. Please enable it in app settings.',
          );
        } else {
          _showSnackBar('Please grant calendar permission to use this feature');
        }
      }
    } catch (e) {
      _addLog('Error requesting permission: $e');
      // Fallback to CalendarWithCallback
      try {
        final granted = await CalendarWithCallback.requestPermission();
        setState(() {
          _hasPermission = granted;
          _lastMessage = granted ? 'Permission granted' : 'Permission denied';
          _lastSuccess = granted;
        });
      } catch (e2) {
        _addLog('Error with CalendarWithCallback fallback: $e2');
        _showSnackBar('Error requesting permission: $e');
      }
    }
  }

  /// Add event to calendar
  Future<void> _addEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _lastMessage = null;
    });

    try {
      _addLog('Creating event...');
      _addLog('Title: ${_titleController.text}');
      _addLog('Start: ${_startDate.toIso8601String()}');
      _addLog('End: ${_endDate.toIso8601String()}');
      _addLog('All Day: $_allDay');

      final event = CalendarEvent(
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        location: _locationController.text.isEmpty
            ? null
            : _locationController.text,
        startDate: _startDate,
        endDate: _endDate,
        allDay: _allDay,
        reminder: _reminderMinutes != null
            ? Duration(minutes: _reminderMinutes!)
            : null,
      );

      _addLog('Calling CalendarWithCallback.addEvent()...');
      final result = await CalendarWithCallback.addEvent(event);

      setState(() {
        _isLoading = false;
        _lastSuccess = result.success;
        _lastMessage = result.success
            ? 'Event added successfully!'
            : (result.errorMessage ?? 'Failed to add event');

        if (result.success) {
          _eventId = result.eventId;
          _calendarId = result.calendarId;
          _addLog('Success! Event ID: ${result.eventId}');
          _addLog('Calendar ID: ${result.calendarId}');
        } else {
          _eventId = null;
          _calendarId = null;
          _addLog('Failed: ${result.errorMessage}');
        }
      });

      if (result.success) {
        _showSnackBar('Event added successfully!', isError: false);
      } else {
        _showSnackBar(result.errorMessage ?? 'Failed to add event');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _lastSuccess = false;
        _lastMessage = 'Error: $e';
        _eventId = null;
        _calendarId = null;
      });
      _addLog('Exception: $e');
      _showSnackBar('Error: $e');
    }
  }

  /// Delete event from calendar
  Future<void> _deleteEvent() async {
    if (_eventId == null || _calendarId == null) {
      _showSnackBar('No event to delete');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _addLog('Deleting event: $_eventId');
      final success = await CalendarWithCallback.deleteEvent(
        _eventId!,
        _calendarId!,
      );

      setState(() {
        _isLoading = false;
        _lastSuccess = success;
        _lastMessage = success
            ? 'Event deleted successfully!'
            : 'Failed to delete event';
      });

      if (success) {
        _eventId = null;
        _calendarId = null;
        _addLog('Event deleted successfully');
        _showSnackBar('Event deleted successfully!', isError: false);
      } else {
        _addLog('Failed to delete event');
        _showSnackBar('Failed to delete event');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _lastSuccess = false;
        _lastMessage = 'Error: $e';
      });
      _addLog('Exception while deleting: $e');
      _showSnackBar('Error: $e');
    }
  }

  /// Show date picker for start date
  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (!_allDay) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_startDate),
        );
        if (time != null) {
          setState(() {
            _startDate = DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            );
            // Auto-update end date if it's before start date
            if (_endDate.isBefore(_startDate)) {
              _endDate = _startDate.add(const Duration(hours: 1));
            }
          });
        }
      } else {
        setState(() {
          _startDate = DateTime(picked.year, picked.month, picked.day);
        });
      }
    }
  }

  /// Show date picker for end date
  Future<void> _selectEndDate() async {
    // Ensure end date is not before start date
    final initialDate = _endDate.isBefore(_startDate) ? _startDate : _endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      if (!_allDay) {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(_endDate),
        );
        if (time != null) {
          setState(() {
            _endDate = DateTime(
              picked.year,
              picked.month,
              picked.day,
              time.hour,
              time.minute,
            );
          });
        }
      } else {
        setState(() {
          _endDate = DateTime(picked.year, picked.month, picked.day);
        });
      }
    }
  }

  /// Add log message
  void _addLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      // Keep only last 50 logs
      if (_logs.length > 50) {
        _logs = _logs.take(50).toList();
      }
    });
    print(message); // Also print to console
  }

  /// Show snackbar message
  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Format date time for display
  String _formatDateTime(DateTime dateTime) {
    if (_allDay) {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    }
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Test App'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Permission Status
                    Card(
                      color: _hasPermission
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _hasPermission
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: _hasPermission
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Permission: ${_hasPermission ? "Granted" : "Denied"}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _hasPermission
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            if (!_hasPermission) ...[
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _requestPermission,
                                icon: const Icon(Icons.lock_open),
                                label: const Text('Request Permission'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Event Form
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Event Information',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Title
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter event title',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Description
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                hintText: 'Enter event description',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // Location
                            TextFormField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Location',
                                border: OutlineInputBorder(),
                                hintText: 'Enter event location',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // All Day Toggle
                            SwitchListTile(
                              title: const Text('All Day Event'),
                              value: _allDay,
                              onChanged: (value) {
                                setState(() {
                                  _allDay = value;
                                  if (value) {
                                    _startDate = DateTime(
                                      _startDate.year,
                                      _startDate.month,
                                      _startDate.day,
                                    );
                                    _endDate = DateTime(
                                      _endDate.year,
                                      _endDate.month,
                                      _endDate.day,
                                    );
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 16),

                            // Start Date/Time
                            ListTile(
                              title: const Text('Start Date/Time *'),
                              subtitle: Text(_formatDateTime(_startDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectStartDate,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // End Date/Time
                            ListTile(
                              title: const Text('End Date/Time *'),
                              subtitle: Text(_formatDateTime(_endDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectEndDate,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Reminder (iOS only)
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS) ...[
                              DropdownButtonFormField<int?>(
                                initialValue: _reminderMinutes,
                                decoration: const InputDecoration(
                                  labelText: 'Reminder (iOS)',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('No reminder'),
                                  ),
                                  const DropdownMenuItem<int?>(
                                    value: 5,
                                    child: Text('5 minutes before'),
                                  ),
                                  const DropdownMenuItem<int?>(
                                    value: 15,
                                    child: Text('15 minutes before'),
                                  ),
                                  const DropdownMenuItem<int?>(
                                    value: 30,
                                    child: Text('30 minutes before'),
                                  ),
                                  const DropdownMenuItem<int?>(
                                    value: 60,
                                    child: Text('1 hour before'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _reminderMinutes = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Add to Calendar Button
                            ElevatedButton.icon(
                              onPressed: _hasPermission ? _addEvent : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Add to Calendar'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Result Display
                    if (_lastMessage != null)
                      Card(
                        color: _lastSuccess
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _lastSuccess
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: _lastSuccess
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _lastMessage!,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _lastSuccess
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_eventId != null) ...[
                                const SizedBox(height: 8),
                                Text('Event ID: $_eventId'),
                              ],
                              if (_calendarId != null) ...[
                                const SizedBox(height: 4),
                                Text('Calendar ID: $_calendarId'),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (_lastMessage != null) const SizedBox(height: 16),

                    // Delete Event Button
                    if (_eventId != null && _calendarId != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            onPressed: _deleteEvent,
                            icon: const Icon(Icons.delete),
                            label: const Text('Delete Event'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    if (_eventId != null) const SizedBox(height: 16),

                    // Logs Section
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Debug Logs',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _logs.clear();
                                    });
                                  },
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: _logs.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No logs yet',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : ListView.builder(
                                      reverse: true,
                                      itemCount: _logs.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            _logs[index],
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
