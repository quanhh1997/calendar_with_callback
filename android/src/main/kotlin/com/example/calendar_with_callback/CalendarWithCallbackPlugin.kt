package com.example.calendar_with_callback

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.text.SimpleDateFormat
import java.util.*

class CalendarWithCallbackPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private lateinit var channel : MethodChannel
  private var activity: android.app.Activity? = null
  private val REQUEST_CODE_ADD_EVENT = 1001
  private val REQUEST_CODE_PERMISSION = 1002
  private var pendingResult: Result? = null
  private var pendingEventData: Map<String, Any>? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "calendar_with_callback")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "addEvent" -> {
        if (activity == null) {
          result.error("NO_ACTIVITY", "Activity is not available", null)
          return
        }
        
        // Check permission first
        if (!hasPermission()) {
          requestPermission(result)
          return
        }
        
        val eventData = call.arguments as Map<String, Any>
        addEventToCalendar(eventData, result)
      }
      "deleteEvent" -> {
        val args = call.arguments as Map<String, Any>
        val eventId = args["eventId"] as String
        val calendarId = args["calendarId"] as String
        deleteEvent(eventId, calendarId, result)
      }
      "hasPermission" -> {
        result.success(hasPermission())
      }
      "requestPermission" -> {
        requestPermission(result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun hasPermission(): Boolean {
    return activity?.let {
      ContextCompat.checkSelfPermission(
        it,
        Manifest.permission.WRITE_CALENDAR
      ) == PackageManager.PERMISSION_GRANTED &&
      ContextCompat.checkSelfPermission(
        it,
        Manifest.permission.READ_CALENDAR
      ) == PackageManager.PERMISSION_GRANTED
    } ?: false
  }

  private fun requestPermission(result: Result) {
    activity?.let {
      ActivityCompat.requestPermissions(
        it,
        arrayOf(
          Manifest.permission.WRITE_CALENDAR,
          Manifest.permission.READ_CALENDAR
        ),
        REQUEST_CODE_PERMISSION
      )
      // Note: Permission result will be handled in Activity's onRequestPermissionsResult
      // For now, we'll check permission status
      result.success(hasPermission())
    } ?: run {
      result.error("NO_ACTIVITY", "Activity is not available", null)
    }
  }

  private fun addEventToCalendar(eventData: Map<String, Any>, result: Result) {
    try {
      val title = eventData["title"] as? String ?: ""
      val description = eventData["description"] as? String
      val location = eventData["location"] as? String
      val startDateStr = eventData["startDate"] as String
      val endDateStr = eventData["endDate"] as String
      val allDay = eventData["allDay"] as? Boolean ?: false

      val dateFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
      dateFormat.timeZone = TimeZone.getTimeZone("UTC")
      val startDate = dateFormat.parse(startDateStr)
      val endDate = dateFormat.parse(endDateStr)

      if (startDate == null || endDate == null) {
        result.error("INVALID_DATE", "Invalid date format", null)
        return
      }

      // Create intent to add event
      val intent = Intent(Intent.ACTION_INSERT).apply {
        data = CalendarContract.Events.CONTENT_URI
        putExtra(CalendarContract.Events.TITLE, title)
        description?.let { putExtra(CalendarContract.Events.DESCRIPTION, it) }
        location?.let { putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startDate.time)
        putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endDate.time)
        putExtra(CalendarContract.EXTRA_EVENT_ALL_DAY, allDay)
      }

      // Store pending data to check result later
      pendingResult = result
      pendingEventData = eventData

      activity?.startActivityForResult(intent, REQUEST_CODE_ADD_EVENT)
      
      // Note: We need to handle the result in onActivityResult
      // For now, we'll use a workaround: check for the event after a delay
      android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
        checkForNewEvent(startDate, endDate, title, result)
      }, 2000) // Wait 2 seconds for user to add event
      
    } catch (e: Exception) {
      result.error("ERROR", "Failed to add event: ${e.message}", null)
    }
  }

  private fun checkForNewEvent(startDate: Date, endDate: Date, title: String, result: Result) {
    try {
      val projection = arrayOf(
        CalendarContract.Events._ID,
        CalendarContract.Events.CALENDAR_ID,
        CalendarContract.Events.TITLE,
        CalendarContract.Events.DTSTART,
        CalendarContract.Events.DTEND
      )

      val selection = "${CalendarContract.Events.TITLE} = ? AND ${CalendarContract.Events.DTSTART} >= ? AND ${CalendarContract.Events.DTSTART} <= ?"
      val selectionArgs = arrayOf(
        title,
        startDate.time.toString(),
        (startDate.time + 3600000).toString() // 1 hour window
      )

      val cursor = activity?.contentResolver?.query(
        CalendarContract.Events.CONTENT_URI,
        projection,
        selection,
        selectionArgs,
        "${CalendarContract.Events.DTSTART} DESC"
      )

      cursor?.use {
        if (it.moveToFirst()) {
          val eventId = it.getLong(it.getColumnIndexOrThrow(CalendarContract.Events._ID)).toString()
          val calendarId = it.getLong(it.getColumnIndexOrThrow(CalendarContract.Events.CALENDAR_ID)).toString()
          
          result.success(mapOf(
            "success" to true,
            "eventId" to eventId,
            "calendarId" to calendarId
          ))
        } else {
          result.success(mapOf(
            "success" to false,
            "errorMessage" to "Event not found (user may have cancelled)"
          ))
        }
      } ?: run {
        result.success(mapOf(
          "success" to false,
          "errorMessage" to "Failed to query calendar"
        ))
      }
    } catch (e: Exception) {
      result.success(mapOf(
        "success" to false,
        "errorMessage" to "Error checking event: ${e.message}"
      ))
    }
  }

  private fun deleteEvent(eventId: String, calendarId: String, result: Result) {
    try {
      val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId.toLong())
      val deleted = activity?.contentResolver?.delete(uri, null, null) ?: 0
      result.success(deleted > 0)
    } catch (e: Exception) {
      result.error("ERROR", "Failed to delete event: ${e.message}", null)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivity() {
    activity = null
  }
}

