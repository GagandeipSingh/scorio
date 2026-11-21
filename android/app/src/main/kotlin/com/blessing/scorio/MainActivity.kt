package com.blessing.scorio

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Edge to edge, as in Breeze: the app draws under the status and
        // navigation bars, which stay visible and transparent. Flutter pads
        // the content by the system insets, so nothing sits under the bar.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        // Flutter's PlatformPlugin rewrites the decor flags on every resume to
        // LAYOUT_STABLE | LAYOUT_FULLSCREEN, dropping LAYOUT_HIDE_NAVIGATION
        // below Android 10 (its edge-to-edge mode returns early there). The
        // app then stopped above an opaque white navigation bar. Put it back.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val decor = window.decorView
            @Suppress("DEPRECATION")
            decor.systemUiVisibility = decor.systemUiVisibility or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                android.view.View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            // Then ask for the insets again once the window is laid out.
            // Below Android 11 Flutter guesses "keyboard" when the bottom
            // inset is 18% or more of the root view height, and on the
            // first pass that height is still 0: the 48 dp nav bar reads
            // as a keyboard and the Scaffold shrinks, clipping the page
            // above an empty strip. Light mode hid it (setting the light
            // nav-icon flag re-sends the insets); dark kept the wrong value.
            decor.post { decor.requestApplyInsets() }
        }
    }
}
