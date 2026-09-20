package com.anamika.ai.v13.core;

import android.content.Context;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Clean V13 runtime registry. It does not claim a subsystem is ready until it is explicitly marked ready. */
public final class V13Runtime {
    public enum State { PLANNED, MIGRATING, READY, BLOCKED }

    public static final class Subsystem {
        public final String id;
        public final String name;
        public final State state;
        public final String note;
        public Subsystem(String id, String name, State state, String note) {
            this.id=id; this.name=name; this.state=state; this.note=note;
        }
    }

    private V13Runtime() {}

    public static List<Subsystem> inventory(Context context) {
        List<Subsystem> out=new ArrayList<>();
        out.add(new Subsystem("owner","Owner security",State.MIGRATING,"V7 owner session retained until V13 owner module replaces it."));
        out.add(new Subsystem("voice","Voice + wake",State.MIGRATING,"Wake/TTS/recognizer migration required."));
        out.add(new Subsystem("assistant","Assistant brain",State.PLANNED,"Hybrid online/local adapter will be isolated from phone-control functions."));
        out.add(new Subsystem("phone","Phone control",State.MIGRATING,"Existing verified phone functions are migration input."));
        out.add(new Subsystem("automation","App automation",State.MIGRATING,"Accessibility remains owner-authorized."));
        out.add(new Subsystem("blueprint","Deep blueprint",State.MIGRATING,"Observable UI discovery only."));
        out.add(new Subsystem("files","Files + vault",State.MIGRATING,"Private storage and export paths will be revalidated."));
        out.add(new Subsystem("research","Research memory",State.MIGRATING,"Visible/public screen learning only."));
        out.add(new Subsystem("developer","Code Doctor",State.MIGRATING,"Compiler-backed verification remains mandatory."));
        out.add(new Subsystem("upgrade","Local self-upgrade",State.MIGRATING, upgradeNote(context)));
        out.add(new Subsystem("media","Media/3D",State.MIGRATING,"Existing engines retained until V13 tests pass."));
        out.add(new Subsystem("runtime","Health + recovery",State.PLANNED,"Crash journal/resource guard/rollback health checks."));
        return Collections.unmodifiableList(out);
    }

    private static String upgradeNote(Context c) {
        File source=new File(c.getFilesDir(),"self_upgrade");
        return "Source workspace="+(source.exists()?"present":"not created yet")+
                "; phone-local builder/signer still requires implementation and device validation.";
    }
}
