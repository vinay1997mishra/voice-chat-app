package com.tinnistar.tinni_star

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val roomServiceChannel = "tinni.star/room_service"
    private val permissionChannel = "tinni.star/permissions"
    private val privacyChannel = "tinni.star/privacy"
    private val voicePermissionRequest = 744
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var privacyMethodChannel: MethodChannel? = null
    private var captureCallback: android.app.Activity.ScreenCaptureCallback? = null
    private var recordingCallback: java.util.function.Consumer<Int>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            roomServiceChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val intent = Intent(this, TinniRoomForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(true)
                }
                "stop" -> {
                    stopService(Intent(this, TinniRoomForegroundService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }


        privacyMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            privacyChannel
        )
        privacyMethodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecureScreen" -> {
                    val enabled = call.argument<Boolean>("enabled") == true
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            registerPrivacyDetection()
                        } else {
                            unregisterPrivacyDetection()
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            permissionChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVoiceRoom" -> requestVoiceRoomPermissions(result)
                "hasVoiceRoom" -> result.success(hasVoiceRoomPermissions())
                else -> result.notImplemented()
            }
        }
    }


    private fun registerPrivacyDetection() {
        if (Build.VERSION.SDK_INT >= 34 && captureCallback == null) {
            captureCallback = android.app.Activity.ScreenCaptureCallback {
                privacyMethodChannel?.invokeMethod("captureAttempt", mapOf("action" to "screenshot"))
            }
            registerScreenCaptureCallback(mainExecutor, captureCallback!!)
        }
        if (Build.VERSION.SDK_INT >= 35 && recordingCallback == null) {
            recordingCallback = java.util.function.Consumer<Int> { state ->
                if (state == WindowManager.SCREEN_RECORDING_STATE_VISIBLE) {
                    privacyMethodChannel?.invokeMethod("captureAttempt", mapOf("action" to "screen_recording"))
                }
            }
            windowManager.addScreenRecordingCallback(mainExecutor, recordingCallback!!)
        }
    }

    private fun unregisterPrivacyDetection() {
        if (Build.VERSION.SDK_INT >= 34) {
            captureCallback?.let { unregisterScreenCaptureCallback(it) }
        }
        captureCallback = null
        if (Build.VERSION.SDK_INT >= 35) {
            recordingCallback?.let { windowManager.removeScreenRecordingCallback(it) }
        }
        recordingCallback = null
    }

    private fun voiceRoomPermissions(): Array<String> {
        val permissions = mutableListOf(Manifest.permission.RECORD_AUDIO)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return permissions.toTypedArray()
    }

    private fun hasVoiceRoomPermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        // Bluetooth and notification access are optional. Phone microphone
        // audio must work when the user declines either optional permission.
        return checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestVoiceRoomPermissions(result: MethodChannel.Result) {
        if (hasVoiceRoomPermissions()) {
            result.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("permission_busy", "Permission request is already active.", null)
            return
        }
        pendingPermissionResult = result
        requestPermissions(voiceRoomPermissions(), voicePermissionRequest)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != voicePermissionRequest) return
        val granted = hasVoiceRoomPermissions()
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }
}
