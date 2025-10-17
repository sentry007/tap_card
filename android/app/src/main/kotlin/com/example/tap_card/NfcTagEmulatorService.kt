package com.example.tap_card

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import java.util.Arrays

/**
 * Custom HCE service that emulates an NFC Forum Type 4 Tag with NDEF support.
 * Compatible with both iOS CoreNFC and Android NFC readers.
 *
 * Implements the NFC Forum Type 4 Tag Operation specification:
 * - Application selection (AID: D2760000850101)
 * - Capability Container (CC) file access
 * - NDEF message file access
 */
class NfcTagEmulatorService : HostApduService() {

    /**
     * Enum to track which file is currently selected.
     * This is needed because READ BINARY commands don't specify the file ID,
     * so we need to remember what was last selected.
     */
    enum class SelectedFile {
        NONE,                   // No file selected yet
        CAPABILITY_CONTAINER,   // CC file (E103) selected
        NDEF_FILE              // NDEF data file (E104) selected
    }

    /**
     * Currently selected file for READ BINARY operations.
     * Reset to NONE on deactivation.
     */
    private var selectedFile: SelectedFile = SelectedFile.NONE

    companion object {
        private const val TAG = "TapCard.HCE"

        // ============= APDU Command Patterns =============

        // SELECT commands (CLA INS P1 P2 Lc Data)
        private val SELECT_NDEF_APPLICATION = byteArrayOf(
            0x00, 0xA4.toByte(), 0x04, 0x00, 0x07,
            0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01
        )

        private val SELECT_CAPABILITY_CONTAINER = byteArrayOf(
            0x00, 0xA4.toByte(), 0x00, 0x0C, 0x02,
            0xE1.toByte(), 0x03
        )

        private val SELECT_NDEF_FILE = byteArrayOf(
            0x00, 0xA4.toByte(), 0x00, 0x0C, 0x02,
            0xE1.toByte(), 0x04
        )

        // ============= Response Codes =============

        private val STATUS_SUCCESS = byteArrayOf(0x90.toByte(), 0x00)
        private val STATUS_FAILED = byteArrayOf(0x6A.toByte(), 0x82.toByte()) // File not found
        private val STATUS_UNKNOWN = byteArrayOf(0x6D.toByte(), 0x00) // Unknown instruction

        // ============= Capability Container =============

        /**
         * Capability Container (CC) structure:
         * - Byte 0-1: CCLEN (0x000F = 15 bytes)
         * - Byte 2: Mapping Version (0x20 = version 2.0)
         * - Byte 3-4: MLe (Maximum R-APDU data size = 0x003B = 59 bytes)
         * - Byte 5-6: MLc (Maximum C-APDU data size = 0x0034 = 52 bytes)
         * - Byte 7: NDEF File Control TLV - Tag (0x04)
         * - Byte 8: NDEF File Control TLV - Length (0x06)
         * - Byte 9-10: File Identifier (0xE104)
         * - Byte 11-12: Maximum NDEF size (0x0800 = 2048 bytes)
         * - Byte 13: NDEF read access (0x00 = granted)
         * - Byte 14: NDEF write access (0xFF = denied)
         */
        private val CAPABILITY_CONTAINER = byteArrayOf(
            0x00, 0x0F,                          // CCLEN = 15 bytes
            0x20,                                 // Version 2.0
            0x00, 0x3B,                          // MLe = 59 bytes
            0x00, 0x34,                          // MLc = 52 bytes
            0x04, 0x06,                          // NDEF File Control TLV (Tag + Length)
            0xE1.toByte(), 0x04,                 // File ID = E104
            0x08, 0x00,                          // Max NDEF size = 2048 bytes
            0x00,                                 // Read access granted
            0xFF.toByte()                        // Write access denied
        )

        // ============= Shared State =============

        /**
         * The NDEF message to be served to NFC readers.
         * Set via setNdefMessage() before starting emulation.
         */
        @Volatile
        private var ndefMessage: ByteArray? = null

        /**
         * Set the NDEF message that will be served to NFC readers.
         * Must be called before the service receives any APDU commands.
         */
        fun setNdefMessage(message: ByteArray) {
            ndefMessage = message
            Log.d(TAG, "✅ NDEF message set (${message.size} bytes)")
            Log.d(TAG, "   📦 Hex: ${bytesToHex(message.take(32).toByteArray())}${if (message.size > 32) "..." else ""}")
        }

        /**
         * Clear the NDEF message (optional cleanup).
         */
        fun clearNdefMessage() {
            ndefMessage = null
            Log.d(TAG, "🗑️ NDEF message cleared")
        }

        // ============= Utility Methods =============

        private fun bytesToHex(bytes: ByteArray): String {
            return bytes.joinToString(" ") { "%02X".format(it) }
        }

        private fun startsWith(array: ByteArray, prefix: ByteArray): Boolean {
            if (array.size < prefix.size) return false
            return Arrays.equals(array.copyOf(prefix.size), prefix)
        }

        private fun concatArrays(vararg arrays: ByteArray): ByteArray {
            var totalLength = 0
            for (array in arrays) {
                totalLength += array.size
            }
            val result = ByteArray(totalLength)
            var offset = 0
            for (array in arrays) {
                System.arraycopy(array, 0, result, offset, array.size)
                offset += array.size
            }
            return result
        }
    }

    // ============= Service Lifecycle =============

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "🚀 NFC Tag Emulator Service created")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 NFC Tag Emulator Service destroyed")
    }

    override fun onDeactivated(reason: Int) {
        // Reset file selection state
        selectedFile = SelectedFile.NONE

        val reasonStr = when (reason) {
            DEACTIVATION_LINK_LOSS -> "LINK_LOSS"
            DEACTIVATION_DESELECTED -> "DESELECTED"
            else -> "UNKNOWN ($reason)"
        }
        Log.d(TAG, "📡 Deactivated: $reasonStr")
    }

    // ============= APDU Command Processing =============

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        Log.d(TAG, "📨 Received APDU: ${bytesToHex(commandApdu)}")

        // Check if NDEF message is set
        if (ndefMessage == null) {
            Log.e(TAG, "❌ No NDEF message set! Call setNdefMessage() first")
            return STATUS_FAILED
        }

        // Handle SELECT NDEF Application (with or without Le byte)
        if (startsWith(commandApdu, SELECT_NDEF_APPLICATION)) {
            Log.d(TAG, "✅ SELECT NDEF Application → OK")
            return STATUS_SUCCESS
        }

        // Handle SELECT Capability Container (with or without Le byte)
        if (startsWith(commandApdu, SELECT_CAPABILITY_CONTAINER)) {
            Log.d(TAG, "✅ SELECT Capability Container → OK")
            selectedFile = SelectedFile.CAPABILITY_CONTAINER
            return STATUS_SUCCESS
        }

        // Handle SELECT NDEF File (with or without Le byte)
        if (startsWith(commandApdu, SELECT_NDEF_FILE)) {
            Log.d(TAG, "✅ SELECT NDEF File → OK")
            selectedFile = SelectedFile.NDEF_FILE
            return STATUS_SUCCESS
        }

        // Handle READ BINARY - context-aware based on selected file
        if (commandApdu.size >= 5 &&
            commandApdu[0] == 0x00.toByte() &&
            commandApdu[1] == 0xB0.toByte()) {

            val offset = ((commandApdu[2].toInt() and 0xFF) shl 8) or (commandApdu[3].toInt() and 0xFF)
            val length = commandApdu[4].toInt() and 0xFF

            when (selectedFile) {
                SelectedFile.CAPABILITY_CONTAINER -> {
                    // Reading from Capability Container file
                    Log.d(TAG, "✅ READ BINARY CC (offset=$offset, length=$length) → Returning CC")

                    val response = if (offset == 0) {
                        // Read from beginning
                        if (length >= CAPABILITY_CONTAINER.size) {
                            concatArrays(CAPABILITY_CONTAINER, STATUS_SUCCESS)
                        } else {
                            concatArrays(CAPABILITY_CONTAINER.copyOf(length), STATUS_SUCCESS)
                        }
                    } else if (offset < CAPABILITY_CONTAINER.size) {
                        // Read from middle
                        val remainingData = CAPABILITY_CONTAINER.size - offset
                        val actualLength = minOf(length, remainingData)
                        val data = CAPABILITY_CONTAINER.copyOfRange(offset, offset + actualLength)
                        concatArrays(data, STATUS_SUCCESS)
                    } else {
                        // Invalid offset
                        STATUS_FAILED
                    }

                    return response
                }

                SelectedFile.NDEF_FILE -> {
                    // Reading from NDEF data file
                    if (offset == 0 && length == 2) {
                        // Reading NLEN (NDEF length prefix)
                        val messageSize = ndefMessage!!.size
                        val nlen = byteArrayOf(
                            ((messageSize shr 8) and 0xFF).toByte(),
                            (messageSize and 0xFF).toByte()
                        )

                        Log.d(TAG, "✅ READ BINARY NDEF Length → $messageSize bytes (NLEN=${bytesToHex(nlen)})")
                        return concatArrays(nlen, STATUS_SUCCESS)

                    } else if (offset >= 2) {
                        // Reading NDEF data (offset includes 2-byte NLEN prefix)
                        val dataOffset = offset - 2

                        if (dataOffset < ndefMessage!!.size) {
                            val remainingData = ndefMessage!!.size - dataOffset
                            val actualLength = minOf(length, remainingData)
                            val data = ndefMessage!!.copyOfRange(dataOffset, dataOffset + actualLength)

                            Log.d(TAG, "✅ READ BINARY NDEF Data (offset=$offset, length=$actualLength) → Returning NDEF")
                            Log.d(TAG, "   📤 Bytes: ${bytesToHex(data.take(16).toByteArray())}${if (data.size > 16) "..." else ""}")

                            return concatArrays(data, STATUS_SUCCESS)
                        }
                    }

                    Log.w(TAG, "⚠️ READ BINARY NDEF invalid offset=$offset length=$length")
                    return STATUS_FAILED
                }

                SelectedFile.NONE -> {
                    Log.w(TAG, "⚠️ READ BINARY with no file selected (offset=$offset, length=$length)")
                    return STATUS_FAILED
                }
            }
        }

        // Unknown command
        Log.w(TAG, "⚠️ Unknown APDU command: ${bytesToHex(commandApdu)}")
        return STATUS_UNKNOWN
    }
}
