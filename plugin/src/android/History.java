package com.evothings;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.TimeZone;

/**
 * Created by João Gonçalves (jppg) on 18/04/16.
 */
public class History {

    public static final String ACTION_ENTER = "enter";

    public static final String ACTION_EXIT = "exit";

    /**
     * The identifier of the region involved on the event.
     */
    private String regionIdentifier;

    /**
     * Time stamp, in seconds, of the occurrence of this event.
     */
    private long timeStamp;

    /**
     * The action occurred on the events, either enter or exit
     */
    private String action;

    public String getRegionIdentifier() {
        return regionIdentifier;
    }

    public void setRegionIdentifier(String regionIdentifier) {
        this.regionIdentifier = regionIdentifier;
    }

    public long getTimeStamp() {
        return timeStamp;
    }

    public String getFormattedDate() {
        Date date = new Date(timeStamp * 1000L);
        //yyyy-MM-dd'T'HH:mm:ss.SSSZ
        SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ");
        sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
        return sdf.format(date);
    }

    /**
     * Set the timestamp in Unix time, in seconds.
     * @param timeStamp
     */
    public void setTimeStamp(long timeStamp) {
        this.timeStamp = timeStamp;
    }

    public String getAction() {
        return action;
    }

    public void setAction(String action) {
        this.action = action;
    }

    /**
     * History event record
     * @param regionIdentifier Region identifier.
     * @param timeStamp time, in seconds and Unix time format.
     * @param action Action of the event, either enter or exit.
     */
    public History(String regionIdentifier, long timeStamp, String action) {
        this.action = action;
        this.regionIdentifier = regionIdentifier;
        this.timeStamp = timeStamp;
    }
}
