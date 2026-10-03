package cc.saidian.saydian_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.location.Geocoder
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.Executors

/** Foreground, bounded network location for weather on phones without a GPS fix. */
class WeatherLocationProvider(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var cancel: (() -> Unit)? = null

    @Suppress("DEPRECATION")
    fun city(name: String, result: MethodChannel.Result) {
        if (name.isBlank() || name.length > 80 || !Geocoder.isPresent()) { result.success(null); return }
        val executor = Executors.newSingleThreadExecutor()
        var completed = false
        val timeout = Runnable { if (!completed) { completed = true; result.success(null) } }
        handler.postDelayed(timeout, 8_000)
        executor.execute {
            val address = try { Geocoder(context, Locale.getDefault()).getFromLocationName(name, 1)?.firstOrNull() } catch (_: Exception) { null }
            handler.post {
                if (!completed) {
                    completed = true
                    handler.removeCallbacks(timeout)
                    result.success(address?.let { mapOf("latitude" to it.latitude, "longitude" to it.longitude, "city" to (it.locality ?: name)) })
                }
            }
            executor.shutdown()
        }
    }

    fun close() { cancel?.invoke() }

    @Suppress("DEPRECATION")
    fun current(result: MethodChannel.Result) {
        close()
        val manager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val permitted = context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (manager == null || !permitted) { result.success(null); return }
        var listener: LocationListener? = null
        var timeout: Runnable? = null
        var finished = false
        fun fresh(location: Location): Boolean = System.currentTimeMillis() - location.time in 0..600_000
        fun finish(location: Location?) {
            if (finished) return
            finished = true
            listener?.let { try { manager.removeUpdates(it) } catch (_: SecurityException) {} }
            timeout?.let { handler.removeCallbacks(it) }
            cancel = null
            result.success(location?.let { mapOf("latitude" to it.latitude, "longitude" to it.longitude, "timestamp" to it.time) })
        }
        try {
            if (!manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) { finish(null); return }
            val cached = manager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (cached != null && fresh(cached)) { finish(cached); return }
            listener = object : LocationListener {
                override fun onLocationChanged(location: Location) { if (fresh(location)) finish(location) }
                override fun onProviderDisabled(provider: String) { finish(null) }
                override fun onProviderEnabled(provider: String) {}
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            }
            timeout = Runnable { finish(null) }
            cancel = { finish(null) }
            handler.postDelayed(timeout!!, 8_000)
            manager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0L, 0f, listener!!, Looper.getMainLooper())
        } catch (_: Exception) { finish(null) }
    }
}
