package com.example.myapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.lifecycle.LifecycleService
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.max

class RecordingForegroundService : LifecycleService() {

    private var recorderJob: Job? = null
    private var limitJob: Job? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var recognizer: Recognizer? = null
    private var voskModel: Model? = null
    private val buffer = CircularAudioBuffer(AudioUtils.SAMPLE_RATE * CLIP_DURATION_SECONDS)
    private val detectionTimestamps = ConcurrentHashMap<String, Long>()
    private val storage by lazy { RecordingStorage(applicationContext) }
    private var isPremiumUser: Boolean = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        isPremiumUser = intent?.getBooleanExtra(EXTRA_IS_PREMIUM, false) ?: false
        startForeground(NOTIFICATION_ID, createNotification("Фоновое прослушивание активно"))
        acquireWakeLock()
        scheduleLimitIfNeeded()
        startListening()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        stopListening()
        limitJob?.cancel()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun startListening() {
        if (recorderJob != null) return

        recorderJob = lifecycleScope.launch(Dispatchers.Default) {
            val model = loadModel() ?: run {
                notifyModelMissing()
                return@launch
            }
            voskModel = model
            recognizer = Recognizer(model, AudioUtils.SAMPLE_RATE.toFloat())

            val audioRecord = createAudioRecord() ?: run {
                notifyRecordingIssue("Не удалось инициализировать микрофон")
                return@launch
            }

            try {
                audioRecord.startRecording()
                val shortBuffer = ShortArray(CHUNK_SIZE)
                while (isActive) {
                    val read = audioRecord.read(shortBuffer, 0, shortBuffer.size)
                    if (read > 0) {
                        buffer.write(shortBuffer, read)
                        val bytes = AudioUtils.shortArrayToLittleEndianBytes(shortBuffer, read)
                        processFrame(bytes)
                    }
                }
            } finally {
                audioRecord.stop()
                audioRecord.release()
                recognizer?.close()
                voskModel?.close()
                recognizer = null
                voskModel = null
            }
        }
    }

    private fun stopListening() {
        recorderJob?.cancel()
        recorderJob = null
    }

    private fun processFrame(pcmBytes: ByteArray) {
        val recognizer = recognizer ?: return
        val hasResult = recognizer.acceptWaveForm(pcmBytes, pcmBytes.size)
        val json = if (hasResult) recognizer.result else recognizer.partialResult
        handleRecognizerResult(json)
    }

    private fun handleRecognizerResult(json: String) {
        if (json.isBlank()) return
        val payload = runCatching { JSONObject(json) }.getOrNull() ?: return
        val text = payload.optString("text")
            .takeIf { it.isNotBlank() }
            ?: payload.optString("partial")
        if (text.isBlank()) return

        val keyword = KEYWORDS.firstOrNull { text.contains(it, ignoreCase = true) } ?: return
        if (!shouldTrigger(keyword)) return

        val samples = buffer.snapshot()
        if (samples.isEmpty()) return

        val durationMs = samples.size * 1000L / AudioUtils.SAMPLE_RATE
        val wavBytes = AudioUtils.shortArrayToWavBytes(samples)
        val metadata = storage.saveClip(keyword, wavBytes, durationMs)
        detectionTimestamps[keyword] = System.currentTimeMillis()
        notifyDetection(metadata)
    }

    private fun shouldTrigger(keyword: String): Boolean {
        val now = System.currentTimeMillis()
        val last = detectionTimestamps[keyword] ?: return true
        return (now - last) > DETECTION_COOLDOWN_MS
    }

    private fun notifyDetection(metadata: RecordingMetadata) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Обнаружен мат: ${metadata.keyword}")
            .setContentText("Запись сохранена (${metadata.durationMs / 1000}s)")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(mainPendingIntent())
            .build()

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun notifyModelMissing() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Модель Vosk не найдена")
            .setContentText("Скачайте модель в ${File(filesDir, MODEL_DIR)}")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(mainPendingIntent())
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun notifyRecordingIssue(message: String) {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Ошибка записи")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(mainPendingIntent())
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, notification)
    }

    private fun mainPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createNotification(message: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(message)
            .setContentText(if (isPremiumUser) "Премиум режим" else "Обычный режим (до 3 часов)")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(mainPendingIntent())
            .build()

    private fun createAudioRecord(): AudioRecord? {
        val minBuffer = AudioRecord.getMinBufferSize(
            AudioUtils.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )

        if (minBuffer == AudioRecord.ERROR || minBuffer == AudioRecord.ERROR_BAD_VALUE) {
            return null
        }

        val bufferSize = max(minBuffer, CHUNK_SIZE * 2)

        return AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            AudioUtils.SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize
        )
    }

    private fun scheduleLimitIfNeeded() {
        limitJob?.cancel()
        if (isPremiumUser) return
        limitJob = lifecycleScope.launch {
            delay(NON_PREMIUM_LIMIT_MS)
            notifyRecordingIssue("Лимит 3 часа достигнут. Перезапустите запись.")
            stopSelf()
        }
    }

    private fun acquireWakeLock() {
        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = manager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "AIStudyMate::DetectorWakeLock"
        ).apply {
            setReferenceCounted(false)
            if (isPremiumUser) {
                acquire()
            } else {
                acquire(NON_PREMIUM_LIMIT_MS)
            }
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    private fun loadModel(): Model? {
        val modelDir = File(filesDir, MODEL_DIR)
        if (!modelDir.exists()) {
            return null
        }
        return runCatching { Model(modelDir.absolutePath) }
            .onFailure { notifyModelMissing() }
            .getOrNull()
    }

    companion object {
        private const val CHANNEL_ID = "recording_channel"
        private const val NOTIFICATION_ID = 1001
        private const val MODEL_DIR = "vosk-model"
        private const val CHUNK_SIZE = 2048
        private const val CLIP_DURATION_SECONDS = 3
        private const val DETECTION_COOLDOWN_MS = 5_000L
        private const val NON_PREMIUM_LIMIT_MS = 3 * 60 * 60 * 1000L // 3 часа
        private val KEYWORDS = listOf("блять", "бля", "сука", "хуй", "ебат", "ебать", "пизда")
        private const val EXTRA_IS_PREMIUM = "extra_is_premium"

        fun startService(context: Context, isPremium: Boolean) {
            val intent = Intent(context, RecordingForegroundService::class.java).apply {
                putExtra(EXTRA_IS_PREMIUM, isPremium)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopService(context: Context) {
            val intent = Intent(context, RecordingForegroundService::class.java)
            context.stopService(intent)
        }
    }
}
