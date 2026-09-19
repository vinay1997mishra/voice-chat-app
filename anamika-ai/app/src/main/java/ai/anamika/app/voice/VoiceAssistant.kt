package ai.anamika.app.voice

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import java.util.Locale

class VoiceAssistant(
    private val activity: Activity,
    private val onText: (String) -> Unit,
    private val onError: (String) -> Unit
) : RecognitionListener, TextToSpeech.OnInitListener {

    private val recognizer = SpeechRecognizer.createSpeechRecognizer(activity)
    private val tts = TextToSpeech(activity, this)

    init {
        recognizer.setRecognitionListener(this)
    }

    fun listen() {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
        }
        recognizer.startListening(intent)
    }

    fun speak(text: String) {
        val hasHindi = text.any { it in '\u0900'..'\u097F' }
        tts.language = if (hasHindi) Locale("hi", "IN") else Locale.US
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "anamika-reply")
    }

    fun destroy() {
        recognizer.destroy()
        tts.shutdown()
    }

    override fun onReadyForSpeech(params: Bundle?) {}
    override fun onBeginningOfSpeech() {}
    override fun onRmsChanged(rmsdB: Float) {}
    override fun onBufferReceived(buffer: ByteArray?) {}
    override fun onEndOfSpeech() {}
    override fun onError(error: Int) = onError("Voice recognition error: $error")
    override fun onPartialResults(partialResults: Bundle?) {}
    override fun onEvent(eventType: Int, params: Bundle?) {}

    override fun onResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val best = matches?.firstOrNull().orEmpty()
        if (best.isNotBlank()) onText(best) else onError("No speech detected")
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) tts.language = Locale.US
    }
}
