import 'dart:io';

import 'package:flutter/services.dart';

import 'android_channel.dart';

/// Android drops inbound multicast packets (mDNS, SSDP replies) to save power
/// unless the app holds a `WifiManager.MulticastLock`. This is a reference-
/// counted wrapper around it: every [acquire] must be paired with a [release].
/// A no-op on every other platform.
class MulticastLock {
  const MulticastLock();

  Future<void> acquire() => _invoke('acquireMulticastLock');

  Future<void> release() => _invoke('releaseMulticastLock');

  Future<void> _invoke(String method) async {
    if (!Platform.isAndroid) return;
    try {
      await androidNetworkChannel.invokeMethod<void>(method);
    } on PlatformException {
      // Best-effort: discovery just returns fewer results without the lock.
    } on MissingPluginException {
      // Same: no host-side handler (e.g. under test).
    }
  }
}
