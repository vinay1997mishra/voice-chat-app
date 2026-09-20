package com.anamika.ai;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.ComponentName;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.text.method.ScrollingMovementMethod;
import android.speech.RecognizerIntent;
import android.speech.RecognitionListener;
import android.speech.SpeechRecognizer;
import android.speech.tts.TextToSpeech;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import com.anamika.ai.language.UniversalLanguageRouter;
import com.anamika.ai.phone.PhoneAssistantController;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.research.AppSearchController;
import com.anamika.ai.research.BackgroundKnowledgeLookup;
import com.anamika.ai.research.ResearchLearningStore;
import com.anamika.ai.upgrade.SelfUpgradeWorkspace;

public class MainActivity extends Activity implements TextToSpeech.OnInitListener {
    private static final int REQ_SPEECH = 1001;
    private static final int REQ_AUDIO = 1002;
    private static final int REQ_CONTACTS = 1003;
    private static final int REQ_CALL = 1004;

    private TextToSpeech tts;
    private SharedPreferences prefs;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private SpeechRecognizer wakeRecognizer;
    private boolean wakeAwaitingCommand = false;
    private boolean pendingWakePermission = false;
    private String pendingPhoneCommand = "";
    private String pendingCallNumber = "";
    private String pendingCallName = "";
    private Button wakeListenButton;
    private Button forgetOwnerButton;
    private boolean unlocked = false;
    private int failedPinAttempts = 0;
    private long pinLockedUntilMs = 0L;
    private static final String PIN_FAILS = "pin_fail_count";
    private static final String PIN_LOCK_UNTIL = "pin_lock_until";

    private EditText pinInput;
    private EditText commandInput;
    private TextView status;
    private TextView result;
    private EditText developerPrompt;
    private EditText referenceUrlInput;
    private TextView developerOutput;
    private String lastGeneratedProject = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        prefs = getSharedPreferences("anamika_v7", MODE_PRIVATE);
        tts = new TextToSpeech(this, this);
        failedPinAttempts = prefs.getInt(PIN_FAILS, 0);
        pinLockedUntilMs = prefs.getLong(PIN_LOCK_UNTIL, 0L);

        pinInput = findViewById(R.id.pinInput);
        commandInput = findViewById(R.id.commandInput);
        status = findViewById(R.id.status);
        result = findViewById(R.id.result);
        Button unlockButton = findViewById(R.id.unlockButton);
        Button listenButton = findViewById(R.id.listenButton);
        Button runButton = findViewById(R.id.runButton);
        developerPrompt = findViewById(R.id.developerPrompt);
        referenceUrlInput = findViewById(R.id.referenceUrlInput);
        developerOutput = findViewById(R.id.developerOutput);
        Button generateCodeButton = findViewById(R.id.generateCodeButton);
        Button saveProjectButton = findViewById(R.id.saveProjectButton);
        Button premium3dButton = findViewById(R.id.premium3dButton);
        Button internetCreatorButton = findViewById(R.id.internetCreatorButton);
        Button pluginCenterButton = findViewById(R.id.pluginCenterButton);
        Button researchButton = findViewById(R.id.researchButton);
        Button selfUpgradeButton = findViewById(R.id.selfUpgradeButton);
        Button secureSelfUpdateButton = findViewById(R.id.secureSelfUpdateButton);
        Button testLabButton = findViewById(R.id.testLabButton);
        Button languageStatusButton = findViewById(R.id.languageStatusButton);
        wakeListenButton = findViewById(R.id.wakeListenButton);
        forgetOwnerButton = findViewById(R.id.forgetOwnerButton);
        result.setMovementMethod(new ScrollingMovementMethod());

        boolean ownerPinAlreadySet = OwnerAuth.hasPin(this);
        boolean ownerRemembered = OwnerSession.isTrusted(this);
        unlocked = OwnerSession.isActive(this);
        unlockButton.setText(ownerPinAlreadySet ? "Unlock Owner" : "Set Owner PIN");
        pinInput.setVisibility(ownerRemembered ? View.GONE : View.VISIBLE);
        unlockButton.setVisibility(ownerRemembered ? View.GONE : View.VISIBLE);
        forgetOwnerButton.setVisibility(ownerRemembered ? View.VISIBLE : View.GONE);

        unlockButton.setOnClickListener(v -> unlockOwner(unlockButton));
        listenButton.setOnClickListener(v -> startListening());
        runButton.setOnClickListener(v -> {
            String typed=commandInput.getText().toString().trim();
            if(!typed.isEmpty()){
                runCommand(typed);
                commandInput.setText("");
            }
        });
        if(ownerRemembered){
            prefs.edit().putBoolean("wake_enabled",true).apply();
        }
        wakeListenButton.setText(ownerRemembered
                ? "24×7 Hello Mika / Hello Anamika: ALWAYS ON"
                : "24×7 Wake starts after first Owner setup");
        wakeListenButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            prefs.edit().putBoolean("wake_enabled",true).apply();
            enableWakeListening(true);
            wakeListenButton.setText("24×7 Hello Mika / Hello Anamika: ALWAYS ON");
        });
        forgetOwnerButton.setOnClickListener(v -> {
            OwnerSession.revoke(this);
            unlocked=false;
            prefs.edit().putBoolean("wake_enabled",false).apply();
            stopBackgroundWakeService();
            pinInput.setVisibility(View.VISIBLE);
            unlockButton.setVisibility(View.VISIBLE);
            forgetOwnerButton.setVisibility(View.GONE);
            status.setText("Owner login forgotten • PIN required");
            result.setText("Owner login is no longer remembered on this device. Enter your existing PIN to verify again.");
        });
        generateCodeButton.setOnClickListener(v -> generateDeveloperProject());
        saveProjectButton.setOnClickListener(v -> saveGeneratedProject());
        premium3dButton.setOnClickListener(v -> {
            if (ensureUnlocked()) startActivity(new Intent(this, com.anamika.ai.media3d.Premium3DActivity.class));
        });
        internetCreatorButton.setOnClickListener(v -> {
            if (ensureUnlocked()) startActivity(new Intent(this, com.anamika.ai.creator.CreatorHubActivity.class));
        });
        pluginCenterButton.setOnClickListener(v -> {
            if (ensureUnlocked()) startActivity(new Intent(this, com.anamika.ai.plugins.PluginManagerActivity.class));
        });
        researchButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            String q = commandInput.getText().toString().trim();
            if (q.isEmpty()) q = "owner research session";
            String path = ResearchLearningStore.start(this, q);
            answer("Research mode started. Visible/public screens you open can be saved to local knowledge: " + path);
        });
        testLabButton.setOnClickListener(v -> {
            if (ensureUnlocked()) startActivity(new Intent(this, TestLabActivity.class));
        });
        selfUpgradeButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            prepareSelfUpgrade("Owner requested self-upgrade workspace from V7.8.2 UI.");
        });
        secureSelfUpdateButton.setOnClickListener(v -> {
            if (ensureUnlocked()) startActivity(new Intent(this, SelfUpdateActivity.class));
        });
        languageStatusButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            answer(UniversalLanguageRouter.capability(this) + "\n\n" +
                    CompilerPackManager.bundledInventorySummary(this));
        });

        if (!ownerPinAlreadySet) {
            status.setText("First launch • Owner PIN not set");
            result.setText("Enter any 4–12 digit PIN in the Owner PIN box, then tap SET OWNER PIN. This becomes your owner unlock code.");
        } else if(unlocked) {
            status.setText("Owner remembered • no login required");
            result.setText("Owner login remembered on this phone. Type, speak, or say Hello Mika / Hello Anamika.");
            prefs.edit().putBoolean("wake_enabled",true).apply();
            mainHandler.postDelayed(() -> enableWakeListening(false),500L);
            handleIncomingBackgroundCommand(getIntent());
        } else {
            status.setText("Locked • enter Owner PIN");
            result.setText("Enter your existing Owner PIN, then tap UNLOCK OWNER.");
        }
    }

    @Override
    protected void onNewIntent(Intent intent){
        super.onNewIntent(intent);
        setIntent(intent);
        handleIncomingBackgroundCommand(intent);
    }

    private void handleIncomingBackgroundCommand(Intent intent){
        if(intent==null) return;
        String cmd=intent.getStringExtra("background_voice_command");
        if(cmd==null || cmd.trim().isEmpty()) return;
        intent.removeExtra("background_voice_command");
        if(OwnerSession.isActive(this)){
            unlocked=true;
            runCommand(cmd.trim());
        } else {
            commandInput.setText(cmd.trim());
            showResult("Background command mila hai. Phone-control ke liye Owner PIN unlock required hai.");
        }
    }

    private void unlockOwner(Button unlockButton) {
        long now = System.currentTimeMillis();
        if (now < pinLockedUntilMs) {
            long seconds = Math.max(1L, (pinLockedUntilMs - now + 999L) / 1000L);
            toast("Too many wrong PIN attempts. Try again in " + seconds + "s");
            return;
        }

        String entered = pinInput.getText().toString().trim();
        try {
            boolean firstSetup = !OwnerAuth.hasPin(this);
            if (OwnerAuth.verifyOrSet(this, entered)) {
                unlocked = true;
                OwnerSession.grant(this);
                failedPinAttempts = 0;
                pinLockedUntilMs = 0L;
                prefs.edit()
                        .remove(PIN_FAILS).remove(PIN_LOCK_UNTIL)
                        .putBoolean("wake_enabled",true)
                        .apply();
                status.setText("Owner remembered • no login required");
                unlockButton.setText("Unlock Owner");
                pinInput.setVisibility(View.GONE);
                unlockButton.setVisibility(View.GONE);
                forgetOwnerButton.setVisibility(View.VISIBLE);
                result.setText(firstSetup
                        ? "Owner PIN set successfully. This phone is now remembered; repeated login is not required."
                        : "Owner verified. This phone is now remembered; repeated login is not required.");
                speak(firstSetup ? "Owner lock set. Anamika is ready." : "Welcome back. Anamika is ready.");
                mainHandler.postDelayed(() -> enableWakeListening(false),900L);
            } else {
                unlocked = false;
                failedPinAttempts++;
                if (failedPinAttempts >= 5) {
                    pinLockedUntilMs = System.currentTimeMillis() + 30_000L;
                    failedPinAttempts = 0;
                    prefs.edit().putInt(PIN_FAILS,0).putLong(PIN_LOCK_UNTIL,pinLockedUntilMs).apply();
                    status.setText("Locked • retry after 30 seconds");
                } else {
                    prefs.edit().putInt(PIN_FAILS,failedPinAttempts).apply();
                    status.setText("Locked • wrong PIN");
                }
                speak("Owner verification failed.");
            }
        } catch (IllegalArgumentException e) {
            toast(e.getMessage());
        } catch (Exception e) {
            showResult("Owner verification error: " + e.getMessage());
        } finally {
            pinInput.setText("");
        }
    }

    private void startListening() {
        if (!ensureUnlocked()) return;

        pauseBackgroundWakeService();
        stopWakeRecognizer();
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingWakePermission=false;
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO}, REQ_AUDIO);
            return;
        }

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        // Do not hard-code Hindi/English. Let the installed speech service use its multilingual/auto-detect capability.
        intent.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION", true);
        intent.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH", true);
        intent.putExtra(RecognizerIntent.EXTRA_PROMPT, "Speak to Anamika");
        try {
            startActivityForResult(intent, REQ_SPEECH);
        } catch (ActivityNotFoundException e) {
            showResult("Speech recognition service is not available on this phone.");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_SPEECH) resumeBackgroundWakeService();
        if (requestCode == REQ_SPEECH && resultCode == RESULT_OK && data != null) {
            ArrayList<String> text = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS);
            if (text != null && !text.isEmpty()) {
                String command = text.get(0);
                commandInput.setText(command);
                runCommand(command);
                mainHandler.postDelayed(this::restartWakeIfEnabled,1800L);
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == REQ_AUDIO) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                if(pendingWakePermission){
                    pendingWakePermission=false;
                    startBackgroundWakeService();
                } else {
                    startListening();
                }
            } else {
                showResult("Microphone permission is required for voice commands. Typed commands still work.");
            }
        } else if(requestCode==REQ_CONTACTS){
            String pending=pendingPhoneCommand;
            pendingPhoneCommand="";
            if(grantResults.length>0 && grantResults[0]==PackageManager.PERMISSION_GRANTED){
                if(!pending.isEmpty()) runCommand(pending);
            }else{
                answer("Contacts permission ke bina naam se contact/number search nahi kar sakti.");
            }
        } else if(requestCode==REQ_CALL){
            String number=pendingCallNumber;
            String name=pendingCallName;
            pendingCallNumber="";
            pendingCallName="";
            if(grantResults.length>0 && grantResults[0]==PackageManager.PERMISSION_GRANTED && !number.isEmpty()){
                if(PhoneAssistantController.placeCall(this,number)){
                    answer((name.isEmpty()?number:name)+" ko call laga rahi hoon.");
                }else{
                    PhoneAssistantController.openDialer(this,number);
                    answer("Direct call permission unavailable thi, dialer khol diya.");
                }
            }else if(!number.isEmpty()){
                PhoneAssistantController.openDialer(this,number);
                answer("Call permission nahi mili, dialer khol diya.");
            }
        }
    }

    private void runCommand(String raw) {
        if (!ensureUnlocked()) return;
        String original=raw==null?"":raw.trim();
        if(!original.isEmpty()) {
            appendChat("You",original);
            rememberConversationTurn("User",original);
        }
        UniversalLanguageRouter.Interpretation interpretation =
                UniversalLanguageRouter.interpret(this, original);
        String command = interpretation.normalized;
        if (command.isEmpty()) {
            answerForStyle(interpretation.style,
                    "कृपया कुछ बोलिए या लिखिए।",
                    "Kuch boliye ya likhiye.",
                    "Please speak or type something.");
            return;
        }

        String lower = command.toLowerCase(Locale.ROOT);
        prefs.edit()
                .putString("last_command", command)
                .putString("last_original_command", original)
                .putString("last_language_style", interpretation.style.name())
                .apply();

        if ("SEARCH".equals(interpretation.intent)) {
            String q=interpretation.argument.trim().isEmpty()?original:interpretation.argument.trim();
            answer(searchReply(interpretation.style,q,AppSearchController.searchGoogle(this,q)));
            return;
        }

        if ("YOUTUBE_SEARCH".equals(interpretation.intent)) {
            String q=interpretation.argument.trim().isEmpty()?original:interpretation.argument.trim();
            answer(searchReply(interpretation.style,q,AppSearchController.searchYouTube(this,q)));
            return;
        }

        if ("YOUTUBE_LEARN".equals(interpretation.intent)) {
            startYouTubeLearning(original,interpretation.style);
            return;
        }

        if ("READ_SCREEN".equals(interpretation.intent)) {
            readCurrentScreenAloud(interpretation.style);
            return;
        }

        if ("EXPLAIN_SCREEN".equals(interpretation.intent)) {
            explainCurrentScreen(interpretation.style);
            return;
        }

        if ("CALCULATE".equals(interpretation.intent)) {
            try{
                String value=CalculatorEngine.calculate(original);
                answerForStyle(interpretation.style,
                        "उत्तर है "+value+".",
                        "Answer "+value+" hai.",
                        "The answer is "+value+".");
            }catch(Exception e){
                answerForStyle(interpretation.style,
                        "हिसाब साफ़ समझ नहीं आया। संख्याएँ और ऑपरेशन दोबारा बोलिए।",
                        "Calculation clear nahi hua. Numbers aur operation dobara boliye.",
                        "I couldn't parse that calculation. Please say the numbers and operation again.");
            }
            return;
        }

        if ("SYSTEM_SETTING".equals(interpretation.intent)) {
            answer(PhoneAssistantController.handleSystemSetting(this,original));
            return;
        }

        if ("CONTACT_SEARCH".equals(interpretation.intent)) {
            handleContactSearch(original,interpretation.style);
            return;
        }

        if ("CALL".equals(interpretation.intent)) {
            handleCallCommand(original,interpretation.style);
            return;
        }

        if ("MESSAGE".equals(interpretation.intent) && !original.toLowerCase(Locale.ROOT).contains("whatsapp")) {
            handleSmsCommand(original,interpretation.style);
            return;
        }

        if ("UNKNOWN_LOOKUP".equals(interpretation.intent)) {
            lookupUnknownMeaning(original,interpretation.style);
            return;
        }

        if ("CHAT".equals(interpretation.intent)) {
            answerWithLocalConversation(original,interpretation.style);
            return;
        }

        if (lower.equals("hello") || lower.equals("hello anamika") || lower.equals("hi anamika") ||
                lower.equals("namaste") || lower.equals("namaste anamika") || lower.equals("नमस्ते")) {
            answer("Namaste. Main Anamika AI V7.8.2 hoon. Kaise madad karun?");
            return;
        }

        if (containsAny(lower,
                "is app ke saare functions check kar","is app ke sare functions check kar",
                "saare functions check kar","sare functions check kar","check all functions",
                "a to z","atoz","poora app check","pura app check","full app check",
                "blueprint bana","blueprint banao","auto audit app")) {
            startNamedOrSelectedAutoAudit(command);
            return;
        }

        if (tryHandleWhatsAppMessage(command)) return;

        if (com.anamika.ai.plugins.AppAutomationAccessibilityService.performOwnerPhoneCommand(this,command)) {
            answer("Phone command execute kar diya.");
            return;
        }

        if (tryHandleAnyAppVoiceCommand(command)) return;

        if (containsAny(lower, "compiler status", "toolchain status", "coding status",
                "compiler check", "binary status", "binaries check")) {
            answer(CompilerPackManager.bundledInventorySummary(this));
            return;
        }

        if (containsAny(lower,
                "app banao","app bana","application banao","create app","make app",
                "website banao","website bana","create website","code likho","code banao")) {
            developerPrompt.setText(command);
            answer("Main isi command se Developer Mode me project generation aur validation start kar rahi hoon.");
            generateDeveloperProject();
            return;
        }

        if (containsAny(lower, "test lab", "test app", "apk install", "app test")) {
            startActivity(new Intent(this, TestLabActivity.class));
            answer("Native App Test Lab khol diya hai.");
            return;
        }

        if (containsAny(lower, "weather", "mausam", "मौसम")) {
            webSearch("weather near me");
            answer("Mausam ki latest information browser me khol rahi hoon.");
            return;
        }

        if (lower.contains("youtube") && containsAny(lower, "search", "dhundo", "ढूंढो", "खोज", "find")) {
            String q = extractAfterSearchWord(command, "youtube");
            answer(AppSearchController.searchYouTube(this, q));
            return;
        }

        if (lower.contains("google") && containsAny(lower, "search", "dhundo", "ढूंढो", "खोज", "find")) {
            String q = extractAfterSearchWord(command, "google");
            answer(AppSearchController.searchGoogle(this, q));
            return;
        }

        if (containsAny(lower, "search karke sikho", "search karke seekho", "research mode", "research karo", "learn from search", "study this")) {
            String q = command.replaceFirst("(?i).*(?:search karke sikho|search karke seekho|research mode|research karo|learn from search|study this)\\s*", "").trim();
            if (q.isEmpty()) q = command;
            String path = ResearchLearningStore.start(this, q);
            AppSearchController.searchGoogle(this, q);
            answer("Research mode started. Main sirf visible/public content ka local record banaungi. Knowledge file: " + path);
            return;
        }

        if (containsAny(lower, "research complete", "learning complete", "research stop", "seekhna band", "research khatam")) {
            String path = ResearchLearningStore.stop(this);
            answer("Research session sealed. Local record: " + path);
            return;
        }

        if (lower.startsWith("search ") || lower.startsWith("google ") || lower.startsWith("dhundo ") || lower.startsWith("ढूंढो ")) {
            String query = command.replaceFirst("(?i)^(search|google|dhundo|ढूंढो)\\s+", "");
            webSearch(query);
            answer("Search khol diya: " + query);
            return;
        }

        if (lower.startsWith("remember ") || lower.startsWith("yaad rakho ") || lower.startsWith("याद रखो ")) {
            String memory = command.replaceFirst("(?i)^(remember|yaad rakho|याद रखो)\\s+", "");
            prefs.edit().putString("memory_note", memory).apply();
            answer("Theek hai. Maine is note ko local memory me save kar liya.");
            return;
        }

        if (containsAny(lower, "what do you remember", "kya yaad hai", "क्या याद है")) {
            String memory = prefs.getString("memory_note", "Abhi koi saved note nahi hai.");
            answer("Saved memory: " + memory);
            return;
        }

        if (lower.startsWith("open ") || lower.startsWith("khol ") || lower.startsWith("खोलो ")) {
            String appName = command.replaceFirst("(?i)^(open|khol|खोलो)\\s+", "").trim();
            openKnownApp(appName);
            return;
        }

        if (containsAny(lower, "khud ko upgrade", "self upgrade", "apne aap ko update", "upgrade yourself", "self-update coding")) {
            prepareSelfUpgrade(command);
            return;
        }

        if (containsAny(lower, "check update", "update check", "upgrade anamika", "anamika update", "अपडेट")) {
            showUpdateApproval();
            return;
        }

        if (containsAny(lower, "developer mode", "coding karo", "code banao", "app coding", "डेवलपर मोड", "कोड बनाओ")) {
            developerPrompt.setText(command);
            answer("Standalone Developer Mode ready hai. Request dijiye. Coding local mode me hogi; URL ko online access nahi kiya jayega.");
            return;
        }

        if (containsAny(lower, "3d animation", "3d video", "4d video", "dragon video", "cinematic dragon", "premium animation", "animation studio", "3d एनीमेशन", "cinematic video")) {
            startActivity(new Intent(this, com.anamika.ai.media3d.Premium3DActivity.class));
            answer("Universal Cinematic 3D/4D Studio khol diya. Dragon, eagle, phoenix, wolf, lion, supercar, spaceship, robot, logo/crystal aur custom asset scenes bana sakte hain.");
            return;
        }

        if (containsAny(lower, "online video banao", "internet creator", "full hd video", "movie jaisa video", "ai video banao", "cinematic creator")) {
            startActivity(new Intent(this, com.anamika.ai.creator.CreatorHubActivity.class));
            answer("Internet Cinematic Creator khol diya. Compatible provider configure karke prompt se Full HD cinematic video generate kar sakte hain.");
            return;
        }

        if (containsAny(lower, "plugin center", "plugins", "app control", "control apps", "plugin kholo", "प्लगइन")) {
            startActivity(new Intent(this, com.anamika.ai.plugins.PluginManagerActivity.class));
            answer("Plugin Center khol diya. Yahan selected apps persistent plugins bante hain. One-time voice command se non-plugin apps bhi open/control ho sakte hain bina plugin add hue.");
            return;
        }

        if (containsAny(lower, "settings", "setting kholo", "सेटिंग")) {
            startActivity(new Intent(Settings.ACTION_SETTINGS));
            answer("Phone settings khol di.");
            return;
        }

        // For short unknown words/phrases, try a background public-knowledge lookup
        // and cache the meaning. Longer utterances stay in natural conversation mode.
        if(original.length()<=120 && original.trim().split("\\s+").length<=10){
            lookupUnknownMeaning(original,interpretation.style);
        }else{
            answerWithLocalConversation(original,interpretation.style);
        }
    }

    private void readCurrentScreenAloud(UniversalLanguageRouter.Style style){
        String screen=com.anamika.ai.plugins.AppAutomationAccessibilityService.readVisibleScreenText();
        if(screen==null || screen.trim().isEmpty()){
            answerForStyle(style,
                    "स्क्रीन का टेक्स्ट नहीं मिल रहा। Anamika App Control accessibility service चालू होनी चाहिए।",
                    "Screen ka text nahi mil raha. Anamika App Control accessibility service ON honi chahiye.",
                    "I can't read the screen text. The Anamika App Control accessibility service must be enabled.");
            return;
        }
        answer(screen);
    }

    private void explainCurrentScreen(UniversalLanguageRouter.Style style){
        String screen=com.anamika.ai.plugins.AppAutomationAccessibilityService.readVisibleScreenText();
        if(screen==null || screen.trim().isEmpty()){
            readCurrentScreenAloud(style);
            return;
        }
        final String snapshot=screen.length()>9000?screen.substring(0,9000):screen;
        showResult(style==UniversalLanguageRouter.Style.HINDI?"स्क्रीन समझ रही हूँ…":"Screen samajh rahi hoon…");
        new Thread(() -> {
            String reply;
            try{
                String prompt="You are Anamika AI. Explain the currently visible phone/app screen to the owner. "+
                        UniversalLanguageRouter.replyInstruction(style)+" "+
                        "Explain what the screen is, important controls, what can be done next, and any warning/risk. "+
                        "Do not invent controls not present in the snapshot. Visible screen text:\n"+snapshot;
                reply=LocalModelBridge.generate(MainActivity.this,prompt);
                if(reply==null || reply.trim().isEmpty()) throw new IllegalStateException("empty explanation");
                reply=reply.trim();
            }catch(Throwable t){
                reply=style==UniversalLanguageRouter.Style.HINDI
                        ?"स्क्रीन पढ़ ली है, लेकिन अभी उसका AI explanation नहीं बन पाया।"
                        :"Screen padh li hai, lekin abhi AI explanation nahi ban paya.";
            }
            final String out=reply;
            runOnUiThread(() -> answer(out));
        },"AnamikaScreenExplain").start();
    }

    private void handleContactSearch(String original,UniversalLanguageRouter.Style style){
        if(!PhoneAssistantController.hasContactsPermission(this)){
            pendingPhoneCommand=original;
            requestPermissions(new String[]{Manifest.permission.READ_CONTACTS},REQ_CONTACTS);
            return;
        }
        String name=PhoneAssistantController.extractPersonName(original);
        if(name.isEmpty()) name=original.replaceAll("(?i)(contact|name|naam|number|search|dhundo|dhoondo|khojo|karo|करो|खोजो|ढूंढो)"," ").trim();
        PhoneAssistantController.ContactMatch m=PhoneAssistantController.findContact(this,name);
        if(m==null){
            answerForStyle(style,
                    name+" नाम का कॉन्टैक्ट नहीं मिला।",
                    name+" naam ka contact nahi mila.",
                    "I couldn't find a contact named "+name+".");
        }else{
            answerForStyle(style,
                    m.name+" का नंबर "+m.phone+" है।",
                    m.name+" ka number "+m.phone+" hai.",
                    m.name+"'s number is "+m.phone+".");
        }
    }

    private void handleCallCommand(String original,UniversalLanguageRouter.Style style){
        if(!PhoneAssistantController.hasContactsPermission(this)){
            pendingPhoneCommand=original;
            requestPermissions(new String[]{Manifest.permission.READ_CONTACTS},REQ_CONTACTS);
            return;
        }
        String name=PhoneAssistantController.extractPersonName(original);
        if(name.isEmpty()){
            answerForStyle(style,"किसे कॉल करना है?","Kise call karna hai?","Who should I call?");
            return;
        }
        PhoneAssistantController.ContactMatch m=PhoneAssistantController.findContact(this,name);
        if(m==null || m.phone.isEmpty()){
            answerForStyle(style,name+" का नंबर नहीं मिला।",name+" ka number nahi mila.","I couldn't find a number for "+name+".");
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Call "+m.name+"?")
                .setMessage(m.phone)
                .setNegativeButton("Cancel",(d,w)->answerForStyle(style,"कॉल रद्द कर दी।","Call cancel kar di.","Call cancelled."))
                .setPositiveButton("Call",(d,w)->{
                    if(PhoneAssistantController.hasCallPermission(this)){
                        if(PhoneAssistantController.placeCall(this,m.phone)) answer(m.name+" ko call laga rahi hoon.");
                    }else{
                        pendingCallNumber=m.phone;
                        pendingCallName=m.name;
                        requestPermissions(new String[]{Manifest.permission.CALL_PHONE},REQ_CALL);
                    }
                }).show();
    }

    private void handleSmsCommand(String original,UniversalLanguageRouter.Style style){
        if(!PhoneAssistantController.hasContactsPermission(this)){
            pendingPhoneCommand=original;
            requestPermissions(new String[]{Manifest.permission.READ_CONTACTS},REQ_CONTACTS);
            return;
        }
        String name=PhoneAssistantController.extractMessageRecipient(original);
        String body=PhoneAssistantController.extractMessageBody(original);
        if(name.isEmpty()){
            answerForStyle(style,"किसे मैसेज भेजना है?","Kise message bhejna hai?","Who should I message?");
            return;
        }
        PhoneAssistantController.ContactMatch m=PhoneAssistantController.findContact(this,name);
        if(m==null || m.phone.isEmpty()){
            answerForStyle(style,name+" का नंबर नहीं मिला।",name+" ka number nahi mila.","I couldn't find a number for "+name+".");
            return;
        }
        PhoneAssistantController.composeSms(this,m.phone,body);
        answerForStyle(style,
                m.name+" का मैसेज ड्राफ्ट खोल दिया है। भेजने से पहले एक बार देख लें।",
                m.name+" ka message draft khol diya hai. Send karne se pehle ek baar dekh lo.",
                "I opened the message draft for "+m.name+". Review it before sending.");
    }

    private void startYouTubeLearning(String original,UniversalLanguageRouter.Style style){
        String q=original.replaceAll("(?i)(youtube|यूट्यूब|se|pe|par|से|पर|video|वीडियो|sikho|seekho|learn|सीखो|सीखना)"," ")
                .replaceAll("\\s+"," ").trim();
        if(q.isEmpty()) q=original;
        String path=ResearchLearningStore.start(this,"YouTube learning: "+q);
        AppSearchController.searchYouTube(this,q);
        answerForStyle(style,
                "YouTube learning mode शुरू है। मैं खुले वीडियो के दिखाई देने वाले title, description, controls और captions/subtitles को local knowledge में सीखूँगी।",
                "YouTube learning mode start hai. Main open video ke visible title, description, controls aur captions/subtitles ko local knowledge me learn karungi.",
                "YouTube learning mode is active. I will learn from visible titles, descriptions, controls and captions/subtitles on opened videos.");
    }

    private void lookupUnknownMeaning(String original,UniversalLanguageRouter.Style style){
        String q=original.trim();
        if(q.isEmpty()){ answerWithLocalConversation(original,style); return; }
        showResult(style==UniversalLanguageRouter.Style.HINDI?"मतलब खोज रही हूँ…":"Meaning background me search kar rahi hoon…");
        boolean hi=style==UniversalLanguageRouter.Style.HINDI || style==UniversalLanguageRouter.Style.HINGLISH;
        BackgroundKnowledgeLookup.lookup(this,q,hi,result -> {
            if(result.found){
                String prefix=style==UniversalLanguageRouter.Style.HINDI
                        ?"मैंने इसका मतलब सीख लिया: "
                        :style==UniversalLanguageRouter.Style.ENGLISH
                            ?"I found and learned this: "
                            :"Maine iska meaning samajh kar local memory me learn kar liya: ";
                answer(prefix+result.title+" — "+result.summary+" ("+result.source+(result.fromCache?", saved memory":"")+")");
            }else{
                answerWithLocalConversation(original,style);
            }
        });
    }

    private void rememberConversationTurn(String who,String text){
        if(prefs==null || text==null || text.trim().isEmpty()) return;
        String clean=text.trim().replace("\r"," ").replace("\n"," ");
        if(clean.length()>500) clean=clean.substring(0,500);
        String history=prefs.getString("conversation_history","");
        history+=(history.isEmpty()?"":"\n")+who+": "+clean;
        String[] lines=history.split("\\n");
        if(lines.length>12){
            StringBuilder keep=new StringBuilder();
            for(int i=lines.length-12;i<lines.length;i++){
                if(keep.length()>0) keep.append('\n');
                keep.append(lines[i]);
            }
            history=keep.toString();
        }
        if(history.length()>5000) history=history.substring(history.length()-5000);
        prefs.edit().putString("conversation_history",history).apply();
    }

    private void answerForStyle(UniversalLanguageRouter.Style style,String hindi,String hinglish,String english){
        if(style==UniversalLanguageRouter.Style.HINDI) answer(hindi);
        else if(style==UniversalLanguageRouter.Style.HINGLISH) answer(hinglish);
        else if(style==UniversalLanguageRouter.Style.ENGLISH) answer(english);
        else answer(hinglish);
    }

    private String searchReply(UniversalLanguageRouter.Style style,String query,String technical){
        if(style==UniversalLanguageRouter.Style.HINDI) return "मैंने “"+query+"” की खोज खोल दी है।";
        if(style==UniversalLanguageRouter.Style.ENGLISH) return "I opened a search for “"+query+"”.";
        return "Maine “"+query+"” ka search khol diya hai.";
    }

    private void answerWithLocalConversation(String original,UniversalLanguageRouter.Style style){
        if(original==null || original.trim().isEmpty()) return;
        showResult(style==UniversalLanguageRouter.Style.HINDI
                ?"सोच रही हूँ…"
                :style==UniversalLanguageRouter.Style.ENGLISH
                    ?"Thinking…"
                    :"Samajh rahi hoon…");

        final String userText=original.trim();
        final UniversalLanguageRouter.Style replyStyle=style;
        new Thread(() -> {
            String reply;
            try{
                LocalModelBridge.ModelStatus st=LocalModelBridge.getStatus(MainActivity.this);
                if(!st.ready){
                    reply=replyStyle==UniversalLanguageRouter.Style.HINDI
                            ?"लोकल AI मॉडल अभी तैयार नहीं है। सामान्य कमांड काम करेंगे, लेकिन खुली बातचीत सीमित रहेगी।"
                            :replyStyle==UniversalLanguageRouter.Style.ENGLISH
                                ?"The local AI model is not ready yet. Basic commands will work, but open conversation is limited."
                                :"Local AI model abhi ready nahi hai. Normal commands chalenge, lekin open conversation limited rahegi.";
                }else{
                    String memory=prefs.getString("memory_note","");
                    String history=prefs.getString("conversation_history","");
                    String prompt="You are Anamika AI, the owner's personal on-device assistant. "+
                            "Understand natural human language, including Hindi, Hinglish, English and mixed speech. "+
                            UniversalLanguageRouter.replyInstruction(replyStyle)+" "+
                            "Be concise, useful and conversational. Do not mention intent parsing, keyword maps or model internals. "+
                            "If the user asks for an action you cannot actually execute in this reply, explain the next concrete action instead of pretending it happened. "+
                            (memory.isEmpty()?"":"Relevant owner memory: "+memory+" ")+
                            (history.isEmpty()?"":"Recent conversation context:\n"+history+"\n")+
                            "User: "+userText+"\nAnamika:";
                    reply=LocalModelBridge.generate(MainActivity.this,prompt);
                    if(reply==null || reply.trim().isEmpty()) throw new IllegalStateException("empty local reply");
                    reply=reply.trim();
                    int fence=reply.indexOf("~~~");
                    if(fence>=0) reply=reply.substring(0,fence).trim();
                    if(reply.length()>1800) reply=reply.substring(0,1800).trim();
                }
            }catch(Throwable t){
                reply=replyStyle==UniversalLanguageRouter.Style.HINDI
                        ?"मैं आपकी बात समझने की कोशिश कर रही हूँ, लेकिन इस बार लोकल AI जवाब नहीं बना पाया। दोबारा बोलिए।"
                        :replyStyle==UniversalLanguageRouter.Style.ENGLISH
                            ?"I understood the request, but the local AI could not produce a reply this time. Please try again."
                            :"Main baat samajhne ki koshish kar rahi hoon, lekin is baar local AI reply nahi bana paya. Dobara boliye.";
            }
            final String out=reply;
            runOnUiThread(() -> answer(out));
        },"AnamikaConversation").start();
    }

    private void generateDeveloperProject() {
        if (!ensureUnlocked()) return;
        String prompt = developerPrompt.getText().toString().trim();
        String referenceUrl = referenceUrlInput.getText().toString().trim();

        if (prompt.isEmpty()) {
            developerOutput.setText("Developer request likhiye, jaise: 'Android ke liye video editing app ka project banao'.");
            return;
        }

        if (!referenceUrl.isEmpty()) {
            developerOutput.setText("Standalone coding mode active. URL ko coding engine direct crawl nahi karega. " +
                    "Latest saved App Blueprint compatible clone/reference requests me local context ke roop me use ho sakta hai.\n\n" +
                    "Local generation start ho rahi hai...");
        } else {
            developerOutput.setText("Standalone Developer Mode: local generation + validation start ho rahi hai...");
        }

        StandaloneDeveloperEngine.generate(this, prompt, new StandaloneDeveloperEngine.Callback() {
            @Override
            public void onSuccess(StandaloneDeveloperEngine.Result generated) {
                runOnUiThread(() -> {
                    lastGeneratedProject = generated.generatedText;
                    developerOutput.setText("ENGINE: " + generated.engine + "\n" +
                            "STRUCTURAL VALIDATION: " + generated.validation.summary() + "\n" +
                            "COMPILER VERIFICATION: " + generated.compilerVerification.summary() + "\n" +
                            "FULL VERIFIED: " + (generated.validation.isClean() && generated.compilerVerification.isFullyVerified()) + "\n\n" +
                            generated.generatedText + "\n\n--- STRUCTURAL VALIDATION ---\n" +
                            generated.validation.details() + "\n\n--- REAL COMPILER REPORT ---\n" +
                            generated.compilerVerification.details());
                    speak("Standalone developer generation complete. Validation finished. Review before saving or building.");
                });
            }

            @Override
            public void onError(String error) {
                runOnUiThread(() -> developerOutput.setText("Standalone Developer Mode error: " + error));
            }
        });
    }

    private void saveGeneratedProject() {
        if (!ensureUnlocked()) return;
        if (lastGeneratedProject == null || lastGeneratedProject.trim().isEmpty()) {
            developerOutput.setText("Pehle project/code generate kijiye.");
            return;
        }
        try {
            java.io.File folder = GeneratedProjectSaver.save(this, lastGeneratedProject);
            developerOutput.append("\n\nSaved project folder:\n" + folder.getAbsolutePath());
            speak("Generated project files saved.");
        } catch (Exception e) {
            developerOutput.append("\n\nSave error: " + e.getMessage());
        }
    }

    private void showUpdateApproval() {
        new AlertDialog.Builder(this)
                .setTitle("Anamika AI V7.8.2 • Update Permission")
                .setMessage("Anamika will never activate an update without your approval. This demo build only opens the approved update flow; Android will still require normal package-install permission for any APK update.")
                .setNegativeButton("Cancel", (d, w) -> answer("Update cancelled."))
                .setPositiveButton("Approve check", (d, w) -> answer("Update check approved. No remote update source is configured in this local V7.8.2 build."))
                .show();
    }

    private void openKnownApp(String appName) {
        String pkg=findInstalledPackage(appName);
        if(pkg==null){
            webSearch(appName);
            answer("Installed app label match nahi mila, isliye search khol di.");
            return;
        }
        String r=com.anamika.ai.plugins.AppPluginEngine.openAny(this,pkg);
        answer(appName+" khol diya. Plugin hona zaroori nahi hai. "+r);
    }

    private boolean tryHandleAnyAppVoiceCommand(String command){
        if(command==null || command.trim().isEmpty()) return false;
        String raw=command.trim();
        Matcher m=Pattern.compile(
                "(?i)^(?:open|khol|kholo|खोलो)\\s+(.+?)(?:\\s+(?:aur|then|phir|fir|uske baad|and then)\\s+(.+))?$"
        ).matcher(raw);
        String appName="";
        String action="";
        if(m.find()){
            appName=m.group(1).trim();
            action=m.group(2)==null?"":m.group(2).trim();
        } else {
            m=Pattern.compile(
                    "(?i)^(.+?)\\s+(?:app\\s+)?(?:open|khol|kholo|खोलो)\\s*(?:karo|kar|do)?(?:\\s+(?:aur|then|phir|fir|uske baad|and then)\\s+(.+))?$"
            ).matcher(raw);
            if(!m.find()) return false;
            appName=m.group(1).trim();
            action=m.group(2)==null?"":m.group(2).trim();
        }

        appName=appName.replaceFirst("(?i)\\s+app$","").trim();
        String pkg=findInstalledPackage(appName);
        if(pkg==null || pkg.isEmpty()) return false;

        if(action.isEmpty()){
            String r=com.anamika.ai.plugins.AppPluginEngine.openAny(this,pkg);
            answer(appName+" khol diya. Plugin hona zaroori nahi tha. "+r);
            return true;
        }

        if(!isAutomationServiceEnabled()){
            String r=com.anamika.ai.plugins.AppPluginEngine.openAny(this,pkg);
            answer(appName+" khol diya, lekin andar ka one-time tap/type/scroll command execute nahi hua kyunki Anamika App Control service OFF hai. "+r);
            return true;
        }

        String r=com.anamika.ai.plugins.AppPluginEngine.openAndRunOneShot(this,pkg,action);
        answer(appName+" par one-time owner voice command diya: “"+action+"”. App plugin list me add nahi hua. "+r);
        return true;
    }

    private String findInstalledPackage(String appName){
        if(appName==null) return null;
        String n=appName.trim().toLowerCase(Locale.ROOT);
        if(n.isEmpty()) return null;
        if(n.contains("whatsapp")) return "com.whatsapp";
        if(n.contains("youtube")) return "com.google.android.youtube";
        if(n.contains("chrome")) return "com.android.chrome";
        if(n.contains("instagram")) return "com.instagram.android";
        if(n.contains("telegram")) return "org.telegram.messenger";
        return com.anamika.ai.plugins.PluginRegistry.findPackageByLabel(this,appName);
    }

    private void startBackgroundWakeService(){
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED) return;
        Intent i=new Intent(this,BackgroundWakeService.class).setAction(BackgroundWakeService.ACTION_START);
        try{
            if(android.os.Build.VERSION.SDK_INT>=26) startForegroundService(i); else startService(i);
        }catch(Throwable t){
            showResult("24×7 wake service start error: "+t.getMessage());
        }
    }

    private void stopBackgroundWakeService(){
        Intent i=new Intent(this,BackgroundWakeService.class).setAction(BackgroundWakeService.ACTION_STOP);
        try{ startService(i); }catch(Throwable ignored){}
    }

    private void pauseBackgroundWakeService(){
        if(!BackgroundWakeService.isRunning()) return;
        Intent i=new Intent(this,BackgroundWakeService.class).setAction(BackgroundWakeService.ACTION_PAUSE);
        try{ startService(i); }catch(Throwable ignored){}
    }

    private void resumeBackgroundWakeService(){
        if(prefs==null || !prefs.getBoolean("wake_enabled",true)) return;
        if(!BackgroundWakeService.isRunning()){
            startBackgroundWakeService();
            return;
        }
        Intent i=new Intent(this,BackgroundWakeService.class).setAction(BackgroundWakeService.ACTION_RESUME);
        try{ startService(i); }catch(Throwable ignored){}
    }

    private void toggleWakeListening(){
        if(!ensureUnlocked()) return;
        prefs.edit().putBoolean("wake_enabled",true).apply();
        wakeListenButton.setText("24×7 Hello Mika / Hello Anamika: ALWAYS ON");
        enableWakeListening(true);
    }

    private void enableWakeListening(boolean announce){
        if(!unlocked || !OwnerSession.isActive(this)) return;
        if(!OwnerSession.isTrusted(this)) return;
        if(!prefs.getBoolean("wake_enabled",true)){
            prefs.edit().putBoolean("wake_enabled",true).apply();
        }
        if(!SpeechRecognizer.isRecognitionAvailable(this)){
            wakeListenButton.setText("24×7 Hello Mika / Hello Anamika: unavailable");
            if(announce) answer("Is phone par SpeechRecognizer service available nahi hai.");
            return;
        }
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){
            pendingWakePermission=true;
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO);
            return;
        }
        startBackgroundWakeService();
        status.setText("Owner verified • 24×7 wake active");
        if(announce) answer("24×7 wake mode on hai. Anamika background me “Hello Mika” ya “Hello Anamika” sunegi.");
    }

    private void startWakeRecognizer(){
        if(!unlocked || !OwnerSession.isActive(this)) return;
        stopWakeRecognizer();
        wakeRecognizer=SpeechRecognizer.createSpeechRecognizer(this);
        wakeRecognizer.setRecognitionListener(new RecognitionListener(){
            @Override public void onReadyForSpeech(Bundle params){ status.setText(wakeAwaitingCommand?"Listening for your command…":"Wake listening • say Hello Mika / Hello Anamika"); }
            @Override public void onBeginningOfSpeech(){}
            @Override public void onRmsChanged(float rmsdB){}
            @Override public void onBufferReceived(byte[] buffer){}
            @Override public void onEndOfSpeech(){}
            @Override public void onError(int error){ restartWakeSoon(900L); }
            @Override public void onResults(Bundle results){
                ArrayList<String> list=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
                String heard=(list==null||list.isEmpty())?"":list.get(0).trim();
                handleWakeSpeech(heard);
            }
            @Override public void onPartialResults(Bundle partialResults){}
            @Override public void onEvent(int eventType,Bundle params){}
        });
        Intent i=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        i.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
        i.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION",true);
        i.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH",true);
        try{ wakeRecognizer.startListening(i); }
        catch(Exception e){ restartWakeSoon(1200L); }
    }

    private void handleWakeSpeech(String heard){
        if(heard==null || heard.trim().isEmpty()){ restartWakeSoon(700L); return; }
        String lower=heard.toLowerCase(Locale.ROOT);
        Matcher wake=Pattern.compile("(?i)(?:hello|hey|hi)\\s+(?:anamika|mika)").matcher(heard);
        if(wake.find()){
            appendChat("You",heard);
            String after=heard.substring(wake.end()).replaceFirst("^[\\s,.:;-]+","").trim();
            if(!after.isEmpty()){
                wakeAwaitingCommand=false;
                runCommand(after);
            } else {
                wakeAwaitingCommand=true;
                answer("Ji, boliye.");
                restartWakeSoon(1800L);
            }
            return;
        }
        if(wakeAwaitingCommand){
            wakeAwaitingCommand=false;
            commandInput.setText(heard);
            runCommand(heard);
            restartWakeSoon(1800L);
            return;
        }
        restartWakeSoon(600L);
    }

    private void restartWakeSoon(long delay){
        mainHandler.postDelayed(this::restartWakeIfEnabled,delay);
    }

    private void restartWakeIfEnabled(){
        if(prefs!=null && unlocked && OwnerSession.isActive(this)){
            resumeBackgroundWakeService();
        }
    }

    private void stopWakeRecognizer(){
        if(wakeRecognizer!=null){
            try{ wakeRecognizer.cancel(); }catch(Exception ignored){}
            try{ wakeRecognizer.destroy(); }catch(Exception ignored){}
            wakeRecognizer=null;
        }
    }

    private boolean tryHandleWhatsAppMessage(String command){
        if(command==null) return false;
        String lower=command.toLowerCase(Locale.ROOT);
        if(!lower.contains("whatsapp") || !containsAny(lower," msg "," message ","bhejo","send ")) return false;

        String recipient="";
        String message="";
        Matcher hi=Pattern.compile("(?i)([\\p{L}\\p{N}._ -]{1,45})\\s+ko\\s+(?:msg|message)\\s+(?:kar|karo|bhejo|send)?\\s*(.+)$").matcher(command);
        if(hi.find()){
            recipient=hi.group(1).trim().replaceFirst("(?i)^.*(?:waha|wahaan|aur|then)\\s+","");
            message=hi.group(2).trim();
        } else {
            Matcher en=Pattern.compile("(?i)(?:send|message)\\s+(.+?)\\s+to\\s+([\\p{L}\\p{N}._ -]{1,40})(?:\\s+on\\s+whatsapp)?$").matcher(command);
            if(en.find()){ message=en.group(1).trim(); recipient=en.group(2).trim(); }
        }
        recipient=recipient.replaceFirst("(?i)^whatsapp\\s+(?:open|khol|kholo)\\s*(?:kar|karo)?\\s*","");
        if(recipient.isEmpty() || message.isEmpty()){
            answer("WhatsApp command samajh aaya, lekin contact ya message clear nahi mila. Example: WhatsApp kholo aur Vinay ko message bhejo hello.");
            return true;
        }
        String pkg="com.whatsapp";
        if(!isAutomationServiceEnabled()){
            answer("WhatsApp khol sakti hoon, lekin andar message bhejne ke one-time control ke liye Anamika App Control service ON honi chahiye.");
            com.anamika.ai.plugins.AppPluginEngine.openAny(this,pkg);
            return true;
        }
        String r=com.anamika.ai.plugins.AppPluginEngine.openAndRunOneShot(this,pkg,
                "whatsapp-message|"+recipient+"|"+message);
        answer("WhatsApp me "+recipient+" ko message bhejne ka one-time owner command diya. WhatsApp plugin list me add nahi hua. "+r);
        return true;
    }

    private void startNamedOrSelectedAutoAudit(String command){
        String appName=extractAuditAppName(command);
        String pkg="";
        if(!appName.isEmpty()) pkg=com.anamika.ai.plugins.PluginRegistry.findPackageByLabel(this,appName);
        if(pkg==null) pkg="";
        if(pkg.isEmpty()) pkg=getSharedPreferences("anamika_automation",MODE_PRIVATE).getString("target_package","");
        if(pkg.isEmpty()){
            answer("Jis app ka audit chahiye uska naam command me boliye, jaise: “Hika app open karke A to Z saare functions check karo aur blueprint banao.”");
            return;
        }
        if(!com.anamika.ai.plugins.PluginRegistry.isEnabled(this,pkg)){
            answer("Ye app aapke owner-selected plugins me enabled nahi hai, isliye Anamika ne audit/control start nahi kiya.");
            return;
        }
        if(!isAutomationServiceEnabled()){
            answer("Anamika App Control service off hai, isliye is app par automatic audit/control start nahi kiya gaya.");
            return;
        }
        getSharedPreferences("anamika_automation",MODE_PRIVATE).edit().putString("target_package",pkg).apply();
        String r=com.anamika.ai.plugins.AppPluginEngine.openAndRun(this,pkg,"check all functions");
        answer("Auto Audit start. Anamika app ke visible screens, rooms, menus, safe clickable buttons, scroll aur back-navigation ko systematically check karegi. Har tested/skipped control blueprint me record hoga. Password, payment, destructive action aur real message/send jaise side-effect actions generic audit me skip honge; unhe explicit command se chalaya ja sakta hai. "+r);
    }

    private String extractAuditAppName(String command){
        if(command==null) return "";
        Matcher m=Pattern.compile("(?i)^\\s*([\\p{L}\\p{N}._-]{2,30})\\s+app\\s+(?:open|khol|kholo|check|dekho|dekh)").matcher(command.trim());
        if(m.find()) return m.group(1).trim();
        m=Pattern.compile("(?i)(?:open|khol|kholo)\\s+([\\p{L}\\p{N}._-]{2,30})\\s+app").matcher(command);
        return m.find()?m.group(1).trim():"";
    }

    private boolean isAutomationServiceEnabled(){
        String enabled=Settings.Secure.getString(getContentResolver(),Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES);
        if(TextUtils.isEmpty(enabled)) return false;
        String expected=new ComponentName(this,com.anamika.ai.plugins.AppAutomationAccessibilityService.class).flattenToString();
        TextUtils.SimpleStringSplitter splitter=new TextUtils.SimpleStringSplitter(':');
        splitter.setString(enabled);
        while(splitter.hasNext()) if(expected.equalsIgnoreCase(splitter.next())) return true;
        return false;
    }

    private void webSearch(String query) {
        Intent browser = new Intent(Intent.ACTION_VIEW, Uri.parse("https://www.google.com/search?q=" + Uri.encode(query)));
        try {
            startActivity(browser);
        } catch (ActivityNotFoundException e) {
            showResult("No browser/search app is available on this phone.");
        }
    }

    private String extractAfterSearchWord(String command, String appWord) {
        String s = command == null ? "" : command.trim();
        s = s.replaceFirst("(?i)" + java.util.regex.Pattern.quote(appWord) + "\\s*(?:par|pe|me|mein)?\\s*", "");
        s = s.replaceFirst("(?i)^(?:search|find|dhundo|ढूंढो|खोजो|खोज)\\s+", "");
        s = s.replaceFirst("(?i)\\s+(?:search|find|dhundo|ढूंढो|खोजो|खोज)(?:\\s+karo)?$", "");
        return s.trim().isEmpty() ? command : s.trim();
    }

    private void prepareSelfUpgrade(String request) {
        try {
            java.io.File workspace = SelfUpgradeWorkspace.prepare(this, request);
            String upgradePrompt = "Upgrade Anamika itself. Owner request: " + request +
                    "\nUse the bundled current-source snapshot from: " + workspace.getAbsolutePath() +
                    "\nPreserve owner approval, rollback and validation gates. Generate the complete corrected project after analysing current source.";
            developerPrompt.setText(upgradePrompt);
            answer("Self-upgrade workspace ready. Anamika is generating and checking the requested upgrade locally. Nothing will be installed without owner approval.");
            StandaloneDeveloperEngine.generate(this, upgradePrompt, new StandaloneDeveloperEngine.Callback() {
                @Override public void onSuccess(StandaloneDeveloperEngine.Result generated) {
                    runOnUiThread(() -> {
                        lastGeneratedProject = generated.generatedText;
                        boolean verified = generated.validation.isClean() && generated.compilerVerification.isFullyVerified();
                        developerOutput.setText("SELF-UPGRADE CANDIDATE\nENGINE: " + generated.engine +
                                "\nSTRUCTURAL: " + generated.validation.summary() +
                                "\nCOMPILER: " + generated.compilerVerification.summary() +
                                "\nFULL VERIFIED: " + verified +
                                "\n\n" + generated.generatedText +
                                "\n\n--- VALIDATION ---\n" + generated.validation.details() +
                                "\n\n--- COMPILER ---\n" + generated.compilerVerification.details());
                        speak(verified
                                ? "Self upgrade candidate passed local checks. Review it and approve before installation."
                                : "Self upgrade candidate is not fully verified. I will not mark it ready for installation.");
                    });
                }
                @Override public void onError(String error) {
                    runOnUiThread(() -> developerOutput.setText("Self-upgrade generation error: " + error));
                }
            });
        } catch (Exception e) {
            answer("Self-upgrade workspace error: " + e.getMessage());
        }
    }

    private boolean ensureUnlocked() {
        if (unlocked && !OwnerSession.isActive(this)) unlocked = false;
        if (!unlocked) {
            showResult("Owner lock active. Enter your PIN first.");
            speak("Owner verification required.");
            return false;
        }
        return true;
    }

    private boolean containsAny(String text, String... terms) {
        for (String term : terms) if (text.contains(term)) return true;
        return false;
    }

    private void answer(String text) {
        showResult(text);
        rememberConversationTurn("Anamika",text);
        speak(text);
    }

    private void appendChat(String who,String text){
        if(result==null || text==null || text.trim().isEmpty()) return;
        String existing=result.getText()==null?"":result.getText().toString();
        String line=(existing.trim().isEmpty()?"":"\n\n")+who+": "+text.trim();
        result.append(line);
        result.post(() -> {
            int offset=result.getLayout()==null?0:result.getLayout().getLineTop(result.getLineCount())-result.getHeight();
            result.scrollTo(0,Math.max(0,offset));
        });
    }

    private void showResult(String text) {
        appendChat("Anamika",text);
    }

    private void speak(String text) {
        stopWakeRecognizer();
        pauseBackgroundWakeService();
        if (tts != null && text != null && !text.trim().isEmpty()) {
            Locale desired=UniversalLanguageRouter.speechLocaleFor(text);
            int lang=tts.setLanguage(desired);
            if(lang==TextToSpeech.LANG_MISSING_DATA || lang==TextToSpeech.LANG_NOT_SUPPORTED){
                lang=tts.setLanguage(new Locale("hi","IN"));
                if(lang==TextToSpeech.LANG_MISSING_DATA || lang==TextToSpeech.LANG_NOT_SUPPORTED){
                    tts.setLanguage(Locale.US);
                }
            }
            String clean=text.trim();
            int max=Math.max(800,Math.min(3400,TextToSpeech.getMaxSpeechInputLength()-100));
            int pos=0,part=0;
            while(pos<clean.length()){
                int end=Math.min(clean.length(),pos+max);
                if(end<clean.length()){
                    int cut=clean.lastIndexOf(' ',end);
                    if(cut>pos+200) end=cut;
                }
                String chunk=clean.substring(pos,end).trim();
                if(!chunk.isEmpty()){
                    tts.speak(chunk,part==0?TextToSpeech.QUEUE_FLUSH:TextToSpeech.QUEUE_ADD,null,
                            "anamika_reply_"+part);
                    part++;
                }
                pos=end;
                while(pos<clean.length() && Character.isWhitespace(clean.charAt(pos))) pos++;
            }
        }
        long delay=Math.min(60000L,1800L+(text==null?0:text.length()*48L));
        mainHandler.postDelayed(this::resumeBackgroundWakeService,delay);
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onInit(int statusCode) {
        if (statusCode == TextToSpeech.SUCCESS) {
            int r=tts.setLanguage(new Locale("hi","IN"));
            if(r==TextToSpeech.LANG_MISSING_DATA || r==TextToSpeech.LANG_NOT_SUPPORTED){
                r=tts.setLanguage(Locale.getDefault());
                if(r==TextToSpeech.LANG_MISSING_DATA || r==TextToSpeech.LANG_NOT_SUPPORTED) tts.setLanguage(Locale.US);
            }
            tts.setSpeechRate(0.95f);
        }
    }

    @Override
    protected void onResume(){
        super.onResume();
        if(prefs!=null && OwnerSession.isTrusted(this)){
            unlocked=OwnerSession.isActive(this);
            if(unlocked){
                prefs.edit().putBoolean("wake_enabled",true).apply();
                if(!BackgroundWakeService.isRunning()){
                    mainHandler.postDelayed(this::startBackgroundWakeService,300L);
                }
            }
        }
    }

    @Override
    protected void onDestroy() {
        mainHandler.removeCallbacksAndMessages(null);
        stopWakeRecognizer();
        if (tts != null) {
            tts.stop();
            tts.shutdown();
        }
        super.onDestroy();
    }
}
