package com.anamika.ai.phone;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.AudioManager;
import android.net.Uri;
import android.provider.ContactsContract;
import android.provider.Settings;

import com.anamika.ai.plugins.AppAutomationAccessibilityService;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class PhoneAssistantController {
    public static final class ContactMatch {
        public final String name;
        public final String phone;
        public ContactMatch(String name,String phone){this.name=name;this.phone=phone;}
    }

    private PhoneAssistantController(){}

    public static boolean hasContactsPermission(Context c){
        return c!=null && c.checkSelfPermission(Manifest.permission.READ_CONTACTS)==PackageManager.PERMISSION_GRANTED;
    }

    public static boolean hasCallPermission(Context c){
        return c!=null && c.checkSelfPermission(Manifest.permission.CALL_PHONE)==PackageManager.PERMISSION_GRANTED;
    }

    public static ContactMatch findContact(Context c,String query){
        if(c==null || query==null || query.trim().isEmpty() || !hasContactsPermission(c)) return null;
        String q=query.trim();
        Cursor cur=null;
        try{
            String[] projection={
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
            };
            String sel=ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME+" LIKE ?";
            cur=c.getContentResolver().query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    projection,sel,new String[]{"%"+q+"%"},
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME+" COLLATE NOCASE ASC");
            if(cur!=null && cur.moveToFirst()){
                String name=cur.getString(0);
                String phone=cur.getString(1);
                if(phone!=null) phone=phone.replaceAll("[^0-9+]","");
                return new ContactMatch(name==null?q:name,phone==null?"":phone);
            }
        }catch(Throwable ignored){} finally { if(cur!=null) cur.close(); }
        return null;
    }

    public static String extractPersonName(String command){
        if(command==null) return "";
        String raw=command.trim();
        Matcher m=Pattern.compile("(?i)^(.+?)\\s+ko\\s+(?:call|phone|कॉल|फोन)").matcher(raw);
        if(m.find()) return cleanName(m.group(1));
        m=Pattern.compile("(?i)^(?:call|dial|phone|कॉल|फोन)\\s+(.+?)(?:\\s+(?:karo|kar|lagao|लगाओ|करो))?$").matcher(raw);
        if(m.find()) return cleanName(m.group(1));
        m=Pattern.compile("(?i)(?:contact|name|naam|number|कॉन्टैक्ट|नाम|नंबर)\\s+(?:search|dhundo|dhoondo|खोजो|ढूंढो)?\\s*(.+)").matcher(raw);
        if(m.find()) return cleanName(m.group(1));
        return "";
    }

    public static String extractMessageRecipient(String command){
        if(command==null) return "";
        Matcher m=Pattern.compile("(?i)^(.+?)\\s+ko\\s+(?:message|msg|sms|मैसेज|संदेश)").matcher(command.trim());
        if(m.find()) return cleanName(m.group(1));
        return "";
    }

    public static String extractMessageBody(String command){
        if(command==null) return "";
        Matcher m=Pattern.compile("(?i)^.+?\\s+ko\\s+(?:message|msg|sms|मैसेज|संदेश)\\s+(?:bhejo|send|भेजो)?\\s*(.+)$").matcher(command.trim());
        if(m.find()) return m.group(1).trim();
        return "";
    }

    private static String cleanName(String s){
        if(s==null) return "";
        return s.replaceFirst("(?i)^(?:whatsapp|contact|कॉन्टैक्ट)\\s+","")
                .replaceFirst("(?i)\\s+(?:app)?$","").trim();
    }

    public static void openDialer(Context c,String phone){
        Intent i=new Intent(Intent.ACTION_DIAL, Uri.parse("tel:"+Uri.encode(phone==null?"":phone)));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        c.startActivity(i);
    }

    public static boolean placeCall(Context c,String phone){
        if(!hasCallPermission(c)) return false;
        Intent i=new Intent(Intent.ACTION_CALL,Uri.parse("tel:"+Uri.encode(phone==null?"":phone)));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        c.startActivity(i);
        return true;
    }

    public static void composeSms(Context c,String phone,String body){
        Intent i=new Intent(Intent.ACTION_SENDTO,Uri.parse("smsto:"+Uri.encode(phone==null?"":phone)));
        if(body!=null && !body.trim().isEmpty()) i.putExtra("sms_body",body.trim());
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        c.startActivity(i);
    }

    public static String handleSystemSetting(Context c,String command){
        if(c==null || command==null) return "";
        VerifiedFunctionMemory.Entry learned=VerifiedFunctionMemory.find(c,command);
        if(learned!=null && !learned.action.isEmpty()){
            try{
                Intent remembered=new Intent(learned.action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                if(remembered.resolveActivity(c.getPackageManager())!=null){
                    c.startActivity(remembered);
                    return "Verified setting route yaad tha, direct khol diya.";
                }
            }catch(Throwable ignored){}
        }
        String s=command.toLowerCase(Locale.ROOT);
        int pct=extractPercent(s);

        if(s.contains("volume") || s.contains("वॉल्यूम") || s.contains("awaaz") || s.contains("आवाज")){
            AudioManager am=(AudioManager)c.getSystemService(Context.AUDIO_SERVICE);
            if(am==null) return "Volume service available nahi hai.";
            int stream=(s.contains("ring")||s.contains("ringtone")||s.contains("रिंग"))
                    ?AudioManager.STREAM_RING:AudioManager.STREAM_MUSIC;
            int max=am.getStreamMaxVolume(stream);
            int current=am.getStreamVolume(stream);
            int target=current;
            if(pct>=0) target=Math.round(max*(pct/100f));
            else if(containsAny(s,"badha","increase","up","tez","बढ़ा")) target=Math.min(max,current+Math.max(1,max/8));
            else if(containsAny(s,"kam","decrease","down","slow","घटा","कम")) target=Math.max(0,current-Math.max(1,max/8));
            else if(containsAny(s,"mute","silent","म्यूट")) target=0;
            else return openAndSearchSetting(c,"Volume");
            am.setStreamVolume(stream,target,AudioManager.FLAG_SHOW_UI);
            return "Volume set kar diya.";
        }

        if(s.contains("brightness") || s.contains("ब्राइटनेस")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_DISPLAY_SETTINGS,"Display/Brightness settings");
            open(c,Settings.ACTION_DISPLAY_SETTINGS);
            if(pct>=0) AppAutomationAccessibilityService.queueFirstSeekBarPercent(pct,1200L);
            else AppAutomationAccessibilityService.queueSettingsSearch("Brightness",900L);
            return pct>=0?"Brightness "+pct+"% set karne ki koshish kar rahi hoon.":"Brightness setting khol di.";
        }

        if(s.contains("wifi") || s.contains("wi-fi") || s.contains("वाईफाई")){
            if(android.os.Build.VERSION.SDK_INT>=29) open(c,Settings.Panel.ACTION_WIFI);
            else { VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_WIFI_SETTINGS,"Wi-Fi settings"); open(c,Settings.ACTION_WIFI_SETTINGS); }
            Boolean desired=desiredState(s);
            if(desired!=null) AppAutomationAccessibilityService.queueToggleByLabel(
                    new String[]{"Wi-Fi","Wifi","Internet","वाई-फ़ाई","वाईफाई"},desired,900L);
            return desired==null?"Wi-Fi setting khol di.":"Wi-Fi ko "+(desired?"ON":"OFF")+" karne ki koshish kar rahi hoon.";
        }

        if(s.contains("bluetooth") || s.contains("ब्लूटूथ")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_BLUETOOTH_SETTINGS,"Bluetooth settings");
            open(c,Settings.ACTION_BLUETOOTH_SETTINGS);
            Boolean desired=desiredState(s);
            if(desired!=null) AppAutomationAccessibilityService.queueToggleByLabel(
                    new String[]{"Bluetooth","ब्लूटूथ"},desired,900L);
            return desired==null?"Bluetooth setting khol di.":"Bluetooth ko "+(desired?"ON":"OFF")+" karne ki koshish kar rahi hoon.";
        }

        if(s.contains("location") || s.contains("लोकेशन") || s.contains("gps")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_LOCATION_SOURCE_SETTINGS,"Location settings");
            open(c,Settings.ACTION_LOCATION_SOURCE_SETTINGS);
            return "Location settings khol di.";
        }
        if(s.contains("battery saver") || s.contains("बैटरी सेवर")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_BATTERY_SAVER_SETTINGS,"Battery Saver settings");
            open(c,Settings.ACTION_BATTERY_SAVER_SETTINGS);
            return "Battery Saver settings khol di.";
        }
        if(s.contains("notification") || s.contains("नोटिफिकेशन")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,"android.settings.NOTIFICATION_SETTINGS","Notification settings");
            open(c,"android.settings.NOTIFICATION_SETTINGS");
            return "Notification settings khol di.";
        }
        if(s.contains("ringtone") || s.contains("रिंगटोन") || s.contains("sound setting")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_SOUND_SETTINGS,"Sound settings");
            open(c,Settings.ACTION_SOUND_SETTINGS);
            return "Sound settings khol di.";
        }
        if(s.contains("hotspot") || s.contains("हॉटस्पॉट")){
            return openAndSearchSetting(c,"Hotspot");
        }
        if(s.contains("mobile data") || s.contains("मोबाइल डेटा")){
            return openAndSearchSetting(c,"Mobile data");
        }
        if(s.contains("dark mode") || s.contains("dark theme") || s.contains("डार्क मोड")){
            open(c,Settings.ACTION_DISPLAY_SETTINGS);
            AppAutomationAccessibilityService.queueSettingsSearch("Dark theme",800L);
            return "Dark theme setting search kar rahi hoon.";
        }
        if(s.contains("screen timeout") || s.contains("sleep time") || s.contains("स्क्रीन टाइमआउट")){
            open(c,Settings.ACTION_DISPLAY_SETTINGS);
            AppAutomationAccessibilityService.queueSettingsSearch("Screen timeout",800L);
            return "Screen timeout setting search kar rahi hoon.";
        }
        if(s.contains("airplane") || s.contains("flight mode") || s.contains("एयरप्लेन")){
            VerifiedFunctionMemory.verifyAndSaveIntent(c,command,Settings.ACTION_AIRPLANE_MODE_SETTINGS,"Airplane mode settings");
            open(c,Settings.ACTION_AIRPLANE_MODE_SETTINGS);
            return "Airplane mode settings khol di.";
        }

        return openAndSearchSetting(c,command);
    }

    public static String openAndSearchSetting(Context c,String query){
        open(c,Settings.ACTION_SETTINGS);
        AppAutomationAccessibilityService.queueSettingsSearch(query,900L);
        return "Settings me “"+query+"” search kar rahi hoon.";
    }

    private static void open(Context c,String action){
        try{
            Intent i=new Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            c.startActivity(i);
        }catch(Throwable t){
            c.startActivity(new Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }

    private static int extractPercent(String s){
        Matcher m=Pattern.compile("(\\d{1,3})\\s*%?").matcher(s);
        if(m.find()){
            int v=Integer.parseInt(m.group(1));
            if(v>=0 && v<=100) return v;
        }
        if(containsAny(s,"half","aadha","adha","आधा")) return 50;
        if(containsAny(s,"full","maximum","max","पूरा")) return 100;
        return -1;
    }

    private static Boolean desiredState(String s){
        if(containsAny(s," on","on karo","enable","chalu","chaloo","चालू","ऑन")) return Boolean.TRUE;
        if(containsAny(s," off","off karo","disable","band","बंद","ऑफ")) return Boolean.FALSE;
        return null;
    }

    private static boolean containsAny(String s,String... terms){
        for(String t:terms) if(s.contains(t)) return true;
        return false;
    }
}
