package com.evothings;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;

import java.util.ArrayList;
import java.util.List;

/**
 * Created by João Gonçalves (jppg) on 18/04/16.
 */
public class HistoryStore {

    private final static String TAG = "RegionsStore";

    private Context mContext;
    private LocalStorageDBHelper localStorageDBHelper;
    private SQLiteDatabase database;

    public HistoryStore(Context context) {
        mContext = context;
        localStorageDBHelper = LocalStorageDBHelper.getInstance(mContext);
    }

    public History getHistoryEntry(String regionIdentifier, long timespan) {
        History history = null;
        if (regionIdentifier != null && timespan > 0) {
            database = localStorageDBHelper.getReadableDatabase();
            Cursor cursor = database.query(LocalStorageDBHelper.HISTORY_TABLE_NAME,
                    null, LocalStorageDBHelper.HISTORY_FIELD_BEACON_ID + " = ? AND " + LocalStorageDBHelper.HISTORY_FIELD_TIME + " = ?",
                    new String[]{regionIdentifier, String.valueOf(timespan)}, null, null, null);
            if (cursor.moveToFirst()) {
                String action = cursor.getString(2);
                history = new History(regionIdentifier, timespan, action);
            }
            cursor.close();
            database.close();
        }
        return history;
    }

    /**
     * Retrieve the last event registered.
     * @return
     */
    public History getLastEntry() {
        database = localStorageDBHelper.getReadableDatabase();
        Cursor cursor = database.query(
                LocalStorageDBHelper.HISTORY_TABLE_NAME, null, null, null, null, null,
                LocalStorageDBHelper.HISTORY_FIELD_TIME + " DESC");
        History ret = null;
        if(cursor.moveToFirst())
        {
            final String id = cursor.getString(0);
            final long time = cursor.getLong(1);
            final String action = cursor.getString(2);
            ret = new History(id, time, action);
        }
        return ret;
    }

    /**
     * Retrieve all registered history events.
     * @return
     */
    public List<History> getAllHistoryEntries() {
        ArrayList<History> entries = new ArrayList<History>();
        database = localStorageDBHelper.getReadableDatabase();
        Cursor cursor = database.query(LocalStorageDBHelper.HISTORY_TABLE_NAME,
                null, null,
                null, null, null, null);
        while (cursor.moveToNext()) {
            final String id = cursor.getString(0);
            final long timestamp = cursor.getLong(1);
            final String action = cursor.getString(2);
            entries.add(new History(id, timestamp, action));
        }
    return entries;
    }

    /**
     * Retrieve all event entries for the given region
     * @param regionIdentifier
     * @return
     */
    public List<History> getHistoryEntries(String regionIdentifier) {
        ArrayList<History> entries = new ArrayList<History>();
        if (regionIdentifier != null) {
            database = localStorageDBHelper.getReadableDatabase();
            Cursor cursor = database.query(LocalStorageDBHelper.HISTORY_TABLE_NAME,
                    new String[]{LocalStorageDBHelper.HISTORY_FIELD_TIME, LocalStorageDBHelper.HISTORY_FIELD_ACTION},
                    LocalStorageDBHelper.HISTORY_FIELD_BEACON_ID + " = ? ",
                    new String[]{regionIdentifier},
                    null, null, null);
            while (cursor.moveToNext()) {
                final long timestamp = cursor.getLong(0);
                final String action = cursor.getString(1);
                entries.add(new History(regionIdentifier, timestamp, action));
            }
        }
        return entries;
    }

    public void addHistoryEntry(History history) {
        if (history != null) {
            History oldValue = getHistoryEntry(history.getRegionIdentifier(), history.getTimeStamp());
            database = localStorageDBHelper.getWritableDatabase();
            ContentValues values = new ContentValues();
            values.put(LocalStorageDBHelper.HISTORY_FIELD_BEACON_ID, history.getRegionIdentifier());
            values.put(LocalStorageDBHelper.HISTORY_FIELD_TIME, history.getTimeStamp());
            values.put(LocalStorageDBHelper.HISTORY_FIELD_ACTION, history.getAction());
            if (oldValue == null) {
                database.insert(LocalStorageDBHelper.HISTORY_TABLE_NAME, null, values);
            }
            database.close();
        }
    }



    public void clear() {
        //storage.clear();
    }

}
