package ai.anamika.app.core

import org.junit.Assert.assertTrue
import org.junit.Test

class CommandRouterTest {
    private val router = CommandRouter()

    @Test
    fun updateCommandIsDetected() {
        assertTrue(router.parse("Anamika update check karo") is Command.CheckUpdate)
    }

    @Test
    fun rememberCommandIsDetected() {
        assertTrue(router.parse("remember buy milk") is Command.Remember)
    }

    @Test
    fun linkCommandIsDetected() {
        assertTrue(router.parse("learn https://example.com/video") is Command.LearnFromLink)
    }
}
