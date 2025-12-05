import Flutter
import UIKit
import EventKit
import EventKitUI

public class CalendarWithCallbackPlugin: NSObject, FlutterPlugin {
  private let eventStore = EKEventStore()
  private var result: FlutterResult?
  private weak var registrar: FlutterPluginRegistrar?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "calendar_with_callback", binaryMessenger: registrar.messenger())
    let instance = CalendarWithCallbackPlugin()
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "addEvent":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
      }
      self.result = result
      addEvent(args: args)
      
    case "deleteEvent":
      guard let args = call.arguments as? [String: Any],
            let eventId = args["eventId"] as? String,
            let calendarId = args["calendarId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
        return
      }
      deleteEvent(eventId: eventId, calendarId: calendarId, result: result)
      
    case "hasPermission":
      result(hasPermission())
      
    case "requestPermission":
      requestPermission(result: result)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func hasPermission() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    return status == .authorized
  }
  
  private func requestPermission(result: @escaping FlutterResult) {
    eventStore.requestAccess(to: .event) { granted, error in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }
  
  private func addEvent(args: [String: Any]) {
    // Check permission first
    let status = EKEventStore.authorizationStatus(for: .event)
    
    if status == .notDetermined {
      eventStore.requestAccess(to: .event) { [weak self] granted, error in
        if granted {
          DispatchQueue.main.async {
            self?.createAndPresentEvent(args: args)
          }
        } else {
          DispatchQueue.main.async {
            self?.result?([
              "success": false,
              "errorMessage": "Calendar permission denied"
            ])
          }
        }
      }
    } else if status == .authorized {
      // Dispatch to main thread to ensure UI operations are safe
      DispatchQueue.main.async { [weak self] in
        self?.createAndPresentEvent(args: args)
      }
    } else {
      result?([
        "success": false,
        "errorMessage": "Calendar permission denied"
      ])
    }
  }
  
  private func createAndPresentEvent(args: [String: Any]) {
    guard let title = args["title"] as? String,
          let startDateStr = args["startDate"] as? String,
          let endDateStr = args["endDate"] as? String else {
      result?([
        "success": false,
        "errorMessage": "Missing required fields"
      ])
      return
    }
    
    // Parse ISO8601 date string
    // toIso8601String() can produce formats like:
    // - "2025-11-22T13:18:00.000" (local time, no timezone)
    // - "2025-11-22T13:18:00.000Z" (UTC)
    // - "2025-11-22T13:18:00.000+00:00" (with timezone)
    
    // Use DateFormatter with flexible format parsing
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone.current
    
    // Try different date formats
    let dateFormats = [
      "yyyy-MM-dd'T'HH:mm:ss.SSSZ",  // With timezone and milliseconds
      "yyyy-MM-dd'T'HH:mm:ss.SSS",   // With milliseconds, no timezone
      "yyyy-MM-dd'T'HH:mm:ssZ",      // With timezone, no milliseconds
      "yyyy-MM-dd'T'HH:mm:ss",       // No timezone, no milliseconds
      "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", // UTC with milliseconds
      "yyyy-MM-dd'T'HH:mm:ss'Z'"     // UTC without milliseconds
    ]
    
    var startDate: Date?
    var endDate: Date?
    
    for format in dateFormats {
      dateFormatter.dateFormat = format
      
      if startDate == nil {
        startDate = dateFormatter.date(from: startDateStr)
      }
      if endDate == nil {
        endDate = dateFormatter.date(from: endDateStr)
      }
      
      // If both dates are parsed, break early
      if startDate != nil && endDate != nil {
        break
      }
    }
    
    guard let parsedStartDate = startDate, let parsedEndDate = endDate else {
      result?([
        "success": false,
        "errorMessage": "Invalid date format: startDate=\(startDateStr), endDate=\(endDateStr)"
      ])
      return
    }
    
    let event = EKEvent(eventStore: eventStore)
    event.title = title
    event.startDate = parsedStartDate
    event.endDate = parsedEndDate
    event.isAllDay = args["allDay"] as? Bool ?? false
    event.notes = args["description"] as? String
    event.location = args["location"] as? String
    
    // Set reminder if provided
    if let reminderMinutes = args["reminder"] as? Int {
      event.addAlarm(EKAlarm(relativeOffset: TimeInterval(-reminderMinutes * 60)))
    }
    
    // Use default calendar
    event.calendar = eventStore.defaultCalendarForNewEvents
    
    // Present the view controller - ALL UI operations must be on main thread
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      
      // Create event edit view controller on main thread
      let eventEditViewController = EKEventEditViewController()
      eventEditViewController.eventStore = self.eventStore
      eventEditViewController.event = event
      eventEditViewController.editViewDelegate = self
      
      // Try to get the root view controller from the Flutter view controller
      var presentingViewController: UIViewController?
      
      // Method 1: Try to get from Flutter view controller
      if let flutterViewController = UIApplication.shared.windows.first?.rootViewController as? FlutterViewController {
        presentingViewController = flutterViewController
      }
      // Method 2: Try to get from connected scenes (iOS 13+)
      else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController {
        presentingViewController = rootViewController
      }
      // Method 3: Try to get from key window (fallback)
      else if let rootViewController = UIApplication.shared.keyWindow?.rootViewController {
        presentingViewController = rootViewController
      }
      
      if let presentingVC = presentingViewController {
        // Set modal presentation style for better compatibility
        eventEditViewController.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
          if let sheet = eventEditViewController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
          }
        }
        presentingVC.present(eventEditViewController, animated: true, completion: nil)
      } else {
        self.result?([
          "success": false,
          "errorMessage": "Could not present calendar view - no view controller found"
        ])
        self.result = nil
      }
    }
  }
  
  private func deleteEvent(eventId: String, calendarId: String, result: @escaping FlutterResult) {
    guard let event = eventStore.event(withIdentifier: eventId) else {
      result(false)
      return
    }
    
    do {
      try eventStore.remove(event, span: .thisEvent)
      result(true)
    } catch {
      result(FlutterError(code: "ERROR", message: "Failed to delete event: \(error.localizedDescription)", details: nil))
    }
  }
}

extension CalendarWithCallbackPlugin: EKEventEditViewDelegate {
  public func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
    controller.dismiss(animated: true)
    
    switch action {
    case .saved:
      // Event was saved, get the event ID
      if let event = controller.event,
         let eventId = event.eventIdentifier {
        let calendarId = event.calendar.calendarIdentifier
        
        result?([
          "success": true,
          "eventId": eventId,
          "calendarId": calendarId
        ])
      } else {
        result?([
          "success": false,
          "errorMessage": "Event saved but could not retrieve ID"
        ])
      }
      
    case .canceled:
      result?([
        "success": false,
        "errorMessage": "User cancelled"
      ])
      
    case .deleted:
      result?([
        "success": false,
        "errorMessage": "Event was deleted"
      ])
      
    @unknown default:
      result?([
        "success": false,
        "errorMessage": "Unknown action"
      ])
    }
    
    result = nil
  }
}

