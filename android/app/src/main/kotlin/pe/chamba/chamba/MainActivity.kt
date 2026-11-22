package pe.chamba.chamba

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.media.MediaRecorder
import android.media.MediaPlayer
import java.io.File

class MainActivity : FlutterActivity() {
    private var cameraResult: MethodChannel.Result? = null
    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null
    private var player: MediaPlayer? = null
    private var playingFile: File? = null
    private var playingResult: MethodChannel.Result? = null

    private fun cancelRecording() {
        try { recorder?.stop() } catch (_: Exception) {}
        recorder?.release(); recorder = null
        recordingFile?.delete(); recordingFile = null
    }
    private fun stopPlayback() {
        player?.release(); player = null
        playingFile?.delete(); playingFile = null
        playingResult?.success(null); playingResult = null
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chamba/camera_permissions").setMethodCallHandler { call, result ->
            when (call.method) {
                "request", "requestMicrophone" -> {
                    val permission = if (call.method == "request") Manifest.permission.CAMERA else Manifest.permission.RECORD_AUDIO
                    if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
                        result.success("granted")
                    } else if (cameraResult != null) {
                        result.success("denied")
                    } else {
                        cameraResult = result
                        requestPermissions(arrayOf(permission), if (call.method == "request") 781 else 782)
                    }
                }
                "startAudio" -> {
                    try {
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) throw SecurityException()
                        cancelRecording(); stopPlayback()
                        val file = File.createTempFile("chamba_recording_", ".aac", cacheDir)
                        recordingFile = file
                        @Suppress("DEPRECATION")
                        val capture = MediaRecorder()
                        recorder = capture
                        capture.setAudioSource(MediaRecorder.AudioSource.MIC)
                        capture.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
                        capture.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
                        capture.setAudioChannels(1)
                        capture.setAudioSamplingRate(16000)
                        capture.setAudioEncodingBitRate(32000)
                        capture.setMaxDuration(31000)
                        capture.setMaxFileSize(190000)
                        capture.setOutputFile(file.absolutePath)
                        capture.prepare(); capture.start()
                        result.success(null)
                    } catch (_: Exception) {
                        cancelRecording(); result.error("audio_recording", "No se pudo iniciar la grabación", null)
                    }
                }
                "stopAudioRecording" -> {
                    try {
                        val capture = recorder ?: throw IllegalStateException()
                        try { capture.stop() } catch (_: Exception) {}
                        capture.release(); recorder = null
                        val data = recordingFile?.readBytes() ?: throw IllegalStateException()
                        recordingFile?.delete(); recordingFile = null
                        if (data.size < 7 || data.size > 200000) throw IllegalStateException()
                        result.success(data)
                    } catch (_: Exception) {
                        cancelRecording(); result.error("audio_recording", "No se pudo recuperar el audio", null)
                    }
                }
                "cancelAudio" -> { cancelRecording(); result.success(null) }
                "stopAudioPlayback" -> { stopPlayback(); result.success(null) }
                "playAudio" -> {
                    try {
                        stopPlayback()
                        val data = call.argument<ByteArray>("bytes") ?: throw IllegalArgumentException()
                        if (data.size > 200000 || data.size < 7) throw IllegalArgumentException()
                        val file = File.createTempFile("chamba_playback_", ".aac", cacheDir)
                        file.writeBytes(data); playingFile = file
                        val playback = MediaPlayer(); player = playback; playingResult = result
                        playback.setDataSource(file.absolutePath)
                        playback.setOnCompletionListener { stopPlayback() }
                        playback.setOnErrorListener { _, _, _ ->
                            playingResult?.error("audio_playback", "No se pudo reproducir el audio", null)
                            playingResult = null; stopPlayback(); true
                        }
                        playback.prepare(); playback.start()
                    } catch (_: Exception) {
                        if (playingResult != null) { playingResult?.error("audio_playback", "No se pudo reproducir el audio", null); playingResult = null }
                        else { result.error("audio_playback", "No se pudo reproducir el audio", null) }
                        stopPlayback()
                    }
                }
                "settings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 781 || requestCode == 782) {
            val permission = if (requestCode == 781) Manifest.permission.CAMERA else Manifest.permission.RECORD_AUDIO
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            cameraResult?.success(if (granted) "granted" else if (grantResults.isNotEmpty() && !shouldShowRequestPermissionRationale(permission)) "blocked" else "denied")
            cameraResult = null
        }
    }
    override fun onStop() {
        cancelRecording(); stopPlayback()
        super.onStop()
    }
    override fun onDestroy() {
        cancelRecording(); stopPlayback()
        super.onDestroy()
    }
}
