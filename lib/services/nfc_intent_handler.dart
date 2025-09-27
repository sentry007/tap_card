import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/routes.dart';

/// Service for handling incoming NFC intents when the app is launched
class NFCIntentHandler {
  static const MethodChannel _channel = MethodChannel('app.tapcard/nfc_intent');
  static StreamController<String>? _intentStreamController;
  static bool _isInitialized = false;

  /// Initialize the NFC intent handler
  static Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    try {
      // Set up method channel for receiving Android intents
      _channel.setMethodCallHandler(_handleMethodCall);

      // Create stream controller for intent data
      _intentStreamController = StreamController<String>.broadcast();

      // Listen for intent data and route accordingly
      _intentStreamController!.stream.listen((intentData) {
        _handleNFCIntent(context, intentData);
      });

      // Check if app was launched with an intent
      await _checkLaunchIntent(context);

      _isInitialized = true;
      print('✅ NFC Intent Handler initialized');

    } catch (e) {
      print('❌ Failed to initialize NFC Intent Handler: $e');
    }
  }

  /// Handle incoming method calls from Android
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNewIntent':
        final String? intentData = call.arguments as String?;
        if (intentData != null) {
          print('📱 New NFC intent received: ${intentData.substring(0, intentData.length.clamp(0, 100))}...');
          _intentStreamController?.add(intentData);
        }
        break;
      case 'getInitialIntent':
        // This is called when checking launch intent
        return call.arguments as String?;
      default:
        print('⚠️ Unknown method call: ${call.method}');
    }
  }

  /// Check if the app was launched with an NFC intent
  static Future<void> _checkLaunchIntent(BuildContext context) async {
    try {
      final String? launchIntent = await _channel.invokeMethod('getInitialIntent');

      if (launchIntent != null && launchIntent.isNotEmpty) {
        print('🚀 App launched with NFC intent: ${launchIntent.substring(0, launchIntent.length.clamp(0, 100))}...');

        // Small delay to ensure router is ready
        await Future.delayed(const Duration(milliseconds: 500));

        if (context.mounted) {
          _handleNFCIntent(context, launchIntent);
        }
      } else {
        print('ℹ️ No NFC launch intent detected - normal app startup');
      }
    } catch (e) {
      print('❌ Error checking launch intent: $e');
    }
  }

  /// Handle NFC intent data - DISABLED for user control
  static void _handleNFCIntent(BuildContext context, String intentData) {
    // DISABLED: No automatic navigation for NFC intents
    // User controls sharing via manual FAB button tap only
    print('📱 NFC intent detected but auto-navigation disabled: ${intentData.substring(0, 50)}...');
    print('🎮 User controls sharing manually via FAB button');
  }

  /// Dispose resources
  static void dispose() {
    _intentStreamController?.close();
    _intentStreamController = null;
    _isInitialized = false;
  }
}