package cn.tia.comic

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.os.Handler
import io.flutter.plugin.common.EventChannel
import android.os.Looper
import android.view.KeyEvent

class MainActivity: FlutterActivity() {
    private val uiThreadHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        //
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "volume_button")
            .setStreamHandler(volumeStreamHandler)
        // super
        super.configureFlutterEngine(flutterEngine)
    }

    // volume_buttons
    private var volumeEvents: EventChannel.EventSink? = null

    private val volumeStreamHandler = object : EventChannel.StreamHandler {

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            volumeEvents = events
        }

        override fun onCancel(arguments: Any?) {
            volumeEvents = null
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        volumeEvents?.let {
            if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
                uiThreadHandler.post {
                    it.success("DOWN")
                }
                return true
            }
            if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                uiThreadHandler.post {
                    it.success("UP")
                }
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
