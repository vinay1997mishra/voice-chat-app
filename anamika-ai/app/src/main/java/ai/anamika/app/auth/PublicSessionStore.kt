package ai.anamika.app.auth

import android.content.Context

data class PublicUserSession(
    val googleSubject: String,
    val email: String,
    val displayName: String?
)

class PublicSessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_public_session", Context.MODE_PRIVATE)

    fun save(session: PublicUserSession) {
        prefs.edit()
            .putString(KEY_SUBJECT, session.googleSubject)
            .putString(KEY_EMAIL, session.email)
            .putString(KEY_NAME, session.displayName)
            .apply()
    }

    fun current(): PublicUserSession? {
        val subject = prefs.getString(KEY_SUBJECT, null).orEmpty()
        val email = prefs.getString(KEY_EMAIL, null).orEmpty()
        if (subject.isBlank() || email.isBlank()) return null
        return PublicUserSession(
            googleSubject = subject,
            email = email,
            displayName = prefs.getString(KEY_NAME, null)
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val KEY_SUBJECT = "google_subject"
        private const val KEY_EMAIL = "email"
        private const val KEY_NAME = "display_name"
    }
}
