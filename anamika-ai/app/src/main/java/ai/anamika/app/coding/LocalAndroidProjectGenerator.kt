package ai.anamika.app.coding

import ai.anamika.app.workspace.WorkspaceFileManager

data class GeneratedProject(
    val workspace: String,
    val filesWritten: Int,
    val summary: String
)

class LocalAndroidProjectGenerator(
    private val files: WorkspaceFileManager
) {
    fun generate(workspace: String, goal: String): GeneratedProject {
        require(goal.isNotBlank()) { "App requirement empty hai." }

        val safeWorkspace = workspace
            .lowercase()
            .replace(Regex("[^a-z0-9_]"), "_")
            .trim('_')
            .ifBlank { "generated_app" }

        val packageName = "ai.anamika.generated.$safeWorkspace"
        val appName = titleFromGoal(goal)

        val projectFiles = linkedMapOf(
            "settings.gradle.kts" to """
                pluginManagement {
                    repositories {
                        google()
                        mavenCentral()
                        gradlePluginPortal()
                    }
                }

                dependencyResolutionManagement {
                    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
                    repositories {
                        google()
                        mavenCentral()
                    }
                }

                rootProject.name = "${escapeKotlin(appName)}"
                include(":app")
            """.trimIndent(),

            "build.gradle.kts" to """
                plugins {
                    id("com.android.application") version "8.7.3" apply false
                    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
                }
            """.trimIndent(),

            "gradle.properties" to """
                org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
                android.useAndroidX=true
                kotlin.code.style=official
            """.trimIndent(),

            "app/build.gradle.kts" to """
                plugins {
                    id("com.android.application")
                    id("org.jetbrains.kotlin.android")
                }

                android {
                    namespace = "$packageName"
                    compileSdk = 35

                    defaultConfig {
                        applicationId = "$packageName"
                        minSdk = 26
                        targetSdk = 35
                        versionCode = 1
                        versionName = "1.0"
                    }

                    compileOptions {
                        sourceCompatibility = JavaVersion.VERSION_17
                        targetCompatibility = JavaVersion.VERSION_17
                    }

                    kotlinOptions {
                        jvmTarget = "17"
                    }
                }
            """.trimIndent(),

            "app/src/main/AndroidManifest.xml" to """
                <?xml version="1.0" encoding="utf-8"?>
                <manifest xmlns:android="http://schemas.android.com/apk/res/android">
                    <application
                        android:allowBackup="true"
                        android:label="@string/app_name"
                        android:theme="@style/AppTheme">
                        <activity
                            android:name=".MainActivity"
                            android:exported="true">
                            <intent-filter>
                                <action android:name="android.intent.action.MAIN" />
                                <category android:name="android.intent.category.LAUNCHER" />
                            </intent-filter>
                        </activity>
                    </application>
                </manifest>
            """.trimIndent(),

            "app/src/main/res/values/strings.xml" to """
                <resources>
                    <string name="app_name">${escapeXml(appName)}</string>
                </resources>
            """.trimIndent(),

            "app/src/main/res/values/styles.xml" to """
                <resources>
                    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar">
                        <item name="android:fontFamily">sans</item>
                        <item name="android:windowLightStatusBar">true</item>
                    </style>
                </resources>
            """.trimIndent(),

            "app/src/main/java/${packageName.replace('.', '/')}/MainActivity.kt" to """
                package $packageName

                import android.app.Activity
                import android.os.Bundle
                import android.view.Gravity
                import android.widget.LinearLayout
                import android.widget.TextView

                class MainActivity : Activity() {
                    override fun onCreate(savedInstanceState: Bundle?) {
                        super.onCreate(savedInstanceState)

                        val root = LinearLayout(this).apply {
                            orientation = LinearLayout.VERTICAL
                            gravity = Gravity.CENTER
                            setPadding(48, 48, 48, 48)
                        }

                        root.addView(TextView(this).apply {
                            text = "${escapeKotlin(appName)}"
                            textSize = 28f
                            gravity = Gravity.CENTER
                        })

                        root.addView(TextView(this).apply {
                            text = "${escapeKotlin(goal)}"
                            textSize = 17f
                            gravity = Gravity.CENTER
                            setPadding(0, 24, 0, 0)
                        })

                        setContentView(root)
                    }
                }
            """.trimIndent(),

            "ANAMIKA_REQUIREMENT.txt" to goal.trim()
        )

        projectFiles.forEach { (path, content) ->
            files.writeText(workspace, path, content)
        }

        return GeneratedProject(
            workspace = workspace,
            filesWritten = projectFiles.size,
            summary = "Local Android project generated. Server abhi use nahi hua."
        )
    }

    private fun titleFromGoal(goal: String): String {
        val cleaned = goal
            .replace(Regex("(?i)^(app banao|make app)\\s+"), "")
            .trim()
        val firstWords = cleaned.split(Regex("\\s+")).take(4).joinToString(" ")
        return firstWords.ifBlank { "Anamika Generated App" }
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
    }

    private fun escapeKotlin(value: String): String {
        val slash = 92.toChar().toString()
        val quote = 34.toChar().toString()
        return value
            .replace(slash, slash + slash)
            .replace(quote, slash + quote)
            .replace("\n", slash + "n")
    }

    private fun escapeXml(value: String): String =
        value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
}
