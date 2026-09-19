package com.anamika.ai;

public final class AutoRepairEngine {
    private AutoRepairEngine() { }

    /** Conservative repairs only. It never invents arbitrary missing business logic. */
    public static String repairKnownIssues(String generated, OfflineCodeValidator.Report report) {
        if (generated == null) return "";
        String out = generated;
        // Frequent XML generation mistakes that can be repaired without changing behavior.
        out = out.replace("Generate / Analyze & Code", "Generate / Analyze &amp; Code");
        // Never auto-rewrite unsafe paths; the validator must reject them for owner review.
        return out;
    }
}
