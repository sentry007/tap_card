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
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.nio.charset.Charset

class MainActivity: FlutterActivity() {
    companion object {
        private const val TAG = "TapCard.NFC"

        // NFC Constants
        private const val ACTIVITY_RESUME_DELAY_MS = 150L
        private const val NTAG213_MAX_BYTES = 144
        private const val NTAG215_MAX_BYTES = 504
        private const val NTAG216_MAX_BYTES = 888
    }

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
                    "writeDualPayload" -> {
                        val vcard = call.argument<String>("vcard")
                        val url = call.argument<String>("url")

                        if (vcard != null && url != null) {
                            Log.d(TAG, "📝 Preparing dual-payload NFC write")
                            Log.d(TAG, "   📇 vCard: ${vcard.length} chars")
                            Log.d(TAG, "   🌐 URL: $url")

                            // Store both vCard and URL as JSON for the write handler
                            val dualPayload = """{"type":"dual","vcard":"${vcard.replace("\"", "\\\"")}","url":"$url"}"""
                            pendingWriteData = dualPayload
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                Log.d(TAG, "   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, ACTIVITY_RESUME_DELAY_MS)
                            } else {
                                Log.d(TAG, "   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_PARAMS", "Both vcard and url parameters are required", null)
                        }
                    }
                    "writeUrlOnly" -> {
                        val url = call.argument<String>("url")

                        if (url != null) {
                            Log.d(TAG, "📝 Preparing URL-only NFC write (fallback strategy)")
                            Log.d(TAG, "   🌐 URL: $url")
                            Log.d(TAG, "   💡 Note: Dual-payload was too large, writing URL only")

                            // Store URL as simple string (non-dual format)
                            // writeToTag() will detect this is not dual-payload and create single URL record
                            pendingWriteData = url
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                Log.d(TAG, "   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, ACTIVITY_RESUME_DELAY_MS)
                            } else {
                                Log.d(TAG, "   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_PARAMS", "URL parameter is required", null)
                        }
                    }
                    "writeNdefText" -> {
                        val text = call.argument<String>("text")
                        if (text != null) {
                            Log.d(TAG, "📝 Preparing to write NDEF text: ${text.substring(0, text.length.coerceAtMost(50))}...")
                            pendingWriteData = text
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                Log.d(TAG, "   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, ACTIVITY_RESUME_DELAY_MS)
                            } else {
                                Log.d(TAG, "   ⏳ Activity not resumed yet, will enable in onResume()")
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
                            Log.d(TAG, "📝 Preparing to write plain text: ${text.substring(0, text.length.coerceAtMost(50))}...")
                            pendingWriteData = text
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                Log.d(TAG, "   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, ACTIVITY_RESUME_DELAY_MS)
                            } else {
                                Log.d(TAG, "   ⏳ Activity not resumed yet, will enable in onResume()")
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
                            Log.d(TAG, "📝 Preparing to write URL: ${url.substring(0, url.length.coerceAtMost(50))}...")
                            pendingWriteData = url
                            nfcWriteMode = true

                            // If activity is already resumed, enable dispatch immediately
                            if (isActivityResumed) {
                                Log.d(TAG, "   ✅ Activity is already RESUMED, enabling dispatch now...")
                                Handler(Looper.getMainLooper()).postDelayed({
                                    if (isActivityResumed && nfcWriteMode) {
                                        enableForegroundDispatch()
                                    }
                                }, ACTIVITY_RESUME_DELAY_MS)
                            } else {
                                Log.d(TAG, "   ⏳ Activity not resumed yet, will enable in onResume()")
                                pendingForegroundDispatchEnable = true
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL parameter is required", null)
                        }
                    }
                    "readUrl" -> {
                        Log.d(TAG, "📖 Would read URL from tag")
                        result.success(null)
                    }
                    "cancelWrite" -> {
                        Log.d(TAG, "🛑 Cancelling NFC write mode")
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
        Log.d(TAG, "🟢 onResume() - Activity is RESUMED (nfcWriteMode=$nfcWriteMode, pending=$pendingForegroundDispatchEnable)")

        // Check if we need to enable foreground dispatch
        if (pendingForegroundDispatchEnable || nfcWriteMode) {
            pendingForegroundDispatchEnable = false

            Log.d(TAG, "   → Enabling foreground dispatch (with small delay to ensure fully resumed)")

            // Use Handler.postDelayed to ensure activity is fully resumed
            Handler(Looper.getMainLooper()).postDelayed({
                if (isActivityResumed && nfcWriteMode) {
                    Log.d(TAG, "   → Activity confirmed RESUMED, enabling now...")
                    enableForegroundDispatch()
                } else {
                    Log.d(TAG, "   ⚠️ Activity not resumed or write mode cancelled (isActivityResumed=$isActivityResumed, nfcWriteMode=$nfcWriteMode)")
                }
            }, ACTIVITY_RESUME_DELAY_MS) // Delay to ensure activity is stable
        }
    }

    override fun onPause() {
        super.onPause()
        isActivityResumed = false
        Log.d(TAG, "🟡 onPause() - Activity is PAUSED (nfcWriteMode=$nfcWriteMode)")
        // IMPORTANT: Don't disable foreground dispatch if we're in write mode
        // This allows the dispatch to remain active even when activity loses focus
        if (!nfcWriteMode) {
            disableForegroundDispatch()
        } else {
            Log.d(TAG, "⚠️ Android: Keeping foreground dispatch active during PAUSED state")
        }
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "🔴 onStop() - Activity is STOPPED (nfcWriteMode=$nfcWriteMode)")
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update the intent

        Log.d(TAG, "🔔 onNewIntent() FIRED!")
        Log.d(TAG, "   Action: ${intent.action}")
        Log.d(TAG, "   nfcWriteMode: $nfcWriteMode")

        // Log new intent for debugging
        logIntentInfo(intent)

        // Handle ANY NFC-related intent when in write mode
        val isNfcAction = intent.action == NfcAdapter.ACTION_TAG_DISCOVERED ||
                          intent.action == NfcAdapter.ACTION_NDEF_DISCOVERED ||
                          intent.action == NfcAdapter.ACTION_TECH_DISCOVERED

        if (nfcWriteMode && isNfcAction) {
            Log.d(TAG, "📡 NFC action detected: ${intent.action}")
            val tag = intent.getParcelableExtra<Tag>(NfcAdapter.EXTRA_TAG)

            if (tag != null && pendingWriteData != null) {
                Log.d(TAG, "📡 NFC tag object found, attempting write...")
                val writeResult = writeToTag(tag, pendingWriteData!!)

                runOnUiThread {
                    if (writeResult.success) {
                        Log.d(TAG, "✅ Android: Successfully wrote to NFC tag (${writeResult.bytesWritten} bytes)")
                        writeMethodChannel?.invokeMethod("onWriteSuccess", mapOf(
                            "bytesWritten" to writeResult.bytesWritten,
                            "tagId" to writeResult.tagId,
                            "tagCapacity" to writeResult.tagCapacity
                        ))
                    } else {
                        Log.d(TAG, "❌ Android: Failed to write to NFC tag: ${writeResult.error}")
                        writeMethodChannel?.invokeMethod("onWriteError", writeResult.error)
                    }
                }

                // Reset write mode
                nfcWriteMode = false
                pendingWriteData = null
                disableForegroundDispatch()
            } else {
                Log.d(TAG, "⚠️ Android: Tag or pendingWriteData is null - tag=$tag, data=${pendingWriteData != null}")
            }
        } else if (isNfcIntent(intent)) {
            Log.d(TAG, "🎮 NFC detected but write mode is OFF (nfcWriteMode=$nfcWriteMode)")
        } else {
            Log.d(TAG, "ℹ️ Non-NFC intent received")
        }
    }

    private fun enableForegroundDispatch() {
        Log.d(TAG, "🔧 enableForegroundDispatch() called (nfcWriteMode=$nfcWriteMode)")
        Log.d(TAG, "   Current activity state: isActivityResumed=$isActivityResumed, isFinishing=$isFinishing")

        // CRITICAL: Foreground dispatch only works in RESUMED state
        if (!isActivityResumed) {
            Log.d(TAG, "❌ CRITICAL - Activity is NOT in RESUMED state!")
            Log.d(TAG, "   NFC foreground dispatch will NOT work until activity is RESUMED")
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
                    Log.d(TAG, "✅ NFC foreground dispatch ENABLED successfully (activity is RESUMED)")
                    Log.d(TAG, "📲 Ready to detect NFC tags - bring tag close to phone")
                } catch (e: Exception) {
                    Log.d(TAG, "❌ Failed to enable foreground dispatch: ${e.message}")
                    e.printStackTrace()
                }
            } else {
                Log.d(TAG, "⚠️ NFC adapter is disabled in device settings")
            }
        } ?: Log.d(TAG, "❌ NFC adapter is null")
    }

    private fun disableForegroundDispatch() {
        nfcAdapter?.let { adapter ->
            try {
                adapter.disableForegroundDispatch(this)
                Log.d(TAG, "🛑 NFC foreground dispatch disabled")
            } catch (e: Exception) {
                Log.d(TAG, "⚠️ Error disabling foreground dispatch: ${e.message}")
            }
        }
    }

    // Data class for write results
    data class WriteResult(
        val success: Boolean,
        val bytesWritten: Int = 0,
        val error: String? = null,
        val tagId: String? = null,
        val tagCapacity: Int? = null
    )

    private fun writeToTag(tag: Tag, data: String): WriteResult {
        try {
            // Check if this is a dual-payload write
            val isDualPayload = data.contains("\"type\":\"dual\"")
            val ndefMessage: NdefMessage

            if (isDualPayload) {
                Log.d(TAG, "")
                Log.d(TAG, "═══════════════════════════════════════════════════════")
                Log.d(TAG, "📋 DUAL-PAYLOAD DETECTED - Creating Multi-Record NDEF")
                Log.d(TAG, "═══════════════════════════════════════════════════════")

                // Parse JSON to extract vCard and URL
                val vcard = data.substringAfter("\"vcard\":\"").substringBefore("\",\"url\"").replace("\\\"", "\"")
                val url = data.substringAfter("\"url\":\"").substringBefore("\"}")

                Log.d(TAG, "")
                Log.d(TAG, "📇 RECORD 1: vCard (TEXT)")
                Log.d(TAG, "   ├─ Length: ${vcard.length} chars")
                Log.d(TAG, "   ├─ Format: vCard 3.0")
                Log.d(TAG, "   └─ Contains: Basic contact info (auto-saveable)")

                Log.d(TAG, "")
                Log.d(TAG, "🌐 RECORD 2: URL (URI)")
                Log.d(TAG, "   ├─ URL: $url")
                Log.d(TAG, "   ├─ Length: ${url.length} chars")
                Log.d(TAG, "   └─ Opens: Full digital card in browser")

                // Create two NDEF records
                Log.d(TAG, "")
                Log.d(TAG, "🔨 Creating NDEF records...")
                val vCardRecord = createMimeRecord("text/x-vcard", vcard)
                val urlRecord = createUrlRecord(url)
                ndefMessage = NdefMessage(arrayOf(vCardRecord, urlRecord))

                val totalBytes = ndefMessage.toByteArray().size
                Log.d(TAG, "✅ NDEF message created successfully")
                Log.d(TAG, "   ├─ Records: 2 (vCard + URL)")
                Log.d(TAG, "   ├─ Total size: $totalBytes bytes")
                Log.d(TAG, "   └─ Ready to write to tag")
                Log.d(TAG, "═══════════════════════════════════════════════════════")
                Log.d(TAG, "")
            } else if (data.startsWith("http://") || data.startsWith("https://")) {
                // URL-only fallback strategy
                Log.d(TAG, "")
                Log.d(TAG, "═══════════════════════════════════════════════════════")
                Log.d(TAG, "🌐 URL-ONLY WRITE - Fallback Strategy")
                Log.d(TAG, "═══════════════════════════════════════════════════════")
                Log.d(TAG, "")
                Log.d(TAG, "🌐 Single URL Record:")
                Log.d(TAG, "   ├─ URL: $data")
                Log.d(TAG, "   ├─ Length: ${data.length} chars")
                Log.d(TAG, "   └─ Opens: Full digital card in browser")
                Log.d(TAG, "")

                // Create single URL record
                val urlRecord = createUrlRecord(data)
                ndefMessage = NdefMessage(arrayOf(urlRecord))

                val totalBytes = ndefMessage.toByteArray().size
                Log.d(TAG, "✅ NDEF message created successfully")
                Log.d(TAG, "   ├─ Records: 1 (URL only)")
                Log.d(TAG, "   ├─ Total size: $totalBytes bytes")
                Log.d(TAG, "   └─ Ready to write to tag")
                Log.d(TAG, "═══════════════════════════════════════════════════════")
                Log.d(TAG, "")
            } else {
                // Legacy single text record (for backwards compatibility)
                val ndefRecord = createTextRecord(data)
                ndefMessage = NdefMessage(arrayOf(ndefRecord))
            }

            val messageSize = ndefMessage.toByteArray().size

            // Try to write using Ndef
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()

                // Log tag information for debugging
                val tagType = ndef.type
                val maxSize = ndef.maxSize

                // Extract tag ID from hardware
                val tagIdHex = tag.id.joinToString("") { "%02X".format(it) }
                Log.d(TAG, "📋 Tag detected: ID=$tagIdHex, Type=$tagType, Capacity=$maxSize bytes, Writable=${ndef.isWritable}")

                // Determine tag type based on capacity
                val tagName = when {
                    maxSize >= NTAG216_MAX_BYTES -> "NTAG216"
                    maxSize >= NTAG215_MAX_BYTES -> "NTAG215"
                    maxSize >= NTAG213_MAX_BYTES -> "NTAG213"
                    else -> "Unknown"
                }
                Log.d(TAG, "📋 Identified as: $tagName (${maxSize} bytes)")

                // Check if tag is writable
                if (!ndef.isWritable) {
                    Log.d(TAG, "❌ Tag is write-protected")
                    ndef.close()
                    return WriteResult(false, error = "This tag is write-protected and cannot be modified")
                }

                // Check if message fits
                if (maxSize < messageSize) {
                    val suggestedTag = when {
                        messageSize <= NTAG213_MAX_BYTES -> "NTAG213"
                        messageSize <= NTAG215_MAX_BYTES -> "NTAG215"
                        messageSize <= NTAG216_MAX_BYTES -> "NTAG216"
                        else -> "a larger"
                    }
                    Log.d(TAG, "❌ Message too large: $messageSize bytes > $maxSize bytes")
                    ndef.close()
                    return WriteResult(
                        false,
                        error = "Message too large ($messageSize bytes). This $tagName tag only has $maxSize bytes. Try using $suggestedTag tag."
                    )
                }

                // Warn if near capacity
                val capacityUsed = (messageSize.toFloat() / maxSize.toFloat() * 100).toInt()
                if (capacityUsed > 90) {
                    Log.d(TAG, "⚠️ Tag capacity nearly full: $capacityUsed% used ($messageSize/$maxSize bytes)")
                }

                // Write the message
                ndef.writeNdefMessage(ndefMessage)
                Log.d(TAG, "✅ NDEF message written successfully: $messageSize bytes ($capacityUsed% of $tagName capacity)")
                Log.d(TAG, "📤 Returning tag metadata: ID=$tagIdHex, Capacity=$maxSize bytes")
                ndef.close()
                return WriteResult(true, bytesWritten = messageSize, tagId = tagIdHex, tagCapacity = maxSize)
            }

            // Try to format the tag if it's not NDEF formatted
            val ndefFormatable = NdefFormatable.get(tag)
            if (ndefFormatable != null) {
                Log.d(TAG, "📋 Tag is not formatted, attempting to format...")
                ndefFormatable.connect()
                ndefFormatable.format(ndefMessage)
                Log.d(TAG, "✅ Tag formatted and message written: $messageSize bytes")
                ndefFormatable.close()
                return WriteResult(true, bytesWritten = messageSize)
            }

            Log.d(TAG, "❌ Tag is neither NDEF nor formattable")
            return WriteResult(false, error = "This tag is not NDEF compatible. Please use a compatible NFC tag (NTAG213, NTAG215, or NTAG216)")

        } catch (e: Exception) {
            Log.d(TAG, "❌ Android: Exception writing to tag: ${e.message}")
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

    private fun createUrlRecord(url: String): NdefRecord {
        // Create URL record using well-known URI type
        val uriBytes = url.toByteArray(Charset.forName("UTF-8"))
        return NdefRecord.createUri(url)
    }

    private fun createMimeRecord(mimeType: String, data: String): NdefRecord {
        // Create MIME type record for vCard
        val mimeBytes = mimeType.toByteArray(Charset.forName("US-ASCII"))
        val dataBytes = data.toByteArray(Charset.forName("UTF-8"))

        return NdefRecord(
            NdefRecord.TNF_MIME_MEDIA,
            mimeBytes,
            ByteArray(0), // Empty ID
            dataBytes
        )
    }

    private fun logIntentInfo(intent: Intent?) {
        if (intent == null) return

        Log.d(TAG, "📱 Intent Action: ${intent.action}")
        Log.d(TAG, "📱 Intent Data: ${intent.data}")
        Log.d(TAG, "📱 Intent Categories: ${intent.categories}")
        Log.d(TAG, "📱 Intent Extras: ${intent.extras?.keySet()}")

        if (isNfcIntent(intent)) {
            Log.d(TAG, "🏷️ This is an NFC intent!")
            val nfcData = extractNfcIntentData(intent)
            if (nfcData != null) {
                Log.d(TAG, "📄 NFC Data: ${nfcData.substring(0, nfcData.length.coerceAtMost(100))}...")
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
                Log.d(TAG, "📱 ACTION_VIEW URI: $uri")
                if (uri?.host == "tapcard.app") {
                    uri.toString()
                } else null
            }
            NfcAdapter.ACTION_NDEF_DISCOVERED -> {
                // Handle NDEF discovered intents
                val uri = intent.data
                Log.d(TAG, "📱 NDEF_DISCOVERED URI: $uri")

                // Also check raw NDEF records
                val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
                if (rawMessages != null) {
                    Log.d(TAG, "📋 Found ${rawMessages.size} NDEF messages")
                    // Extract text from NDEF records
                    // This is where we would parse actual NDEF data
                }

                uri?.toString()
            }
            NfcAdapter.ACTION_TAG_DISCOVERED -> {
                // Handle any NFC tag
                Log.d(TAG, "📱 TAG_DISCOVERED - checking for NDEF data")
                val tag = intent.getParcelableExtra<android.nfc.Tag>(NfcAdapter.EXTRA_TAG)

                if (tag != null) {
                    Log.d(TAG, "📋 Tag ID: ${tag.id.contentToString()}")
                    Log.d(TAG, "📋 Tag tech list: ${tag.techList.contentToString()}")
                }

                // For now, return null since we don't have NDEF data
                null
            }
            else -> {
                Log.d(TAG, "📱 Unknown action: ${intent.action}")
                null
            }
        }
    }
}
