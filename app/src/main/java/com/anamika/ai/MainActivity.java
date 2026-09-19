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
import com.anamika.ai.research.AppSearchController;
import com.anamika.ai.research.ResearchLearningStore;
import com.anamika.ai.upgrade.SelfUpgradeWorkspace;

public class MainActivity extends Activity implements TextToSpeech.OnInitListener {
    private static final int REQ_SPEECH = 1001;
    private static final int REQ_AUDIO = 1002;

    private TextToSpeech tts;
    private SharedPreferences prefs;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private SpeechRecognizer wakeRecognizer;
    private boolean wakeAwaitingCommand = false;
    private boolean pendingWakePermission = false;
    private Button wakeListenButton;
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
        Button testLabButton = findViewById(R.id.testLabButton);
        Button languageStatusButton = findViewById(R.id.languageStatusButton);
        wakeListenButton = findViewById(R.id.wakeListenButton);
        result.setMovementMethod(new ScrollingMovementMethod());

        boolean ownerPinAlreadySet = OwnerAuth.hasPin(this);
        unlockButton.setText(ownerPinAlreadySet ? "Unlock Owner" : "Set Owner PIN");

        unlockButton.setOnClickListener(v -> unlockOwner(unlockButton));
        listenButton.setOnClickListener(v -> startListening());
        runButton.setOnClickListener(v -> {
            String typed=commandInput.getText().toString().trim();
            if(!typed.isEmpty()){
                runCommand(typed);
                commandInput.setText("");
            }
        });
        wakeListenButton.setText(prefs.getBoolean("wake_enabled",true)
                ? "Hello Anamika Listening: ON"
                : "Hello Anamika Listening: OFF");
        wakeListenButton.setOnClickListener(v -> toggleWakeListening());
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
        languageStatusButton.setOnClickListener(v -> {
            if (ensureUnlocked()) answer(UniversalLanguageRouter.capability(this));
        });

        if (!ownerPinAlreadySet) {
            status.setText("First launch • Owner PIN not set");
            result.setText("Enter any 4–12 digit PIN in the Owner PIN box, then tap SET OWNER PIN. This becomes your owner unlock code.");
        } else {
            status.setText("Locked • enter Owner PIN");
            result.setText("Enter your existing Owner PIN, then tap UNLOCK OWNER.");
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
                prefs.edit().remove(PIN_FAILS).remove(PIN_LOCK_UNTIL).apply();
                status.setText("Owner verified • unlocked");
                unlockButton.setText("Unlock Owner");
                result.setText(firstSetup
                        ? "Owner PIN set successfully. Anamika is unlocked and ready."
                        : "Owner unlocked. Anamika is ready.");
                speak(firstSetup ? "Owner lock set. Anamika is ready." : "Welcome back. Anamika is ready.");
                if(prefs.getBoolean("wake_enabled",true)){
                    mainHandler.postDelayed(() -> enableWakeListening(false),1800L);
                }
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
                    startWakeRecognizer();
                } else {
                    startListening();
                }
            } else {
                showResult("Microphone permission is required for voice commands. Typed commands still work.");
            }
        }
    }

    private void runCommand(String raw) {
        if (!ensureUnlocked()) return;
        String original=raw==null?"":raw.trim();
        if(!original.isEmpty()) appendChat("You",original);
        String command = UniversalLanguageRouter.normalize(this, original);
        if (command.isEmpty()) {
            showResult("Please speak or type a command.");
            return;
        }

        String lower = command.toLowerCase(Locale.ROOT);
        prefs.edit().putString("last_command", command).apply();

        if (containsAny(lower, "hello", "hi anamika", "namaste", "नमस्ते")) {
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
            answer("Plugin Center khol diya. Sirf owner-enabled apps par control allowed hai.");
            return;
        }

        if (containsAny(lower, "settings", "setting kholo", "सेटिंग")) {
            startActivity(new Intent(Settings.ACTION_SETTINGS));
            answer("Phone settings khol di.");
            return;
        }

        answer("Command directly map nahi hua. Universal language mode text ko local model se normalize karne ki koshish karta hai. Aap Google/YouTube search, research mode, open app, developer mode, cinematic creator, plugin center, self upgrade, settings ya update bol sakte hain.");
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
                            "FULL VERIFIED: " + generated.compilerVerification.isFullyVerified() + "\n\n" +
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
        String n = appName.toLowerCase(Locale.ROOT);
        String pkg = null;
        if (n.contains("whatsapp")) pkg = "com.whatsapp";
        else if (n.contains("youtube")) pkg = "com.google.android.youtube";
        else if (n.contains("chrome")) pkg = "com.android.chrome";
        else if (n.contains("instagram")) pkg = "com.instagram.android";
        else if (n.contains("telegram")) pkg = "org.telegram.messenger";

        if (pkg == null) {
            pkg = com.anamika.ai.plugins.PluginRegistry.findPackageByLabel(this, appName);
            if (pkg == null) {
                webSearch(appName);
                answer("Installed app label match nahi mila, isliye search khol di.");
                return;
            }
        }

        Intent launch = getPackageManager().getLaunchIntentForPackage(pkg);
        if (launch != null) {
            startActivity(launch);
            answer(appName + " khol diya.");
        } else {
            answer(appName + " installed nahi mila.");
        }
    }

    private void toggleWakeListening(){
        if(!ensureUnlocked()) return;
        boolean enable=!prefs.getBoolean("wake_enabled",true);
        prefs.edit().putBoolean("wake_enabled",enable).apply();
        wakeListenButton.setText(enable?"Hello Anamika Listening: ON":"Hello Anamika Listening: OFF");
        if(enable) enableWakeListening(true);
        else {
            wakeAwaitingCommand=false;
            stopWakeRecognizer();
            status.setText("Owner verified • wake listening off");
        }
    }

    private void enableWakeListening(boolean announce){
        if(!unlocked || !OwnerSession.isActive(this)) return;
        if(!prefs.getBoolean("wake_enabled",true)) return;
        if(!SpeechRecognizer.isRecognitionAvailable(this)){
            wakeListenButton.setText("Hello Anamika Listening: unavailable");
            if(announce) answer("Is phone par SpeechRecognizer service available nahi hai.");
            return;
        }
        if(checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){
            pendingWakePermission=true;
            requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},REQ_AUDIO);
            return;
        }
        startWakeRecognizer();
        if(announce) answer("Hello Anamika listening on hai. Screen open ho to “Hello Anamika” boliye.");
    }

    private void startWakeRecognizer(){
        if(!prefs.getBoolean("wake_enabled",true) || !unlocked || !OwnerSession.isActive(this)) return;
        stopWakeRecognizer();
        wakeRecognizer=SpeechRecognizer.createSpeechRecognizer(this);
        wakeRecognizer.setRecognitionListener(new RecognitionListener(){
            @Override public void onReadyForSpeech(Bundle params){ status.setText(wakeAwaitingCommand?"Listening for your command…":"Wake listening • say Hello Anamika"); }
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
        Matcher wake=Pattern.compile("(?i)(?:hello|hey|hi)\\s+anamika").matcher(heard);
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
        if(prefs!=null && prefs.getBoolean("wake_enabled",true) && unlocked && OwnerSession.isActive(this)){
            startWakeRecognizer();
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
        if(!isAutomationServiceEnabled()){
            answer("WhatsApp control ke liye Android Accessibility me Anamika App Control ek baar enable karna hoga. Settings khol rahi hoon.");
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
            return true;
        }
        String pkg="com.whatsapp";
        com.anamika.ai.plugins.PluginRegistry.setEnabled(this,pkg,true);
        getSharedPreferences("anamika_automation",MODE_PRIVATE).edit().putString("target_package",pkg).apply();
        String r=com.anamika.ai.plugins.AppPluginEngine.openAndRun(this,pkg,
                "whatsapp-message|"+recipient+"|"+message);
        answer("WhatsApp me "+recipient+" ko message bhejne ka command diya: “"+message+"”. "+r);
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
        if(!isAutomationServiceEnabled()){
            answer("Full automatic app audit ke liye Android Accessibility me Anamika App Control ek baar enable karna hoga. Settings khol rahi hoon.");
            startActivity(new Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS));
            return;
        }
        com.anamika.ai.plugins.PluginRegistry.setEnabled(this,pkg,true);
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
            developerPrompt.setText("Upgrade Anamika itself. Owner request: " + request + "\nUse the bundled current-source snapshot from: " + workspace.getAbsolutePath() + "\nPreserve owner approval, rollback and validation gates. Generate changed files only after analysing current source.");
            answer("Self-upgrade workspace ready. Current source snapshot extracted locally. Review the generated changes before any APK build/install: " + workspace.getAbsolutePath());
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
        if (tts != null) tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "anamika_reply");
        long delay=Math.min(6500L,1800L+(text==null?0:text.length()*35L));
        restartWakeSoon(delay);
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onInit(int statusCode) {
        if (statusCode == TextToSpeech.SUCCESS) {
            Locale preferred = Locale.getDefault();
            int r = tts.setLanguage(preferred);
            if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                r = tts.setLanguage(new Locale("hi", "IN"));
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) tts.setLanguage(Locale.US);
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
