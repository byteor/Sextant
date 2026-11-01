package net.ionjet.sextant

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.Inet4Address
import java.net.InetAddress
import java.util.concurrent.Executors
import java.net.NetworkInterface

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    // Pings block for up to the timeout, so they run off the main thread.
    private val pingExecutor = Executors.newFixedThreadPool(64)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart's NetworkInterface doesn't expose the netmask, and the `ip`
        // binary isn't usable from inside the app sandbox, so read the IPv4
        // prefix length from java.net.NetworkInterface instead.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "net.ionjet.sextant/network")
            .setMethodCallHandler { call, result ->
                if (call.method == "acquireMulticastLock") {
                    // Without this, Android filters out inbound multicast
                    // (mDNS / SSDP replies). Reference-counted, so overlapping
                    // acquire/release pairs from mDNS and SSDP nest correctly.
                    if (multicastLock == null) {
                        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                        multicastLock = wifi.createMulticastLock("sextant-multicast")
                    }
                    multicastLock?.acquire()
                    result.success(null)
                } else if (call.method == "releaseMulticastLock") {
                    multicastLock?.takeIf { it.isHeld }?.release()
                    result.success(null)
                } else if (call.method == "ping") {
                    val host = call.argument<String>("host")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 1000
                    pingExecutor.execute {
                        val start = System.nanoTime()
                        val alive = try {
                            InetAddress.getByName(host).isReachable(timeoutMs)
                        } catch (e: Exception) {
                            false
                        }
                        val rttMs = (System.nanoTime() - start) / 1_000_000.0
                        runOnUiThread { result.success(if (alive) rttMs else -1.0) }
                    }
                } else if (call.method == "ipv4PrefixLength") {
                    val name = call.arguments as? String
                    val prefix = NetworkInterface.getByName(name)
                        ?.interfaceAddresses
                        ?.firstOrNull { it.address is Inet4Address }
                        ?.networkPrefixLength
                    result.success(prefix?.toInt())
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        pingExecutor.shutdownNow()
        // Reference-counted: drop every outstanding hold, not just one.
        multicastLock?.let { lock -> while (lock.isHeld) lock.release() }
        super.onDestroy()
    }
}
