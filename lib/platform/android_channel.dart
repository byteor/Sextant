import 'package:flutter/services.dart';

/// Channel to the Android host activity (`MainActivity.kt`) for the network
/// facilities Dart can't provide from inside the app sandbox: interface prefix
/// lengths, the Wi-Fi multicast lock and non-forking ICMP pings.
const androidNetworkChannel = MethodChannel('net.ionjet.sextant/network');
