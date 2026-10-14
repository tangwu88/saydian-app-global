package cc.saidian.saydian_app;

import java.util.Locale;

/** User-confirmed name routing; device capabilities still require a handshake. */
final class RingNamePolicy {
    private RingNamePolicy() { }

    static String coolWearModel(String name) {
        if (name == null) return null;
        String normalized = name.trim().toUpperCase(Locale.ROOT);
        for (String model : new String[]{"HR01", "HR05", "K80", "R7ULTRA", "R7PRO", "R7Y", "R7"}) {
            if (!normalized.contains(model)) continue;
            if (model.equals("R7ULTRA")) return "R7Ultra";
            return model.equals("R7PRO") ? "R7Pro" : model;
        }
        return null;
    }

    static boolean isQRingName(String name) {
        if (name == null || coolWearModel(name) != null) return false;
        String normalized = name.trim().toUpperCase(Locale.ROOT);
        return normalized.contains("R8") || normalized.contains("R21") || normalized.contains("R22")
                || normalized.startsWith("Q_") || normalized.startsWith("O_")
                || normalized.startsWith("R2");
    }
}
