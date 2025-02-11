package com.example.uztexsoftclients

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.uztexsoftclients/telegram"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openTelegram") {
                val success = openTelegram(call.argument<String>("url") ?: "")
                if (success) {
                    result.success(null)
                } else {
                    result.error("UNAVAILABLE", "Telegram not installed", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openTelegram(url: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            intent.setPackage("org.telegram.messenger")
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
