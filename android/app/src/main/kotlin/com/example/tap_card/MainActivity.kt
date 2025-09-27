package com.example.tap_card

import android.content.Intent
import android.net.Uri
import android.nfc.NfcAdapter
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val INTENT_CHANNEL = "app.tapcard/nfc_intent"
    private val WRITE_CHANNEL = "app.tapcard/nfc_write"
    private var intentMethodChannel: MethodChannel? = null
    private var writeMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Intent channel for NFC intent detection
        intentMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialIntent" -> {
                        val intentData = extractNfcIntentData(intent)
                        result.success(intentData)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }

        // Write channel for NFC writing operations
        writeMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WRITE_CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            // For now, just return true since actual NFC writing
                            // is complex and requires proper NDEF implementation
                            println("📝 Android: Would write URL: $url")
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL parameter is required", null)
                        }
                    }
                    "readUrl" -> {
                        // For now, return null since actual reading would require
                        // proper NDEF implementation
                        println("📖 Android: Would read URL from tag")
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Log intent information for debugging
        logIntentInfo(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update the intent

        // Log new intent for debugging
        logIntentInfo(intent)

        // DISABLED: No auto-restart on NFC detection
        // User controls sharing manually via FAB button
        if (isNfcIntent(intent)) {
            println("🎮 NFC detected but auto-restart disabled - user controls sharing manually")
        }
    }

    private fun logIntentInfo(intent: Intent?) {
        if (intent == null) return

        println("📱 Intent Action: ${intent.action}")
        println("📱 Intent Data: ${intent.data}")
        println("📱 Intent Categories: ${intent.categories}")
        println("📱 Intent Extras: ${intent.extras?.keySet()}")

        if (isNfcIntent(intent)) {
            println("🏷️ This is an NFC intent!")
            val nfcData = extractNfcIntentData(intent)
            if (nfcData != null) {
                println("📄 NFC Data: ${nfcData.substring(0, nfcData.length.coerceAtMost(100))}...")
            }
        }
    }

    private fun isNfcIntent(intent: Intent): Boolean {
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val uri = intent.data
                uri?.host == "tapcard.app" && uri.getQueryParameter("data") != null
            }
            NfcAdapter.ACTION_NDEF_DISCOVERED -> true
            NfcAdapter.ACTION_TAG_DISCOVERED -> true
            else -> false
        }
    }

    private fun extractNfcIntentData(intent: Intent): String? {
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                // Handle deep link intents (https://tapcard.app/receive?data=...)
                val uri = intent.data
                println("📱 ACTION_VIEW URI: $uri")
                if (uri?.host == "tapcard.app") {
                    uri.toString()
                } else null
            }
            NfcAdapter.ACTION_NDEF_DISCOVERED -> {
                // Handle NDEF discovered intents
                val uri = intent.data
                println("📱 NDEF_DISCOVERED URI: $uri")

                // Also check raw NDEF records
                val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
                if (rawMessages != null) {
                    println("📋 Found ${rawMessages.size} NDEF messages")
                    // Extract text from NDEF records
                    // This is where we would parse actual NDEF data
                }

                uri?.toString()
            }
            NfcAdapter.ACTION_TAG_DISCOVERED -> {
                // Handle any NFC tag
                println("📱 TAG_DISCOVERED - checking for NDEF data")
                val tag = intent.getParcelableExtra<android.nfc.Tag>(NfcAdapter.EXTRA_TAG)

                if (tag != null) {
                    println("📋 Tag ID: ${tag.id.contentToString()}")
                    println("📋 Tag tech list: ${tag.techList.contentToString()}")
                }

                // For now, return null since we don't have NDEF data
                null
            }
            else -> {
                println("📱 Unknown action: ${intent.action}")
                null
            }
        }
    }
}
