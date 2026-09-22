package com.anamika.ai.upgrade;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.text.InputType;
import android.widget.Button;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

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
    private Button done;
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
                "2) Matching .p12/.pfx file select karo.\n"+
                "3) Done • Import Signer dabao.\n\n"+
                "Sirf wahi PKCS#12 accept hoga jiska certificate installed permanent-signed Anamika se match kare. File encrypted vault me store hogi.");
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
        pick.setText("2 • Select PKCS#12");

        selectedFile=new TextView(this);
        selectedFile.setText("No signing file selected.");
        selectedFile.setPadding(0,dp(8),0,dp(8));

        done=new Button(this);
        done.setText("3 • Done • Import Signer");
        done.setEnabled(true);

        Button refresh=new Button(this);
        refresh.setText("Refresh Status");

        box.addView(pick);
        box.addView(done);
        box.addView(selectedFile);
        box.addView(refresh);

        status=new TextView(this);
        status.setText(SignerVault.status(this));
        status.setTextIsSelectable(true);
        status.setPadding(0,dp(14),0,dp(24));
        box.addView(status);

        pick.setOnClickListener(v->pick());
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
            status.setText("PKCS#12 file abhi select nahi hui. Pehle “2 • Select PKCS#12” dabao.");
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
                selectedFile.setText("Signer imported successfully • READY");
                done.setText("Signer READY ✓");
                done.setEnabled(true);
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
    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
