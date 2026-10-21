package com.gathin.tvhome;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.Collections;
import java.util.List;
import java.util.Random;

/**
 * The line under the clock (home_message, home_messages, home_message_rotation). Picks which message
 * shows; MainActivity only displays it. One message, or none, works exactly like home_message alone.
 */
final class HomeMessages {
    /** A different message each day, the same all day long. */
    static final String DAILY = "daily";
    /** A different message every time Home comes back to the screen, never the one just shown. */
    static final String EACH_HOME = "each_home";

    private static final String PREFS = "home_messages";
    private static final String LAST_INDEX = "last_index";

    private final List<String> messages;
    private final String rotation;
    /** home_message_minutes: change every this many minutes, even while Home is on screen; 0 uses the rotation. */
    private final int minutes;
    private final Random random = new Random();

    /**
     * @param single   home_message, used when the list is empty
     * @param list     home_messages; blank entries are dropped
     * @param rotation {@link #DAILY} (default) or {@link #EACH_HOME}
     * @param minutes  when above 0, a new message every this many minutes, overriding the rotation
     */
    HomeMessages(String single, List<String> list, String rotation, int minutes) {
        List<String> clean = new ArrayList<>();
        if (list != null) {
            for (String m : list) {
                if (m != null && !m.trim().isEmpty()) clean.add(m.trim());
            }
        }
        if (clean.isEmpty() && single != null && !single.trim().isEmpty()) clean.add(single.trim());
        this.messages = Collections.unmodifiableList(clean);
        this.rotation = EACH_HOME.equals(rotation) ? EACH_HOME : DAILY;
        this.minutes = Math.max(0, minutes);
    }

    /** The message to show now; empty when there is none. */
    String pick(Context ctx) {
        int n = messages.size();
        if (n == 0) return "";
        if (n == 1) return messages.get(0);
        if (minutes > 0) return messages.get(timedIndex(n, minutes));
        return messages.get(EACH_HOME.equals(rotation) ? nextIndex(ctx, n) : dailyIndex(n));
    }

    /**
     * Whether the message can change while Home stays on screen (the minute tick asks again): true for
     * timed and daily messages, false for each_home, which must change only when Home comes back.
     */
    boolean changesWithTime() {
        return messages.size() > 1 && (minutes > 0 || !EACH_HOME.equals(rotation));
    }

    /** Consecutive time slots get consecutive messages, so a change never repeats the one before. */
    private static int timedIndex(int n, int minutes) {
        long slot = System.currentTimeMillis() / (minutes * 60_000L);
        return (int) (slot % n);
    }

    /** Consecutive days get consecutive messages, so tomorrow never repeats today. */
    private static int dailyIndex(int n) {
        Calendar now = Calendar.getInstance();
        long day = now.get(Calendar.YEAR) * 366L + now.get(Calendar.DAY_OF_YEAR);
        return (int) (day % n);
    }

    /** A random message other than the last one shown, remembered across restarts. */
    private int nextIndex(Context ctx, int n) {
        SharedPreferences prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        int last = prefs.getInt(LAST_INDEX, -1);
        int i;
        if (last >= 0 && last < n) {
            i = random.nextInt(n - 1);
            if (i >= last) i++;
        } else {
            i = random.nextInt(n);
        }
        prefs.edit().putInt(LAST_INDEX, i).apply();
        return i;
    }
}
