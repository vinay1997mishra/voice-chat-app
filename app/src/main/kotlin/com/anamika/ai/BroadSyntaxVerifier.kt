package com.anamika.ai

import io.xberg.tslp.android.ProcessConfig
import io.xberg.tslp.android.TreeSitterLanguagePack

object BroadSyntaxVerifier {
    data class Outcome(
        val available: Boolean,
        val clean: Boolean,
        val pack: String,
        val detail: String
    )

    @JvmStatic
    fun verify(language: String, source: String): Outcome {
        val grammar = normalize(language)
            ?: return Outcome(false, false, "Tree-sitter", "No grammar mapping for $language.")
        return try {
            val config = ProcessConfig(
                language = grammar,
                diagnostics = true,
                maxSourceBytes = 2_000_000,
                parseTimeoutMs = 5_000
            )
            val result = TreeSitterLanguagePack.process(source, config)
            val errors = result.metrics.errorCount
            if (errors == 0L) {
                Outcome(
                    true, true,
                    "Tree-sitter language pack 1.15.12 ($grammar)",
                    "Syntax tree parsed without error nodes."
                )
            } else {
                Outcome(
                    true, false,
                    "Tree-sitter language pack 1.15.12 ($grammar)",
                    "Parser found $errors syntax error node(s)."
                )
            }
        } catch (t: Throwable) {
            Outcome(
                false, false,
                "Tree-sitter language pack 1.15.12 ($grammar)",
                "Parser unavailable: ${t.javaClass.simpleName}: ${t.message ?: "unknown error"}"
            )
        }
    }

    @JvmStatic
    fun prefetchCore(): String {
        val languages = listOf("c", "cpp", "rust", "go", "c_sharp", "ruby", "php", "dart", "bash")
        return try {
            TreeSitterLanguagePack.prefetch(languages)
            "Syntax parser cache ready: ${languages.joinToString(", ")}"
        } catch (t: Throwable) {
            "Syntax parser prefetch incomplete: ${t.javaClass.simpleName}: ${t.message ?: "unknown error"}"
        }
    }

    private fun normalize(language: String): String? = when (language.lowercase()) {
        "c" -> "c"
        "c++", "cpp" -> "cpp"
        "rust" -> "rust"
        "go" -> "go"
        "c#", "csharp" -> "c_sharp"
        "ruby" -> "ruby"
        "php" -> "php"
        "dart" -> "dart"
        "shell", "bash" -> "bash"
        else -> null
    }
}
