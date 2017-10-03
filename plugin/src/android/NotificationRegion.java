package com.evothings;

import android.os.Parcel;
import android.os.Parcelable;

import com.estimote.sdk.Region;

import java.util.UUID;

/**
 * Created by João Gonçalves (jppg) on 03/03/16.
 */
public class NotificationRegion extends Region implements Parcelable {

    public static final Creator<NotificationRegion> CREATOR = new Creator<NotificationRegion>() {
        @Override
        public NotificationRegion createFromParcel(Parcel in) {
            final Region tmpRegion = Region.CREATOR.createFromParcel(in);
            final String enterTitle = in.readString();
            final String exitTitle = in.readString();
            final String enterMessage = in.readString();
            final String exitMessage = in.readString();
            final String deeplink = in.readString();
            final int idle = in.readInt();
            final boolean logHistory = in.readInt() > 0;
            return new NotificationRegion(tmpRegion, enterMessage, enterTitle, exitMessage, exitTitle, deeplink, idle, logHistory);
        }

        @Override
        public NotificationRegion[] newArray(int size) {
            return new NotificationRegion[size];
        }
    };
    private String enterTitle;
    private String exitTitle;
    private String enterMessage;
    private String exitMessage;
    private String deeplink;
    private int idle;
    private long lastNotificationTime;
    private boolean logHistory;
    private boolean openedFromNotification;

    public NotificationRegion(String identifier, UUID proximityUUID, Integer major, Integer minor, String enterMessage, String enterTitle, String exitMessage, String exitTitle, String deeplink, int idle, boolean logHistory) {
        super(identifier, proximityUUID, major, minor);
        this.enterMessage = enterMessage;
        this.enterTitle = enterTitle;
        this.exitMessage = exitMessage;
        this.exitTitle = exitTitle;
        this.deeplink = deeplink;
        this.idle = idle;
        this.openedFromNotification = false;
        this.lastNotificationTime = 0;
        this.logHistory = logHistory;
    }

    public NotificationRegion(Region region, String enterMessage, String enterTitle, String exitMessage, String exitTitle, String deeplink, int idle, boolean logHistory) {
        this(region.getIdentifier(), region.getProximityUUID(), region.getMajor(), region.getMinor(), enterMessage, enterTitle, exitMessage, exitTitle, deeplink, idle, logHistory);
    }

    public String getDeeplink() {
        return deeplink;
    }

    public String getEnterMessage() {
        return enterMessage;
    }

    public String getEnterTitle() {
        return enterTitle;
    }

    public String getExitMessage() {
        return exitMessage;
    }

    public String getExitTitle() {
        return exitTitle;
    }

    public int getIdle() {
        return idle;
    }

    public boolean logHistory() {
        return logHistory;
    }

    public void setLogHistory(boolean logHistory) {
        this.logHistory = logHistory;
    }

    public long getLastNotificationTime() {
        return lastNotificationTime;
    }

    public void setLastNotificationTime(long lastNotificationTime) {
        this.lastNotificationTime = lastNotificationTime;
    }

    public boolean isOpenedFromNotification() {
        return openedFromNotification;
    }

    public void setOpenedFromNotification(boolean openedFromNotification) {
        this.openedFromNotification = openedFromNotification;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        if (!super.equals(o)) return false;

        NotificationRegion that = (NotificationRegion) o;

        if (idle != that.idle) return false;
        if (lastNotificationTime != that.lastNotificationTime) return false;
        if (logHistory != that.logHistory) return false;
        if (openedFromNotification != that.openedFromNotification) return false;
        if (enterTitle != null ? !enterTitle.equals(that.enterTitle) : that.enterTitle != null)
            return false;
        if (exitTitle != null ? !exitTitle.equals(that.exitTitle) : that.exitTitle != null)
            return false;
        if (enterMessage != null ? !enterMessage.equals(that.enterMessage) : that.enterMessage != null)
            return false;
        if (exitMessage != null ? !exitMessage.equals(that.exitMessage) : that.exitMessage != null)
            return false;
        return !(deeplink != null ? !deeplink.equals(that.deeplink) : that.deeplink != null);

    }

    @Override
    public int hashCode() {
        int result = super.hashCode();
        result = 31 * result + (enterTitle != null ? enterTitle.hashCode() : 0);
        result = 31 * result + (exitTitle != null ? exitTitle.hashCode() : 0);
        result = 31 * result + (enterMessage != null ? enterMessage.hashCode() : 0);
        result = 31 * result + (exitMessage != null ? exitMessage.hashCode() : 0);
        result = 31 * result + (deeplink != null ? deeplink.hashCode() : 0);
        result = 31 * result + idle;
        result = 31 * result + (int) (lastNotificationTime ^ (lastNotificationTime >>> 32));
        result = 31 * result + (logHistory ? 1 : 0);
        result = 31 * result + (openedFromNotification ? 1 : 0);
        return result;
    }

    @Override
    public void writeToParcel(Parcel dest, int flags) {
        super.writeToParcel(dest, flags);
        dest.writeString(enterTitle);
        dest.writeString(exitTitle);
        dest.writeString(enterMessage);
        dest.writeString(exitMessage);
        dest.writeString(deeplink);
        dest.writeInt(idle);
        dest.writeInt(logHistory ? 1 : 0);
    }

    @Override
    public int describeContents() {
        return 0;
    }
}
