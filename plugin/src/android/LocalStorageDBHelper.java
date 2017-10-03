package com.evothings;

import android.content.Context;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.util.Log;

/**
 * @author João Gonçalves
 *         Created by João Gonçalves (jppg) on 03/03/16.
 *         Original taken from https://github.com/cowbell/cordova-plugin-geofence/blob/master/src/android/LocalStorageDBHelper.java
 */
public class LocalStorageDBHelper extends SQLiteOpenHelper {

    /**
     * the name of the table
     */
    public static final String BEACONS_TABLE_NAME = "beacons";
    /**
     * the id column of the table BEACONS_TABLE_NAME
     */
    public static final String BEACONS_ID = "_id";
    /**
     * the value column of the table BEACONS_TABLE_NAME
     */
    public static final String LOCALSTORAGE_VALUE = "value";
    /**
     *
     */
    public static final String HISTORY_TABLE_NAME = "history";
    /**
     *
     */
    public static final String HISTORY_FIELD_BEACON_ID = "beacon_id";
    /**
     *
     */
    public static final String HISTORY_FIELD_TIME = "time";
    /**
     *
     */
    public static final String HISTORY_FIELD_ACTION = "action";
    private static final int DATABASE_VERSION = 2;
    private static final String DATABASE_NAME = "beacons.db";
    private static final String DICTIONARY_TABLE_BEACONS_CREATE = "CREATE TABLE "
            + BEACONS_TABLE_NAME + " (" + BEACONS_ID
            + " TEXT PRIMARY KEY, " + LOCALSTORAGE_VALUE + " TEXT NOT NULL);";
    private static final String DICTIONARY_TABLE_HISTORY_CREATE = "CREATE TABLE "
            + HISTORY_TABLE_NAME + " ("
            + HISTORY_FIELD_BEACON_ID + " TEXT NOT NULL, "
            + HISTORY_FIELD_TIME + " INTEGER NOT NULL, "
            + HISTORY_FIELD_ACTION + " TEXT NOT NULL, "
            + "PRIMARY KEY(" + HISTORY_FIELD_BEACON_ID + ", " + HISTORY_FIELD_TIME + " ));";
    private static LocalStorageDBHelper mInstance;

    private LocalStorageDBHelper(Context context) {
        super(context, DATABASE_NAME, null, DATABASE_VERSION);
    }

    /**
     * Returns an instance of LocalStorage
     *
     * @param ctx : a Context used to create the database
     * @return the instance of LocalStorage of the application or a new one if
     * it has not been created before.
     */
    public static LocalStorageDBHelper getInstance(Context ctx) {
        if (mInstance == null) {
            mInstance = new LocalStorageDBHelper(ctx);
        }
        return mInstance;
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        Log.d("LocalStoragePath", db.getPath());
        db.execSQL(DICTIONARY_TABLE_BEACONS_CREATE);
        db.execSQL(DICTIONARY_TABLE_HISTORY_CREATE);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        Log.w(LocalStorageDBHelper.class.getName(),
                "Upgrading database from version " + oldVersion + " to "
                        + newVersion + ", which will destroy all old data");
        db.execSQL("DROP TABLE IF EXISTS " + BEACONS_TABLE_NAME);
        db.execSQL("DROP TABLE IF EXISTS " + HISTORY_TABLE_NAME);
        onCreate(db);
    }
}