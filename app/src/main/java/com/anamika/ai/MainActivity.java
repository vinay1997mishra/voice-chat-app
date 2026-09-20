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
import com.anamika.ai.voice.SoftVoiceProfile;
import com.anamika.ai.behavior.RuntimeBehaviorPreferences;
import com.anamika.ai.phone.PhoneAssistantController;
import com.anamika.ai.phone.CalculatorEngine;
import com.anamika.ai.files.FileExportManager;
import com.anamika.ai.media.VideoEditEngine;
import com.anamika.ai.media.PhotoEditEngine;
import com.anamika.ai.files.StorageLibrary;
import com.anamika.ai.files.AnamikaVault;
import com.anamika.ai.phone.PermissionAccessManager;
import com.anamika.ai.phone.DeviceFunctionDiscovery;
import com.anamika.ai.phone.DeviceProfileStore;
import com.anamika.ai.research.AppSearchController;
import com.anamika.ai.research.BackgroundKnowledgeLookup;
import com.anamika.ai.research.ResearchLearningStore;
import com.anamika.ai.upgrade.SelfUpgradeWorkspace;

public class MainActivity extends Activity implements TextToSpeech.OnInitListener {
    private static final int REQ_SPEECH = 1001;
    private static final int REQ_AUDIO = 1002;
    private static final int REQ_CONTACTS = 1003;
    private static final int REQ_CALL = 1004;
    private static final int REQ_PICK_FILES = 1801;
    private static final int REQ_PICK_TREE = 1802;

    private TextToSpeech tts;
    private SharedPreferences prefs;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private SpeechRecognizer wakeRecognizer;
    private boolean wakeAwaitingCommand = false;
    private boolean pendingWakePermission = false;
    private String pendingPhoneCommand = "";
    private String pendingCallNumber = "";
    private String pendingCallName = "";
    private boolean permissionSetupActive = false;
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
        DeviceProfileStore.ensureSaved(this);
        SoftVoiceProfile.ensureDefaults(this);
        RuntimeBehaviorPreferences.ensureDefaults(this);
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
        Button attachButton = findViewById(R.id.attachButton);
        Button menuButton = findViewById(R.id.menuButton);
        Button toolsCloseButton = findViewById(R.id.toolsCloseButton);
        Button imageCreatorMenuButton = findViewById(R.id.imageCreatorMenuButton);
        Button projectMenuButton = findViewById(R.id.projectMenuButton);
        Button memoryMenuButton = findViewById(R.id.memoryMenuButton);
        Button voiceMenuButton = findViewById(R.id.voiceMenuButton);
        Button remoteMenuButton = findViewById(R.id.remoteMenuButton);
        Button vaultMenuButton = findViewById(R.id.vaultMenuButton);
        Button deviceInfoMenuButton = findViewById(R.id.deviceInfoMenuButton);
        Button settingsMenuButton = findViewById(R.id.settingsMenuButton);
        Button permissionSetupButton = findViewById(R.id.permissionSetupButton);
        Button storageSetupButton = findViewById(R.id.storageSetupButton);
        View toolsPanel = findViewById(R.id.toolsPanel);
        View menuDim = findViewById(R.id.menuDim);
        View ownerBar = findViewById(R.id.ownerBar);
        wakeListenButton = findViewById(R.id.wakeListenButton);
        forgetOwnerButton = findViewById(R.id.forgetOwnerButton);
        result.setMovementMethod(new ScrollingMovementMethod());

        boolean ownerPinAlreadySet = OwnerAuth.hasPin(this);
        boolean ownerRemembered = OwnerSession.isTrusted(this);
        unlocked = OwnerSession.isActive(this);
        unlockButton.setText(ownerPinAlreadySet ? "Unlock Owner" : "Set Owner PIN");
        pinInput.setVisibility(ownerRemembered ? View.GONE : View.VISIBLE);
        unlockButton.setVisibility(ownerRemembered ? View.GONE : View.VISIBLE);
        forgetOwnerButton.setVisibility(ownerRemembered ? View.GONE : View.GONE);
        ownerBar.setVisibility(ownerRemembered ? View.GONE : View.VISIBLE);

        unlockButton.setOnClickListener(v -> unlockOwner(unlockButton));
        listenButton.setOnClickListener(v -> startListening());
        runButton.setOnClickListener(v -> {
            String typed=commandInput.getText().toString().trim();
            if(!typed.isEmpty()){
                runCommand(typed);
                commandInput.setText("");
            }
        });
        attachButton.setOnClickListener(v -> showAttachMenu());
        menuButton.setOnClickListener(v -> showFunctionDrawer(toolsPanel,menuDim));
        toolsCloseButton.setOnClickListener(v -> hideFunctionDrawer(toolsPanel,menuDim));
        menuDim.setOnClickListener(v -> hideFunctionDrawer(toolsPanel,menuDim));

        imageCreatorMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            Intent i=new Intent(this,com.anamika.ai.creator.CreatorHubActivity.class);
            i.putExtra("media_type","image");
            i.putExtra("width",1024);
            i.putExtra("height",1024);
            startActivity(i);
            hideFunctionDrawer(toolsPanel,menuDim);
        });
        projectMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            String p=lastGeneratedProject==null?"":lastGeneratedProject.trim();
            answer(p.isEmpty()
                    ?"Projects: abhi is session me koi generated project selected nahi hai. ☰ > App / Website / Code Builder se naya project bana sakte ho."
                    :"Current project:\n"+p);
        });
        memoryMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            String note=prefs.getString("memory_note","");
            String hist=prefs.getString("conversation_history","");
            answer("Memory & Learning\nSaved note: "+(note.isEmpty()?"none":note)+
                    "\nRecent conversation memory: "+(hist.isEmpty()?"empty":"available")+
                    "\nVerified language phrases aur learned phone-functions local memory me save hote hain.");
        });
        voiceMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            answer(SoftVoiceProfile.summary(this)+
                    "\nVoice command examples: ‘voice aur soft karo’, ‘deep karo’, ‘childish karo’, ‘slow bolo’, ‘normal voice’.");
        });
        remoteMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            answer("Remote / Phone Control\n"+DeviceProfileStore.summary(this)+"\n"+
                    PermissionAccessManager.status(this)+
                    "\nSettings, apps, contacts, calls, messages, screen reading aur verified device controls voice/text command se use hote hain.");
        });
        vaultMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            answer(AnamikaVault.summary(this)+"\n"+StorageLibrary.summary(this));
        });
        deviceInfoMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            answer(DeviceProfileStore.summary(this));
        });
        settingsMenuButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            startActivity(new Intent(Settings.ACTION_SETTINGS));
        });
        permissionSetupButton.setOnClickListener(v -> {
            hideFunctionDrawer(toolsPanel,menuDim);
            startOneTimePermissionSetup();
        });
        storageSetupButton.setOnClickListener(v -> {
            hideFunctionDrawer(toolsPanel,menuDim);
            pickStorageTree();
        });
        if(ownerRemembered){
            prefs.edit().putBoolean("wake_enabled",true).apply();
        }
        wakeListenButton.setText(ownerRemembered
                ? "24×7 Hello Mika / Hello Anamika: ALWAYS ON"
                : "24×7 Wake starts after first Owner setup");
        wakeListenButton.setOnClickListener(v -> {
            if(!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
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
            View ob=findViewById(R.id.ownerBar); if(ob!=null) ob.setVisibility(View.VISIBLE);
            status.setText("Owner login forgotten • PIN required");
            result.setText("Owner login is no longer remembered on this device. Enter your existing PIN to verify again.");
        });
        generateCodeButton.setOnClickListener(v -> generateDeveloperProject());
        saveProjectButton.setOnClickListener(v -> saveGeneratedProject());
        premium3dButton.setOnClickListener(v -> {
            if (ensureUnlocked()) {
                hideFunctionDrawer(toolsPanel,menuDim);
                startActivity(new Intent(this, com.anamika.ai.media3d.Premium3DActivity.class));
            }
        });
        internetCreatorButton.setOnClickListener(v -> {
            if (ensureUnlocked()) {
                hideFunctionDrawer(toolsPanel,menuDim);
                startActivity(new Intent(this, com.anamika.ai.creator.CreatorHubActivity.class));
            }
        });
        pluginCenterButton.setOnClickListener(v -> {
            if (ensureUnlocked()) {
                hideFunctionDrawer(toolsPanel,menuDim);
                startActivity(new Intent(this, com.anamika.ai.plugins.PluginManagerActivity.class));
            }
        });
        researchButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            String q = commandInput.getText().toString().trim();
            if (q.isEmpty()) q = "owner research session";
            String path = ResearchLearningStore.start(this, q);
            answer("Research mode started. Visible/public screens you open can be saved to local knowledge: " + path);
        });
        testLabButton.setOnClickListener(v -> {
            if (ensureUnlocked()) {
                hideFunctionDrawer(toolsPanel,menuDim);
                startActivity(new Intent(this, TestLabActivity.class));
            }
        });
        selfUpgradeButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
            prepareSelfUpgrade("Owner requested self-upgrade workspace from V7.8.2 UI.");
        });
        secureSelfUpdateButton.setOnClickListener(v -> {
            if (ensureUnlocked()) {
                hideFunctionDrawer(toolsPanel,menuDim);
                startActivity(new Intent(this, SelfUpdateActivity.class));
            }
        });
        languageStatusButton.setOnClickListener(v -> {
            if (!ensureUnlocked()) return;
            hideFunctionDrawer(toolsPanel,menuDim);
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

    private void showFunctionDrawer(View drawer,View dim){
        if(drawer==null||dim==null)return;
        dim.setVisibility(View.VISIBLE);
        drawer.setVisibility(View.VISIBLE);
        drawer.setTranslationX(-drawer.getWidth());
        drawer.animate().translationX(0f).setDuration(180L).start();
    }

    private void hideFunctionDrawer(View drawer,View dim){
        if(drawer==null||dim==null)return;
        if(drawer.getVisibility()!=View.VISIBLE){
            dim.setVisibility(View.GONE);
            return;
        }
        float width=drawer.getWidth()>0?drawer.getWidth():330f;
        drawer.animate().translationX(-width).setDuration(160L).withEndAction(() -> {
            drawer.setVisibility(View.GONE);
            drawer.setTranslationX(0f);
            dim.setVisibility(View.GONE);
        }).start();
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
                forgetOwnerButton.setVisibility(View.GONE);
                View ob=findViewById(R.id.ownerBar); if(ob!=null) ob.setVisibility(View.GONE);
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
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS,
                RuntimeBehaviorPreferences.silenceMs(this));
        intent.putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS,
                RuntimeBehaviorPreferences.silenceMs(this));
        // Do not hard-code Hindi/English. Let the installed speech service use its multilingual/auto-detect capability.
        intent.putExtra("android.speech.extra.ENABLE_LANGUAGE_DETECTION", true);
        intent.putExtra("android.speech.extra.ENABLE_LANGUAGE_SWITCH", "balanced");
        intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "hi-IN");
        intent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
        intent.putStringArrayListExtra("android.speech.extra.LANGUAGE_DETECTION_ALLOWED_LANGUAGES",
                new java.util.ArrayList<>(java.util.Arrays.asList("hi-IN", "ur-IN", "en-IN")));
        intent.putStringArrayListExtra("android.speech.extra.LANGUAGE_SWITCH_ALLOWED_LANGUAGES",
                new java.util.ArrayList<>(java.util.Arrays.asList("hi-IN", "ur-IN", "en-IN")));
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
        if(requestCode==REQ_PICK_FILES && resultCode==RESULT_OK && data!=null){
            importPickedFiles(data);
            return;
        }
        if(requestCode==REQ_PICK_TREE && resultCode==RESULT_OK && data!=null && data.getData()!=null){
            Uri tree=data.getData();
            int flags=data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            try{getContentResolver().takePersistableUriPermission(tree,flags);}catch(Exception ignored){}
            StorageLibrary.saveTree(this,tree);
            answer("Storage folder access save ho gaya. Next time is folder ke liye permission repeat nahi hogi.\n"+StorageLibrary.summary(this));
            return;
        }
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
        } else if(requestCode==PermissionAccessManager.REQ_ALL_RUNTIME){
            if(permissionSetupActive) mainHandler.postDelayed(this::continueOneTimePermissionSetup,400L);
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
        String behaviorUpdate=RuntimeBehaviorPreferences.applyOwnerCommand(this,original);
        if(!behaviorUpdate.isEmpty()){
            answer("Theek hai, ye change bina coding ke save kar liya. "+behaviorUpdate);
            return;
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

        if ("SETTINGS".equals(interpretation.intent)) {
            String stripped=original.replaceAll("(?i)(settings?|setting|सेटिंग्स?|khol|kholo|open|dhundo|search|change|badlo|बदलो|खोलो|खोजो)"," ")
                    .replaceAll("\\s+"," ").trim();
            if(stripped.isEmpty()) {
                startActivity(new Intent(Settings.ACTION_SETTINGS));
                answerForStyle(interpretation.style,"सेटिंग्स खोल दी।","Settings khol di.","Settings opened.");
            } else {
                answer(PhoneAssistantController.openAndSearchSetting(this,stripped));
            }
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

        if ("MEDIA".equals(interpretation.intent)) {
            handleMediaCommand(original,interpretation.style);
            return;
        }

        if ("VAULT_STATUS".equals(interpretation.intent)) {
            answer(AnamikaVault.summary(this)+"\n"+StorageLibrary.summary(this));
            return;
        }

        if ("FILE_SEARCH".equals(interpretation.intent)) {
            handleFileSearch(original,interpretation.style);
            return;
        }

        if ("FILE_EXPORT".equals(interpretation.intent)) {
            exportLastVaultFile(interpretation.style);
            return;
        }

        if ("FILE_DELETE".equals(interpretation.intent)) {
            handleVaultDelete(original,interpretation.style);
            return;
        }

        if ("SELF_UPGRADE".equals(interpretation.intent)) {
            prepareSelfUpgrade(original);
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

        if (containsAny(lower,"voice soft","voice softer","awaz soft","awaaz soft","voice deep","awaaz deep",
                "voice loud","awaaz loud","voice childish","bacchi jaisi voice","childish voice","voice young",
                "voice mature","voice slow","voice fast","voice reset","normal voice","default voice",
                "आवाज सॉफ्ट","आवाज गहरी","आवाज धीमी","आवाज तेज")) {
            String profile=SoftVoiceProfile.tune(this,original);
            answer("Theek hai. "+profile);
            return;
        }

        if (containsAny(lower,"phone model","device model","mera phone ka model","device info","phone info",
                "फोन मॉडल","डिवाइस मॉडल","फोन की जानकारी")) {
            answer(DeviceProfileStore.summary(this));
            return;
        }

        if (containsAny(lower, "settings", "setting kholo", "सेटिंग")) {
            startActivity(new Intent(Settings.ACTION_SETTINGS));
            answer("Phone settings khol di.");
            return;
        }

        // Unknown phone-control/function wording gets a silent device-function discovery first.
        // Only locally verified Android routes are persisted for next time.
        if(looksLikePhoneFunctionQuestion(original)){
            discoverUnknownPhoneFunction(original,interpretation.style);
        }else if(original.length()<=120 && original.trim().split("\\s+").length<=10){
            lookupUnknownMeaning(original,interpretation.style);
        }else{
            answerWithLocalConversation(original,interpretation.style);
        }
    }

    private void handleMediaCommand(String original,UniversalLanguageRouter.Style style){
        String lower=original.toLowerCase(Locale.ROOT);

        boolean animeRequested=containsAny(lower,"anime","एनिमे");
        boolean storyAnime=animeRequested && containsAny(lower,"story","kahani","कहानी","स्टोरी");
        if(animeRequested){
            Intent ai=new Intent(this,com.anamika.ai.creator.CreatorHubActivity.class);
            ai.putExtra("media_type","video");
            ai.putExtra("prompt",original);
            ai.putExtra("workflow",storyAnime?"story_to_anime":"video_to_anime");
            ai.putExtra("width",lower.contains("9:16")?1080:1920);
            ai.putExtra("height",lower.contains("9:16")?1920:1080);
            if(!storyAnime){
                String last=prefs.getString("last_vault_file","");
                String mime=prefs.getString("last_vault_mime","");
                if(!last.isEmpty() && mime.startsWith("video/")) ai.putExtra("source_video_path",last);
            }
            startActivity(ai);
            answerForStyle(style,
                    storyAnime
                            ?"Anime story creator खोल दिया है। Story, scenes और अलग-अलग natural character voices के साथ video generate होगा।"
                            :"Anime video converter खोल दिया है। Last uploaded video को anime look और natural anime-style voice treatment के साथ process किया जा सकता है.",
                    storyAnime
                            ?"Anime story creator khol diya hai. Story, scenes aur alag-alag natural character voices ke saath video generate hoga."
                            :"Anime video converter khol diya hai. Last uploaded video ko anime look aur natural anime-style voice treatment ke saath process kiya ja sakta hai.",
                    storyAnime
                            ?"Anime story creator opened with multi-character natural voice generation."
                            :"Anime video converter opened for visual transformation and natural character-style voice treatment.");
            return;
        }

        boolean create=containsAny(lower,"banao","bana do","create","generate","new photo","new image","new video","बनाओ","बना दो");
        if(create){
            Intent i=new Intent(this,com.anamika.ai.creator.CreatorHubActivity.class);
            i.putExtra("prompt",original);
            i.putExtra("media_type",(lower.contains("photo")||lower.contains("pic")||lower.contains("image")||lower.contains("फोटो"))?"image":"video");
            java.util.regex.Matcher m=java.util.regex.Pattern.compile("(\\d{2,5})\\s*[x×]\\s*(\\d{2,5})").matcher(lower);
            if(m.find()){
                i.putExtra("width",Integer.parseInt(m.group(1)));
                i.putExtra("height",Integer.parseInt(m.group(2)));
            }else if(lower.contains("9:16")){
                i.putExtra("width",1080);i.putExtra("height",1920);
            }else if(lower.contains("1:1")||lower.contains("square")){
                i.putExtra("width",1080);i.putExtra("height",1080);
            }else{
                i.putExtra("width",1920);i.putExtra("height",1080);
            }
            startActivity(i);
            answerForStyle(style,
                    "Creator खोल दिया है। आपका prompt और size उसमें डाल दिया है।",
                    "Creator khol diya hai. Tumhara prompt aur size usme daal diya hai.",
                    "Creator opened with your prompt and requested size.");
            return;
        }

        String p=prefs.getString("last_vault_file","");
        String mime=prefs.getString("last_vault_mime","");
        java.io.File src=new java.io.File(p);
        if(!src.isFile()){
            answerForStyle(style,
                    "पहले + से photo या video upload करें। फिर edit command सीधे उसी file पर चलेगी।",
                    "Pehle + se photo ya video upload karo. Phir edit command directly us file par chalegi.",
                    "Upload a photo or video with + first, then the edit command will run on that file.");
            return;
        }

        showResult("Anamika: media edit process kar rahi hoon…");
        new Thread(() -> {
            try{
                if(mime.startsWith("image/")){
                    PhotoEditEngine.Result out=PhotoEditEngine.edit(MainActivity.this,src,original);
                    runOnUiThread(() -> answer("Photo edit complete • "+out.width+"×"+out.height+" • "+
                            AnamikaVault.human(out.file.length())+"\nSaved in Personal Space: "+out.file.getName()));
                }else if(mime.startsWith("video/")){
                    VideoEditEngine.Result out=VideoEditEngine.edit(MainActivity.this,src,original);
                    runOnUiThread(() -> answer("Video edit complete • "+out.startSec+"s to "+out.endSec+"s"+
                            (out.muted?" • audio muted":"")+" • "+AnamikaVault.human(out.file.length())+
                            "\nSaved in Personal Space: "+out.file.getName()));
                }else{
                    runOnUiThread(() -> answer("Last saved file photo/video nahi hai. + se media upload karo."));
                }
            }catch(Exception e){
                runOnUiThread(() -> answer("Media edit error: "+e.getMessage()));
            }
        },"AnamikaMediaEdit").start();
    }

    private void showAttachMenu(){
        if(!ensureUnlocked()) return;
        String[] items={"Upload file / photo / video","Personal Space status","Choose storage folder once",
                "One-time phone access setup","Photo/Video creator","App control / deep audit"};
        new AlertDialog.Builder(this).setTitle("Add to Anamika").setItems(items,(d,which)->{
            if(which==0) pickFiles();
            else if(which==1) answer(AnamikaVault.summary(this)+"\n"+StorageLibrary.summary(this));
            else if(which==2) pickStorageTree();
            else if(which==3) startOneTimePermissionSetup();
            else if(which==4) startActivity(new Intent(this,com.anamika.ai.creator.CreatorHubActivity.class));
            else if(which==5) startActivity(new Intent(this,com.anamika.ai.plugins.PluginManagerActivity.class));
        }).show();
    }

    private void pickFiles(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        i.putExtra(Intent.EXTRA_ALLOW_MULTIPLE,true);
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(i,REQ_PICK_FILES);
    }

    private void pickStorageTree(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION|Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);
        startActivityForResult(i,REQ_PICK_TREE);
    }

    private void importPickedFiles(Intent data){
        java.util.ArrayList<Uri> uris=new java.util.ArrayList<>();
        if(data.getData()!=null) uris.add(data.getData());
        if(data.getClipData()!=null){
            for(int i=0;i<data.getClipData().getItemCount();i++) uris.add(data.getClipData().getItemAt(i).getUri());
        }
        if(uris.isEmpty()) return;
        showResult("Anamika: "+uris.size()+" file(s) Personal Space me import kar rahi hoon…");
        new Thread(() -> {
            int ok=0; long bytes=0; String last="";
            for(Uri u:uris){
                try{
                    try{getContentResolver().takePersistableUriPermission(u,Intent.FLAG_GRANT_READ_URI_PERMISSION);}catch(Exception ignored){}
                    AnamikaVault.Entry e=AnamikaVault.importUri(MainActivity.this,u);
                    ok++;bytes+=e.size;last=e.name;
                }catch(Exception ignored){}
            }
            final int fOk=ok; final long fBytes=bytes; final String fLast=last;
            runOnUiThread(() -> answer(fOk+" file(s) save ho gayi • "+AnamikaVault.human(fBytes)+
                    (fLast.isEmpty()?"":" • Last: "+fLast)+"\n"+AnamikaVault.summary(this)));
        },"AnamikaFileImport").start();
    }

    private void startOneTimePermissionSetup(){
        if(!ensureUnlocked()) return;
        permissionSetupActive=true;
        continueOneTimePermissionSetup();
    }

    private void continueOneTimePermissionSetup(){
        if(!permissionSetupActive) return;
        String[] missing=PermissionAccessManager.missingRuntimePermissions(this);
        if(missing.length>0){
            requestPermissions(missing,PermissionAccessManager.REQ_ALL_RUNTIME);
            return;
        }
        if(!PermissionAccessManager.hasAllFilesAccess()){
            showResult("Anamika: Android All Files Access screen khol rahi hoon. “Allow access to manage all files” ON kar do; phir main setup continue karungi.");
            PermissionAccessManager.openAllFilesAccess(this);
            return;
        }
        if(!PermissionAccessManager.canWriteSystemSettings(this)){
            showResult("Anamika: Modify system settings access ON kar do; brightness jaise controls direct change ho sakenge.");
            PermissionAccessManager.openWriteSettings(this);
            return;
        }
        if(!PermissionAccessManager.isAccessibilityEnabled(this)){
            showResult("Anamika: Accessibility me “Anamika App Control” ON kar do. Isse screen read, taps, app control aur settings automation chalega.");
            PermissionAccessManager.openAccessibility(this);
            return;
        }
        permissionSetupActive=false;
        answer("One-time assistant access setup complete. "+PermissionAccessManager.status(this));
    }

    private void handleFileSearch(String original,UniversalLanguageRouter.Style style){
        String q=original.replaceAll("(?i)(phone|mobile|storage|file|files|photo|pic|image|video|pdf|document|audio|dhundo|dhoondo|search|find|khojo|karo|kar|मेरे|फोन|फाइल|फोटो|वीडियो|पीडीएफ|ढूंढो|खोजो|सर्च)"," ")
                .replaceAll("\\s+"," ").trim();
        if(q.isEmpty()) q="";
        final String query=q;
        showResult("Anamika: phone storage search kar rahi hoon…");
        new Thread(() -> {
            java.util.List<StorageLibrary.Item> items=StorageLibrary.search(MainActivity.this,query,30);
            StringBuilder out=new StringBuilder();
            out.append("File search: ").append(query.isEmpty()?"all":query).append("\n");
            if(items.isEmpty()) out.append("Koi matching file nahi mili. ").append(StorageLibrary.summary(MainActivity.this));
            else{
                for(int i=0;i<items.size();i++) out.append(i+1).append(". ").append(items.get(i).line()).append("\n");
                out.append("Showing ").append(items.size()).append(" result(s).");
            }
            runOnUiThread(() -> answer(out.toString()));
        },"AnamikaStorageSearch").start();
    }

    private void exportLastVaultFile(UniversalLanguageRouter.Style style){
        String p=prefs.getString("last_vault_file","");
        if(p.isEmpty()||!new java.io.File(p).isFile()){
            answerForStyle(style,"कोई last saved file नहीं मिली।","Koi last saved file nahi mili.","No last saved file was found.");
            return;
        }
        java.io.File f=new java.io.File(p);
        String mime=prefs.getString("last_vault_mime","application/octet-stream");
        new Thread(() -> {
            try{
                Uri out=FileExportManager.exportToDownloads(MainActivity.this,f,mime);
                runOnUiThread(() -> answer("Downloads/Anamika me export ho gaya: "+f.getName()));
            }catch(Exception e){
                runOnUiThread(() -> answer("Export error: "+e.getMessage()));
            }
        },"AnamikaExport").start();
    }

    private void handleVaultDelete(String original,UniversalLanguageRouter.Style style){
        String q=original.replaceAll("(?i)(file|delete|hatao|hata|hta|trash|karo|kar|फाइल|डिलीट|हटाओ|करो)"," ")
                .replaceAll("\\s+"," ").trim();
        if(q.isEmpty()){
            answerForStyle(style,"कौन सी file हटानी है?","Kaunsi file hatani hai?","Which file should I remove?");
            return;
        }
        boolean ok=AnamikaVault.moveToTrash(this,q);
        answer(ok?"File Personal Space trash me move kar di: "+q:"Matching saved file nahi mili: "+q);
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

    private boolean looksLikePhoneFunctionQuestion(String raw){
        if(raw==null)return false;
        String s=raw.toLowerCase(Locale.ROOT);
        return containsAny(s,
                "setting","settings","phone me","mobile me","control","function","feature","option",
                "kaha hai","kahan hai","kaise on","kaise off","kaise change","kaise set",
                "सेटिंग","फोन में","कंट्रोल","फंक्शन","फीचर","ऑप्शन","कहाँ है","कैसे ऑन","कैसे ऑफ");
    }

    private void discoverUnknownPhoneFunction(String original,UniversalLanguageRouter.Style style){
        showResult(style==UniversalLanguageRouter.Style.HINDI
                ?"फोन का सही फ़ंक्शन background में ढूंढ और verify कर रही हूँ…"
                :"Phone function background me search karke verify kar rahi hoon…");
        DeviceFunctionDiscovery.discover(this,original,r -> {
            if(r.verified){
                if(r.fromMemory){
                    answer("Saved settings page is still available. "+r.explanation);
                } else {
                    answer("Settings page mili hai. Function ka kaam karna abhi confirm karna hai. "+r.explanation);
                    new android.app.AlertDialog.Builder(this)
                            .setTitle("Remember this settings page?")
                            .setMessage(original+"\n\n"+r.explanation+"\n\nAndroid can open this page; this does not prove the requested setting changed.")
                            .setPositiveButton("Confirm & save", (dialog, which) -> {
                                if(!ensureUnlocked()) return;
                                boolean saved=VerifiedFunctionMemory.verifyAndSaveIntent(this,original,r.action,r.explanation);
                                answer(saved?"Settings page aapki confirmation ke baad save ho gayi.":"Page ab available nahi hai; save nahi kiya.");
                            })
                            .setNegativeButton("Not now",null).show();
                }
            }else if(r.found){
                String msg=style==UniversalLanguageRouter.Style.HINDI
                        ?"Possible function मिला, लेकिन इस phone पर verify नहीं हुआ इसलिए save नहीं किया। "
                        :"Possible function mila, lekin is phone par verify nahi hua isliye save nahi kiya. ";
                answer(msg+r.explanation);
            }else{
                lookupUnknownMeaning(original,style);
            }
        });
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

    private String compactConversationHistory(String history,int maxLines,int maxChars){
        if(history==null||history.trim().isEmpty()) return "";
        String[] lines=history.split("\\n");
        StringBuilder out=new StringBuilder();
        int start=Math.max(0,lines.length-Math.max(1,maxLines));
        for(int i=start;i<lines.length;i++){
            String line=lines[i].trim();
            if(line.isEmpty()) continue;
            if(out.length()>0) out.append('\n');
            out.append(line);
        }
        String s=out.toString();
        if(s.length()>maxChars) s=s.substring(s.length()-maxChars);
        return s;
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
                    String history=compactConversationHistory(prefs.getString("conversation_history",""),6,1800);
                    String prompt="You are Anamika AI, the owner's personal on-device assistant. "+
                            "Understand natural human language, including Hindi, Hinglish, English and mixed speech. "+
                            UniversalLanguageRouter.replyInstruction(replyStyle)+" "+
                            (RuntimeBehaviorPreferences.fullReply(MainActivity.this)
                                    ?"Give a complete useful answer. Do not shorten merely for speed; include all important points while staying focused. "
                                    :"Keep the answer concise unless detail is requested. ")+
                            "Do not mention intent parsing, keyword maps or model internals. "+
                            "If the user asks for an action you cannot actually execute in this reply, explain the next concrete action instead of pretending it happened. "+
                            (memory.isEmpty()?"":"Relevant owner memory: "+memory+" ")+
                            (history.isEmpty()?"":"Recent conversation context:\n"+history+"\n")+
                            "User: "+userText+"\nAnamika:";
                    reply=LocalModelBridge.generateFastChat(MainActivity.this,prompt);
                    if(reply==null || reply.trim().isEmpty()) throw new IllegalStateException("empty local reply");
                    reply=reply.trim();
                    int fence=reply.indexOf("~~~");
                    if(fence>=0) reply=reply.substring(0,fence).trim();
                    // Full reply mode intentionally does not hard-truncate normal answers.
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
        if(!isAutomationServiceEnabled()){
            answer("Deep discover ke liye Android Accessibility/App Control service ON honi zaroori hai. Plugin banana zaroori nahi hai. Service ON karke wahi command dobara boliye.");
            return;
        }
        getSharedPreferences("anamika_automation",MODE_PRIVATE).edit().putString("target_package",pkg).apply();
        boolean persistentPlugin=com.anamika.ai.plugins.PluginRegistry.isEnabled(this,pkg);
        String r=persistentPlugin
                ? com.anamika.ai.plugins.AppPluginEngine.openAndRun(this,pkg,"check all functions")
                : com.anamika.ai.plugins.AppPluginEngine.openAndDeepAuditOneShot(this,pkg);
        answer("Deep Discover start. "+(persistentPlugin?"Selected plugin":"One-time owner-selected non-plugin app")+
                " ko systematically map karke blueprint banaya jayega. Reachable screens, visible controls, scroll/back paths aur supported custom touch surfaces record honge. "+
                "Risky real-world action par owner confirmation li jayegi. Hidden server logic ya Android ko expose na hone wali UI ko coverage gap me clearly likha jayega. "+r);
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
            String sourceContext = SelfUpgradeWorkspace.sourceContext(workspace, 65000);
            if(sourceContext.trim().isEmpty()){
                throw new IllegalStateException("Bundled current-source context is empty.");
            }
            String upgradePrompt = "Upgrade Anamika itself. Owner request: " + request +
                    "\nYou are editing the CURRENT Anamika source shown below, not creating an unrelated demo app." +
                    "\nReturn only files that must be replaced/added, each as <<<FILE:path>>> ... <<<END FILE>>>." +
                    "\nPreserve existing package names, owner approval gates, rollback, security and working features." +
                    "\nDo not claim installation. The generated candidate will be validated, compiled where supported, saved privately, then require owner approval and a separately signed APK." +
                    "\n\nCURRENT ANAMIKA SOURCE CONTEXT:\n" + sourceContext;
            developerPrompt.setText(request);
            answer("Self-coding start kar rahi hoon. Current Anamika source ko read karke code generate, validate aur compiler-check karungi. Verified candidate hi save hoga; install owner approval ke bina nahi hoga.");

            StandaloneDeveloperEngine.generate(this, upgradePrompt, new StandaloneDeveloperEngine.Callback() {
                @Override public void onSuccess(StandaloneDeveloperEngine.Result generated) {
                    final boolean verified = generated.validation.isClean() &&
                            generated.compilerVerification.isFullyVerified();
                    if(verified){
                        try{
                            java.io.File candidate=SelfUpgradeWorkspace.saveVerifiedCandidate(
                                    MainActivity.this,workspace,generated.generatedText);
                            runOnUiThread(() -> {
                                lastGeneratedProject=generated.generatedText;
                                developerOutput.setText("SELF-UPGRADE CANDIDATE VERIFIED\nENGINE: "+generated.engine+
                                        "\nCANDIDATE: "+candidate.getAbsolutePath()+
                                        "\nSTRUCTURAL: "+generated.validation.summary()+
                                        "\nCOMPILER: "+generated.compilerVerification.summary()+
                                        "\n\n"+generated.generatedText);
                                answer("Self-coding candidate verified aur private workspace me save ho gaya. Abhi install nahi hua hai. Owner review/approval ke baad signed APK build/install hoga.");
                            });
                        }catch(Exception e){
                            runOnUiThread(() -> {
                                developerOutput.setText("Verified generation ko candidate workspace me save karne me error: "+e.getMessage());
                                answer("Code generate hua, lekin verified candidate save nahi ho paya: "+e.getMessage());
                            });
                        }
                    }else{
                        runOnUiThread(() -> {
                            lastGeneratedProject=generated.generatedText;
                            developerOutput.setText("SELF-UPGRADE CANDIDATE NOT VERIFIED\nENGINE: "+generated.engine+
                                    "\nSTRUCTURAL: "+generated.validation.summary()+
                                    "\nCOMPILER: "+generated.compilerVerification.summary()+
                                    "\n\n"+generated.generatedText+
                                    "\n\n--- VALIDATION ---\n"+generated.validation.details()+
                                    "\n\n--- COMPILER ---\n"+generated.compilerVerification.details());
                            answer("Self-coding hui, lekin candidate fully verify nahi hua. Isliye Anamika ne ise active/update-ready code ke roop me save nahi kiya.");
                        });
                    }
                }
                @Override public void onError(String error) {
                    runOnUiThread(() -> {
                        developerOutput.setText("Self-upgrade generation error: " + error);
                        answer("Self-coding error: "+error);
                    });
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
            SoftVoiceProfile.apply(this,tts,text);
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
                    android.os.Bundle params=new android.os.Bundle();
                    params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME,
                            Math.max(0.1f,Math.min(1.0f,SoftVoiceProfile.volumeHint(this))));
                    tts.speak(chunk,part==0?TextToSpeech.QUEUE_FLUSH:TextToSpeech.QUEUE_ADD,params,
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
            SoftVoiceProfile.apply(this,tts,"Namaste, main Anamika hoon.");
        }
    }

    @Override
    protected void onResume(){
        super.onResume();
        if(permissionSetupActive) mainHandler.postDelayed(this::continueOneTimePermissionSetup,500L);
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
