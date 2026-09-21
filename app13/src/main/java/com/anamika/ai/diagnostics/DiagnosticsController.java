package com.anamika.ai.diagnostics;

import android.app.Activity;
import android.content.Intent;

import java.io.File;

/**
 * Diagnostics bridge entry point.
 * Sharing is explicit and owner-initiated; reports are never uploaded automatically.
 */
public final class DiagnosticsController {
    private DiagnosticsController(){}

    public static String runAndSave(Activity a){
        try{
            FullDiagnosticsEngine.Result r=FullDiagnosticsEngine.run(a);
            File f=DiagnosticsReportStore.save(a,r);
            return r.summary()+"\nReport saved: "+f.getAbsolutePath();
        }catch(Exception e){
            return "Self-test report save failed: "+safe(e);
        }
    }

    public static String shareLatest(Activity a){
        String report=DiagnosticsReportStore.readLatest(a);
        if(report.startsWith("No diagnostics report")){
            runAndSave(a);
            report=DiagnosticsReportStore.readLatest(a);
        }
        if(report.startsWith("Diagnostics report unavailable"))
            return report;

        try{
            Intent i=new Intent(Intent.ACTION_SEND);
            i.setType("text/plain");
            i.putExtra(Intent.EXTRA_SUBJECT,"Anamika AI 13 Full Functional Diagnostics");
            i.putExtra(Intent.EXTRA_TEXT,report);
            a.startActivity(Intent.createChooser(i,"Share Anamika diagnostics"));
            return "Diagnostics share sheet khol di. Aap report ChatGPT ya kisi trusted destination ko bhej sakte ho.";
        }catch(Exception e){
            return "Diagnostics share sheet open nahi hui: "+safe(e);
        }
    }

    public static String latest(Activity a){
        return DiagnosticsReportStore.readLatest(a);
    }

    private static String safe(Exception e){
        String m=e.getMessage();
        return m==null||m.trim().isEmpty()?e.getClass().getSimpleName():m;
    }
}
