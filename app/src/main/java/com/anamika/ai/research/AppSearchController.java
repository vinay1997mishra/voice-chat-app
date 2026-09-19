package com.anamika.ai.research;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

/** Explicit owner-requested search launchers. No hidden scraping is performed. */
public final class AppSearchController {
    private AppSearchController() { }

    public static String searchYouTube(Context context, String query) {
        String q = query == null ? "" : query.trim();
        Uri uri = Uri.parse("https://www.youtube.com/results?search_query=" + Uri.encode(q));
        Intent i = new Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            i.setPackage("com.google.android.youtube");
            context.startActivity(i);
            return "YouTube search opened: " + q;
        } catch (ActivityNotFoundException e) {
            try {
                i.setPackage(null);
                context.startActivity(i);
                return "YouTube search opened in available browser/app: " + q;
            } catch (Exception ex) { return "YouTube/search app unavailable."; }
        }
    }

    public static String searchGoogle(Context context, String query) {
        String q = query == null ? "" : query.trim();
        Uri uri = Uri.parse("https://www.google.com/search?q=" + Uri.encode(q));
        Intent i = new Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            i.setPackage("com.google.android.googlequicksearchbox");
            context.startActivity(i);
            return "Google search opened: " + q;
        } catch (Exception ignored) {
            try {
                i.setPackage("com.android.chrome");
                context.startActivity(i);
                return "Google search opened in Chrome: " + q;
            } catch (Exception ignored2) {
                try {
                    i.setPackage(null);
                    context.startActivity(i);
                    return "Google search opened: " + q;
                } catch (Exception e) { return "No browser/search app available."; }
            }
        }
    }
}
