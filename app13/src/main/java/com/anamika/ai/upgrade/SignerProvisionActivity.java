package com.anamika.ai.upgrade;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.util.Base64;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.anamika.ai.components.ComponentPacksActivity;
import com.anamika.ai.core.OwnerStore;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.util.Arrays;

/** Owner-only UI for provisioning the matching release PKCS#12 signer. */
public final class SignerProvisionActivity extends Activity {
    private static final int PICK=1330;
    private TextView status;
    private TextView selectedFile;
    private EditText password;
    private EditText base64Input;
    private Button done;
    private Button importBase64;
    private Uri selectedUri;

    @Override protected void onCreate(Bundle state){
        super.onCreate(state);
        if(!OwnerStore.isTrusted(this)){finish();return;}
        buildUi();
    }

    private void buildUi(){
        int p=dp(16);
        LinearLayout box=new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(p,p,p,p);

        TextView title=new TextView(this);
        title.setText("Anamika 13 • Signer Setup");
        title.setTextSize(23);
        box.addView(title);

        TextView note=new TextView(this);
        note.setText(
                "3 steps:\n"+
                "1) PKCS#12 password enter karo.\n"+
                "2) Matching .p12/.pfx file select karo, YA GitHub jaisa Base64 text direct paste karo.\n"+
                "3) Done • Import Signer dabao.\n\n"+
                "Sirf wahi PKCS#12 accept hoga jiska certificate installed permanent-signed Anamika se match kare. Signer encrypted vault me store hoga.");
        note.setPadding(0,dp(8),0,dp(12));
        box.addView(note);

        password=new EditText(this);
        password.setHint("PKCS#12 password (leave empty if none)");
        password.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
        box.addView(password);

        CheckBox showPassword=new CheckBox(this);
        showPassword.setText("Show password");
        showPassword.setOnCheckedChangeListener((buttonView,isChecked)->{
            int type=InputType.TYPE_CLASS_TEXT|
                    (isChecked?InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD:InputType.TYPE_TEXT_VARIATION_PASSWORD);
            password.setInputType(type);
            password.setSelection(password.getText().length());
        });
        box.addView(showPassword);

        Button pick=new Button(this);
        pick.setText("2A • Select PKCS#12 file");

        TextView orText=new TextView(this);
        orText.setText("OR • direct Base64 paste");
        orText.setPadding(0,dp(12),0,dp(4));

        base64Input=new EditText(this);
        base64Input.setHint("Paste PKCS#12 Base64 here (MIIR... / MII...)");
        base64Input.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_MULTI_LINE);
        base64Input.setSingleLine(false);
        base64Input.setMinLines(4);
        base64Input.setMaxLines(8);

        Button pasteBase64=new Button(this);
        pasteBase64.setText("2B • Paste Base64 from Clipboard");

        importBase64=new Button(this);
        importBase64.setText("Import Pasted PKCS#12");

        selectedFile=new TextView(this);
        selectedFile.setText("No signing file selected.");
        selectedFile.setPadding(0,dp(8),0,dp(8));

        done=new Button(this);
        done.setText("3 • Done • Import Signer");
        done.setEnabled(true);

        Button refresh=new Button(this);
        refresh.setText("Refresh Status");

        box.addView(pick);
        box.addView(orText);
        box.addView(base64Input);
        box.addView(pasteBase64);
        box.addView(importBase64);
        box.addView(done);
        box.addView(selectedFile);
        box.addView(refresh);

        status=new TextView(this);
        status.setText(SignerVault.status(this));
        status.setTextIsSelectable(true);
        if(SignerVault.ready(this)){
            password.setText("");
            base64Input.setText("");
            selectedFile.setText("Signer already provisioned • READY");
            done.setText("Signer READY ✓ • Continue Setup");
            done.setOnClickListener(v->openComponentsAndFinish());
        }
        status.setPadding(0,dp(14),0,dp(24));
        box.addView(status);

        pick.setOnClickListener(v->pick());
        pasteBase64.setOnClickListener(v->pasteBase64FromClipboard());
        importBase64.setOnClickListener(v->importBase64Signer());
        done.setOnClickListener(v->importSelected());
        refresh.setOnClickListener(v->status.setText(SignerVault.status(this)));

        ScrollView scroll=new ScrollView(this);
        scroll.addView(box);
        setContentView(scroll);
    }

    private void pick(){
        Intent i=new Intent(Intent.ACTION_OPEN_DOCUMENT);
        i.addCategory(Intent.CATEGORY_OPENABLE);
        i.setType("*/*");
        startActivityForResult(i,PICK);
    }

    @Override protected void onActivityResult(int requestCode,int resultCode,Intent data){
        super.onActivityResult(requestCode,resultCode,data);
        if(requestCode!=PICK)return;

        if(resultCode!=RESULT_OK||data==null||data.getData()==null){
            status.setText("File selection cancelled. Password aur PKCS#12 file select karke Done dabao.");
            done.setEnabled(true);
            return;
        }

        selectedUri=data.getData();
        try{
            final int flags=data.getFlags()&
                    (Intent.FLAG_GRANT_READ_URI_PERMISSION|Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
            if((flags&Intent.FLAG_GRANT_READ_URI_PERMISSION)!=0){
                getContentResolver().takePersistableUriPermission(
                        selectedUri,flags&Intent.FLAG_GRANT_READ_URI_PERMISSION);
            }
        }catch(Throwable ignored){}

        String name=selectedUri.getLastPathSegment();
        if(name==null||name.trim().isEmpty())name="selected PKCS#12";
        selectedFile.setText("Selected: "+name);
        done.setEnabled(true);
        if(password.getText().length()>0){
            status.setText("File selected. Password bhi entered hai, signer import check kar rahi hu…");
            importSelected();
        }else{
            status.setText("File selected. Password enter karo, phir “Done • Import Signer” dabao.");
        }
    }

    private void importSelected(){
        if(selectedUri==null){
            if(base64Input!=null && base64Input.getText().toString().trim().length()>0){
                importBase64Signer();
                return;
            }
            status.setText("PKCS#12 file select karo YA Base64 paste karke Import Pasted PKCS#12 dabao.");
            done.setEnabled(true);
            return;
        }

        String passwordText=password.getText().toString();
        char[] pass=passwordText.toCharArray();
        done.setEnabled(false);
        status.setText("Checking signing file…");
        try{
            byte[] bytes=read(selectedUri,16*1024*1024);
            String result=SignerVault.importPkcs12(this,bytes,pass);
            Arrays.fill(bytes,(byte)0);
            status.setText(result+"\n\n"+SignerVault.status(this));
            if(SignerVault.ready(this)){
                password.setText("");
                selectedFile.setText("Signer imported successfully • READY");
                done.setText("Signer READY ✓ • Continue Setup");
                done.setEnabled(true);
                done.setOnClickListener(v->openComponentsAndFinish());
            }else{
                done.setText("3 • Retry Import Signer");
                done.setEnabled(true);
            }
        }catch(Exception e){
            status.setText("Signer import failed: "+safe(e)+"\n\nFile selected rahegi. Password check karke Retry Import Signer dabao.");
            done.setText("3 • Retry Import Signer");
            done.setEnabled(true);
        }finally{
            Arrays.fill(pass,'\0');
        }
    }


    private void pasteBase64FromClipboard(){
        try{
            ClipboardManager cb=(ClipboardManager)getSystemService(Context.CLIPBOARD_SERVICE);
            if(cb==null||!cb.hasPrimaryClip()){
                status.setText("Clipboard empty hai. GitHub wala PKCS#12 Base64 copy karke phir Paste dabao.");
                return;
            }
            ClipData clip=cb.getPrimaryClip();
            if(clip==null||clip.getItemCount()==0){
                status.setText("Clipboard me readable text nahi mila.");
                return;
            }
            CharSequence text=clip.getItemAt(0).coerceToText(this);
            if(text==null||text.toString().trim().isEmpty()){
                status.setText("Clipboard me PKCS#12 Base64 text nahi mila.");
                return;
            }
            base64Input.setText(text.toString().trim());
            base64Input.setSelection(base64Input.length());
            status.setText("Base64 pasted. Password enter/check karo, phir Import Pasted PKCS#12 dabao.");
        }catch(Throwable e){
            status.setText("Clipboard paste failed: "+safe(e));
        }
    }

    private void importBase64Signer(){
        String raw=base64Input==null?"":base64Input.getText().toString();
        String compact=raw.replaceAll("\\s+","");
        if(compact.isEmpty()){
            status.setText("Base64 box empty hai. PKCS#12 Base64 paste karo.");
            return;
        }

        char[] pass=password.getText().toString().toCharArray();
        importBase64.setEnabled(false);
        done.setEnabled(false);
        status.setText("Pasted PKCS#12 verify/import kar rahi hu…");
        byte[] bytes=null;
        try{
            bytes=Base64.decode(compact,Base64.DEFAULT);
            if(bytes.length>16*1024*1024)
                throw new IllegalArgumentException("Signer data too large.");
            String result=SignerVault.importPkcs12(this,bytes,pass);
            status.setText(result+"\n\n"+SignerVault.status(this));
            if(SignerVault.ready(this)){
                password.setText("");
                selectedFile.setText("Signer imported from Base64 • READY");
                done.setText("Signer READY ✓ • Back to Anamika");
                done.setOnClickListener(v->finish());
                base64Input.setText("");
            }else{
                done.setText("3 • Retry Import Signer");
            }
        }catch(IllegalArgumentException e){
            status.setText("Base64 invalid hai. GitHub secret wala complete PKCS#12 Base64 copy karke paste karo.");
        }catch(Throwable e){
            status.setText("Signer import failed: "+safe(e));
        }finally{
            if(bytes!=null)Arrays.fill(bytes,(byte)0);
            Arrays.fill(pass,'\0');
            importBase64.setEnabled(true);
            done.setEnabled(true);
        }
    }

    private void openComponentsAndFinish(){
        startActivity(new Intent(this,ComponentPacksActivity.class));
        finish();
    }

    private byte[] read(Uri uri,int limit)throws Exception{
        try(InputStream in=getContentResolver().openInputStream(uri);
            ByteArrayOutputStream out=new ByteArrayOutputStream()){
            if(in==null)throw new IllegalStateException("Cannot read selected signer.");
            byte[] b=new byte[8192];int n,total=0;
            while((n=in.read(b))>0){
                total+=n;
                if(total>limit)throw new IllegalStateException("Signer file too large.");
                out.write(b,0,n);
            }
            return out.toByteArray();
        }
    }

    private int dp(int v){return (int)(v*getResources().getDisplayMetrics().density+0.5f);}
    private static String safe(Throwable e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
