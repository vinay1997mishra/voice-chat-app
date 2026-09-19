package ai.anamika.app.auth

import android.content.Context

data class PublicUserSession(
    val googleSubject: String,
    val email: String,
    val displayName: String?,
    val role: String,
    val sessionToken: String
) {
    fun isOwner(): Boolean = role == "OWNER"
}

class PublicSessionStore(context: Context) {
    private val prefs = context.getSharedPreferences("anamika_public_session", Context.MODE_PRIVATE)

    fun save(session: PublicUserSession) {
        prefs.edit()
            .putString(KEY_SUBJECT, session.googleSubject)
            .putString(KEY_EMAIL, session.email)
            .putString(KEY_NAME, session.displayName)
            .putString(KEY_ROLE, session.role)
            .putString(KEY_TOKEN, session.sessionToken)
            .apply()
    }

    fun current(): PublicUserSession? {
        val subject = prefs.getString(KEY_SUBJECT, null).orEmpty()
        val email = prefs.getString(KEY_EMAIL, null).orEmpty()
        val role = prefs.getString(KEY_ROLE, null).orEmpty()
        val token = prefs.getString(KEY_TOKEN, null).orEmpty()
        if (subject.isBlank() || role.isBlank() || token.isBlank()) return null
        return PublicUserSession(
            googleSubject = subject,
            email = email,
            displayName = prefs.getString(KEY_NAME, null),
            role = role,
            sessionToken = token
        )
    }

    fun clear() {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val KEY_SUBJECT = "google_subject"
        private const val KEY_EMAIL = "email"
        private const val KEY_NAME = "display_name"
        private const val KEY_ROLE = "role"
        private const val KEY_TOKEN = "session_token"
    }
}
