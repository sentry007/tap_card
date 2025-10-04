package com.example.tap_card

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity: FlutterActivity() {
    private val INTENT_CHANNEL = "app.tapcard/nfc_intent"
    private val WRITE_CHANNEL = "app.tapcard/nfc_write"
    private var intentMethodChannel: MethodChannel? = null
    private var writeMethodChannel: MethodChannel? = null

    private var nfcAdapter: NfcAdapter? = null
    private var pendingIntent: PendingIntent? = null
    private var nfcWriteMode = false
    private var pendingWriteData: String? = null
    private var pendingForegroundDispatchEnable = false
    private var isActivityResumed = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize NFC adapter
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

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
                    "writeNdefText" -> {
                        val text = call.argument<String>("text")
                        if (text != null) {
                            println("📝 Android: Preparing to write NDEF text: ${text.substring(0, text.length.coerceAtMost(50))}...")
                            pendingWriteData = text
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                println("   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, 150)
                            } else {
                                println("   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_TEXT", "Text parameter is required", null)
                        }
                    }
                    "writeText" -> {
                        val text = call.argument<String>("text")
                        if (text != null) {
                            println("📝 Android: Preparing to write plain text: ${text.substring(0, text.length.coerceAtMost(50))}...")
                            pendingWriteData = text
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                println("   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, 150)
                            } else {
                                println("   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_TEXT", "Text parameter is required", null)
                        }
                    }
                    "writeUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            println("📝 Android: Preparing to write URL: ${url.substring(0, url.length.coerceAtMost(50))}...")
                            pendingWriteData = url
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                println("   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, 150)
                            } else {
                                println("   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL parameter is required", null)
                        }
                    }
                    "readUrl" -> {
                        println("📖 Android: Would read URL from tag")
                        result.success(null)
                    }
                    "cancelWrite" -> {
                        println("🛑 Android: Cancelling NFC write mode")
                        nfcWriteMode = false
                        pendingWriteData = null
                        disableForegroundDispatch()
                        result.success(true)
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

        // Setup pending intent for NFC
        pendingIntent = PendingIntent.getActivity(
            this, 0, Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_MUTABLE
        )

        // Log intent information for debugging
        logIntentInfo(intent)
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true
        println("🟢 Android: onResume() - Activity is RESUMED (nfcWriteMode=$nfcWriteMode, pending=$pendingForegroundDispatchEnable)")

        // Check if we need to enable foreground dispatch
        if (pendingForegroundDispatchEnable || nfcWriteMode) {
            pendingForegroundDispatchEnable = false

            println("   → Enabling foreground dispatch (with small delay to ensure fully resumed)")

            // Use Handler.postDelayed to ensure activity is fully resumed
            Handler(Looper.getMainLooper()).postDelayed({
                if (isActivityResumed && nfcWriteMode) {
                    println("   → Activity confirmed RESUMED, enabling now...")
                    enableForegroundDispatch()
                } else {
                    println("   ⚠️ Activity not resumed or write mode cancelled (isActivityResumed=$isActivityResumed, nfcWriteMode=$nfcWriteMode)")
                }
            }, 150) // 150ms delay to ensure activity is stable
        }
    }

    override fun onPause() {
        super.onPause()
        isActivityResumed = false
        println("🟡 Android: onPause() - Activity is PAUSED (nfcWriteMode=$nfcWriteMode)")
        // IMPORTANT: Don't disable foreground dispatch if we're in write mode
        // This allows the dispatch to remain active even when activity loses focus
        if (!nfcWriteMode) {
            disableForegroundDispatch()
        } else {
            println("⚠️ Android: Keeping foreground dispatch active during PAUSED state")
        }
    }

    override fun onStop() {
        super.onStop()
        println("🔴 Android: onStop() - Activity is STOPPED (nfcWriteMode=$nfcWriteMode)")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update the intent

        println("🔔 Android: onNewIntent() FIRED!")
        println("   Action: ${intent.action}")
        println("   nfcWriteMode: $nfcWriteMode")

        // Log new intent for debugging
        logIntentInfo(intent)

        // Handle ANY NFC-related intent when in write mode
        val isNfcAction = intent.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
                          intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
                          intent.action == NfcAdapter.ACTION_TECH_DISCOVERED

        if (nfcWriteMode && isNfcAction) {
            println("📡 Android: NFC action detected: ${intent.action}")
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)

            if (tag != null && pendingWriteData != null) {
                println("📡 Android: NFC tag object found, attempting write...")
                val writeResult = writeToTag(tag, pendingWriteData!!)

                runOnUiThread {
                    if (writeResult.success) {
                        println("✅ Android: Successfully wrote to NFC tag (${writeResult.bytesWritten} bytes)")
                        writeMethodChannel?.invokeMethod("onWriteSuccess", writeResult.bytesWritten)
                    } else {
                        println("❌ Android: Failed to write to NFC tag: ${writeResult.error}")
                        writeMethodChannel?.invokeMethod("onWriteError", writeResult.error)
                    }
                }

                // Reset write mode
                nfcWriteMode = false
                pendingWriteData = null
                disableForegroundDispatch()
            } else {
                println("⚠️ Android: Tag or pendingWriteData is null - tag=$tag, data=${pendingWriteData != null}")
            }
        } else if (isNfcIntent(intent)) {
            println("🎮 NFC detected but write mode is OFF (nfcWriteMode=$nfcWriteMode)")
        } else {
            println("ℹ️ Android: Non-NFC intent received")
        }
    }

    private fun enableForegroundDispatch() {
        println("🔧 Android: enableForegroundDispatch() called (nfcWriteMode=$nfcWriteMode)")
        println("   Current activity state: isActivityResumed=$isActivityResumed, isFinishing=$isFinishing")

        // CRITICAL: Foreground dispatch only works in RESUMED state
        if (!isActivityResumed) {
            println("❌ Android: CRITICAL - Activity is NOT in RESUMED state!")
            println("   NFC foreground dispatch will NOT work until activity is RESUMED")
            return
        }

        nfcAdapter?.let { adapter ->
            if (adapter.isEnabled) {
                val filters = arrayOf(
                    IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
                    IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED),
                    IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)
                )
                val techLists = arrayOf(
                    arrayOf(Ndef::class.java.name),
                    arrayOf(NdefFormatable::class.java.name)
                )

                try {
                    adapter.enableForegroundDispatch(this, pendingIntent, filters, techLists)
                    println("✅ Android: NFC foreground dispatch ENABLED successfully (activity is RESUMED)")
                    println("📲 Android: Ready to detect NFC tags - bring tag close to phone")
                } catch (e: Exception) {
                    println("❌ Android: Failed to enable foreground dispatch: ${e.message}")
                    e.printStackTrace()
                }
            } else {
                println("⚠️ Android: NFC adapter is disabled in device settings")
            }
        } ?: println("❌ Android: NFC adapter is null")
    }

    private fun disableForegroundDispatch() {
        nfcAdapter?.let { adapter ->
            try {
                adapter.disableForegroundDispatch(this)
                println("🛑 Android: NFC foreground dispatch disabled")
            } catch (e: Exception) {
                println("⚠️ Android: Error disabling foreground dispatch: ${e.message}")
            }
        }
    }

    // Data class for write results
    data class WriteResult(
        val success: Boolean,
        val bytesWritten: Int = 0,
        val error: String? = null
    )

    private fun writeToTag(tag: Tag, data: String): WriteResult {
        try {
            // Create NDEF text record
            val ndefRecord = createTextRecord(data)
            val ndefMessage = NdefMessage(arrayOf(ndefRecord))

            // Try to write using Ndef
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()

                // Check if tag is writable
                if (!ndef.isWritable) {
                    println("❌ Android: Tag is not writable")
                    ndef.close()
                    return WriteResult(false, error = "Tag is write-protected")
                }

                // Check if message fits
                val size = ndefMessage.toByteArray().size
                if (ndef.maxSize < size) {
                    println("❌ Android: Message too large for tag ($size bytes > ${ndef.maxSize} bytes)")
                    ndef.close()
                    return WriteResult(false, error = "Message too large ($size bytes > ${ndef.maxSize} bytes)")
                }

                // Write the message
                ndef.writeNdefMessage(ndefMessage)
                println("✅ Android: NDEF message written successfully ($size bytes)")
                ndef.close()
                return WriteResult(true, bytesWritten = size)
            }

            // Try to format the tag if it's not NDEF formatted
            val ndefFormatable = NdefFormatable.get(tag)
            if (ndefFormatable != null) {
                ndefFormatable.connect()
                val size = ndefMessage.toByteArray().size
                ndefFormatable.format(ndefMessage)
                println("✅ Android: Tag formatted and message written ($size bytes)")
                ndefFormatable.close()
                return WriteResult(true, bytesWritten = size)
            }

            println("❌ Android: Tag is neither NDEF nor formattable")
            return WriteResult(false, error = "Tag is not NDEF compatible")

        } catch (e: Exception) {
            println("❌ Android: Exception writing to tag: ${e.message}")
            e.printStackTrace()
            return WriteResult(false, error = e.message ?: "Unknown error")
        }
    }

    private fun createTextRecord(text: String): NdefRecord {
        val languageCode = "en"
        val languageCodeBytes = languageCode.toByteArray(Charset.forName("US-ASCII"))
        val textBytes = text.toByteArray(Charset.forName("UTF-8"))

        val payloadBytes = ByteArray(1 + languageCodeBytes.size + textBytes.size)
        payloadBytes[0] = languageCodeBytes.size.toByte()
        System.arraycopy(languageCodeBytes, 0, payloadBytes, 1, languageCodeBytes.size)
        System.arraycopy(textBytes, 0, payloadBytes, 1 + languageCodeBytes.size, textBytes.size)

        return NdefRecord(NdefRecord.TNF_WELL_KNOWN, NdefRecord.RTD_TEXT, ByteArray(0), payloadBytes)
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
