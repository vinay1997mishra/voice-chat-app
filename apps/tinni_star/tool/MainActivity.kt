package com.tinnistar.tinni_star

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.common.api.ApiException
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
    private val googleSignInRequest = 745
    private var pendingGoogleResult: MethodChannel.Result? = null
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


        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tinni.star/google_sign_in"
        ).setMethodCallHandler { call, result ->
            if (call.method == "authenticate") {
                startClassicGoogleSignIn(call.argument<String>("server_client_id") ?: "", result)
            } else {
                result.notImplemented()
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


    @Suppress("DEPRECATION")
    private fun startClassicGoogleSignIn(serverClientId: String, result: MethodChannel.Result) {
        if (pendingGoogleResult != null) {
            result.error("google_busy", "Google login is already open.", null)
            return
        }
        if (serverClientId.isBlank()) {
            result.error("google_setup", "Google login setup is unavailable.", null)
            return
        }
        val availability = GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this)
        if (availability != ConnectionResult.SUCCESS) {
            result.error("google_play_services", "Please update Google Play services and try again.", availability)
            return
        }
        pendingGoogleResult = result
        try {
            val options = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestEmail()
                .requestIdToken(serverClientId)
                .build()
            val client = GoogleSignIn.getClient(this, options)
            // Explicit user action: let them choose an account again instead of
            // silently retrying a cancelled Credential Manager dialog.
            client.signOut().addOnCompleteListener {
                if (pendingGoogleResult == null || isFinishing || isDestroyed) return@addOnCompleteListener
                try {
                    startActivityForResult(client.signInIntent, googleSignInRequest)
                } catch (error: Exception) {
                    pendingGoogleResult?.error("google_unavailable", "Unable to open Google account picker.", null)
                    pendingGoogleResult = null
                }
            }
        } catch (error: Exception) {
            pendingGoogleResult = null
            result.error("google_unavailable", "Unable to open Google account picker.", null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != googleSignInRequest) return
        val result = pendingGoogleResult ?: return
        pendingGoogleResult = null
        if (data == null && resultCode == Activity.RESULT_CANCELED) {
            result.error("google_canceled", "Google login cancelled.", null)
            return
        }
        try {
            val account = GoogleSignIn.getSignedInAccountFromIntent(data).getResult(ApiException::class.java)
            val token = account.idToken
            if (token.isNullOrBlank() || account.email.isNullOrBlank()) {
                result.error("google_token_missing", "Google did not return a valid account. Please try again.", null)
                return
            }
            result.success(mapOf("id_token" to token, "email" to account.email,
                "display_name" to (account.displayName ?: "")))
        } catch (error: ApiException) {
            when (error.statusCode) {
                12501, 16 -> result.error("google_canceled", "Google login cancelled.", null)
                10 -> result.error("google_setup", "Google login setup does not match this app. Reference: 10", 10)
                else -> result.error("google_failed", "Google login failed. Reference: " + error.statusCode, error.statusCode)
            }
        } catch (error: Exception) {
            result.error("google_failed", "Unable to complete Google login. Please try again.", null)
        }
    }

    override fun onDestroy() {
        pendingGoogleResult?.error("google_canceled", "Google login screen closed.", null)
        pendingGoogleResult = null
        super.onDestroy()
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
