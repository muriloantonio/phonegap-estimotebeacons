/*
Android implementation of Cordova plugin for Estimote Beacons.

JavaDoc for Estimote Android API: https://estimote.github.io/Android-SDK/JavaDocs/
*/

package com.evothings;

import android.Manifest;
import android.bluetooth.BluetoothAdapter;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.ServiceConnection;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.os.Messenger;
import android.os.RemoteException;
import android.util.Log;

import com.estimote.sdk.Beacon;
import com.estimote.sdk.BeaconManager;
import com.estimote.sdk.Region;
import com.estimote.sdk.SystemRequirementsHelper;
import com.estimote.sdk.Utils;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.UUID;

/**
 * Plugin class for the Estimote Beacon plugin.
 */
public class EstimoteBeacons extends CordovaPlugin {
    private static final String LOGTAG = "EstimoteBeacons";
    private static final int REQUEST_ENABLE_BLUETOOTH = 1;
    private static final int REQUEST_LOCATION_PERMISSION = 2;

    private BeaconManager mBeaconManager;
    private CordovaInterface mCordovaInterface;

    private ArrayList<Beacon> mRangedBeacons;
    private boolean mIsConnected = false;


    // Maps and variables that keep track of Cordova callbacks.
    private HashMap<String, CallbackContext> mRangingCallbackContexts =
            new HashMap<String, CallbackContext>();

    private CallbackContext mBluetoothStateCallbackContext;
    private CallbackContext mRequestLocationCallbackContext;


    /**
     * Messenger to receive messages from service;
     */
    private Messenger mMessenger = null;

    /**
     * Messenger to send messages to service
     */
    private Messenger mServiceMessenger = null;
    private boolean mBound = false;
    private boolean mBeaconsServiceConnected = false;

    /**
     * Broadcast receiver to bind to the service in case the application was opened but the service was not yet running.
     */
    private ServiceReadyBroadcastReceiver mServiceReadyBroadcastReceiver = null;

    private HistoryStore mHistoryStore = null;

    private CallbackContext mInitServiceCallbackContext = null;
    private ServiceConnection mServiceConnection = new ServiceConnection() {

        @Override
        public void onServiceConnected(ComponentName name, IBinder service) {
            Log.d(LOGTAG, "onServiceConnected start");
            EstimoteBeacons.this.mServiceMessenger = new Messenger(service);
            // Send a message to the service to register our-self as a "replier"
            try {
                Message msg = Message.obtain(null, BeaconsMonitoringService.MSG_REGISTER_CLIENT);
                msg.replyTo = mMessenger;
                mServiceMessenger.send(msg);
            } catch (RemoteException re) {
                Log.e(LOGTAG, re.getMessage(), re);
            }

            EstimoteBeacons.this.mBeaconsServiceConnected = true;
            EstimoteBeacons.this.mBound = true;
            EstimoteBeacons.this.sendMonitoringServiceReady();

            Log.d(LOGTAG, "onServiceConnected end");
        }

        @Override
        public void onServiceDisconnected(ComponentName name) {
            Log.d(LOGTAG, "onServiceDisconnected start");
            EstimoteBeacons.this.mServiceMessenger = null;
            EstimoteBeacons.this.mBound = false;
            EstimoteBeacons.this.mBeaconsServiceConnected = false;
            Log.d(LOGTAG, "onServiceDisconnected end");
        }
    };

    /**
     * Create JSON object representing a region.
     */
    private static JSONObject makeJSONRegion(Region region)
            throws JSONException {
        return makeJSONRegion(region, null);
    }

    /**
     * Create JSON object representing a region in the given state.
     */
    private static JSONObject makeJSONRegion(Region region, String state)
            throws JSONException {
        JSONObject json = new JSONObject();
        json.put("identifier", region.getIdentifier());
        json.put("uuid", region.getProximityUUID());
        json.put("major", region.getMajor());
        json.put("minor", region.getMinor());
        if (state != null) {
            json.put("state", state);
        }
        return json;
    }

    @Override
    protected void pluginInitialize() {
        Log.i(LOGTAG, "pluginInitialize");

        super.pluginInitialize();

        mCordovaInterface = cordova;
        mCordovaInterface.setActivityResultCallback(this);

        // Initialized receiver Messenger
        if (mMessenger == null) {
            mMessenger = new Messenger(new IncomingHandler());
        }

        if (mBeaconManager == null) {
            mBeaconManager = new BeaconManager(cordova.getActivity());
        }

        mBeaconManager.setErrorListener(new BeaconManager.ErrorListener() {
            @Override
            public void onError(Integer errorId) {
                Log.e(LOGTAG, "BeaconManager error: " + errorId);
            }
        });

        mRangedBeacons = new ArrayList<Beacon>();

        mHistoryStore = new HistoryStore(this.cordova.getActivity());


        doBindService();
        registerServiceReadyBroadcastReceiver();
    }

    /**
     * Plugin reset.
     * Called when the WebView does a top-level navigation or refreshes.
     */
    @Override
    public void onReset() {
        Log.i(LOGTAG, "onReset");

        disconnectBeaconManager();
        sendMonitoringServiceReady();
        mRangingCallbackContexts = new HashMap<String, CallbackContext>();
    }

    @Override
    public void onResume(boolean multitasking) {
        Log.i(LOGTAG, "onResume - " + multitasking);

        doBindService();
        registerServiceReadyBroadcastReceiver();

        super.onResume(multitasking);
    }

    @Override
    public void onPause(boolean multitasking) {
        Log.i(LOGTAG, "onPause - " + multitasking);

        unregisterServiceReadyBroadcastReceiver();
        doUnbindService();

        super.onPause(multitasking);
    }

    /**
     * The final call you receive before your activity is destroyed.
     *  
     */
    public void onDestroy() {
        Log.i(LOGTAG, "onDestroy");
        disconnectBeaconManager();
        mMessenger = null;
    }

    /**
     * Disconnect from the beacon manager.
     *  
     */
    private void disconnectBeaconManager() {
        if (mBeaconManager != null && mIsConnected) {
            mBeaconManager.disconnect();
            mIsConnected = false;
        }
    }

    /**
     * Entry point for JavaScript calls.
     */
    @Override
    public boolean execute(String action, CordovaArgs args, final CallbackContext callbackContext)
            throws JSONException {

        if ("beacons_startMonitoringForRegion".equals(action)) {
            startMonitoringForRegion(args, callbackContext);
        } else if ("beacons_stopMonitoringForRegion".equals(action)) {
            stopMonitoringForRegion(args, callbackContext);
        } else if ("bluetooth_bluetoothState".equals(action)) {
            checkBluetoothState(args, callbackContext);
        } else if ("beacons_requestAlwaysAuthorization".equals(action)) {
            requestLocationPermission(args, callbackContext);
        } else if ("beacons_authorizationStatus".equals(action)) {
            getLocationPermissionStatus(args, callbackContext);
        } else if ("initService".equals(action)) {
            initService(args, callbackContext);
        } else if ("deviceReady".equals(action)) {
            deviceReady(args, callbackContext);
        } else if ("GetAllEvents".equals(action)) {
            getAllEvents(args, callbackContext);
        } else if ("GetLastEvent".equals(action)) {
            getLastEvent(args, callbackContext);
        } else {
            return false;
        }
        return true;
    }

    private void getLocationPermissionStatus(CordovaArgs args, CallbackContext callbackContext) {
        boolean hasLocationPermission = SystemRequirementsHelper.hasAnyLocationPermission(cordova.getActivity());
        // Mimics the response from iOS
        // 2 - kCLAuthorizationStatusDenied
        // 3 - kCLAuthorizationStatusAuthorizedAlways

        callbackContext.success(hasLocationPermission ? 3 : 2);
    }

    private void getAllEvents(CordovaArgs cordovaArgs, final CallbackContext callbackContext) {
        // Perhaps this should be refactored to retrieve this information from the service.
        if (mHistoryStore != null) {
            ArrayList<History> events = (ArrayList<History>) mHistoryStore.getAllHistoryEntries();
            JSONArray result = new JSONArray();
            for (History event : events) {
                try {
                    JSONObject jsonEvent = new JSONObject();
                    jsonEvent.put("RegionId", event.getRegionIdentifier());
                    jsonEvent.put("TimeStamp", event.getFormattedDate());
                    jsonEvent.put("Action", event.getAction());
                    result.put(jsonEvent);
                } catch (JSONException e) {
                    callbackContext.error("Failed to retrieve json.");
                }
            }
            callbackContext.success(result);
        } else {
            callbackContext.error("Failed to retrieve data");
        }
    }

    private void requestLocationPermission(CordovaArgs cordovaArgs, final CallbackContext callbackContext) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            boolean hasLocationPermission = SystemRequirementsHelper.hasAnyLocationPermission(cordova.getActivity());
            if (!hasLocationPermission) {
                this.mRequestLocationCallbackContext = callbackContext;
                cordova.requestPermission(this, REQUEST_LOCATION_PERMISSION, Manifest.permission.ACCESS_COARSE_LOCATION);
            }
        }
    }

    private void getLastEvent(CordovaArgs cordovaArgs, final CallbackContext callbackContext) {
        // Perhaps this should be refactored to retrieve this information from the service.
        if (mHistoryStore != null) {
            History history = mHistoryStore.getLastEntry();
            try {
                JSONObject jsonEvent = new JSONObject();
                jsonEvent.put("RegionId", history.getRegionIdentifier());
                jsonEvent.put("TimeStamp", history.getFormattedDate());
                jsonEvent.put("Action", history.getAction());
                callbackContext.success(jsonEvent);
                return;
            } catch (JSONException e) {
                callbackContext.error("Failed to retrieve json.");
            }

        } else {
            callbackContext.error("Failed to retrieve data");
        }
    }

    private boolean initService(CordovaArgs cordovaArgs, final CallbackContext callbackContext) {
        mInitServiceCallbackContext = callbackContext;
        sendMonitoringServiceReady();
        return true;
    }

    private void deviceReady(CordovaArgs cordovaArgs, final CallbackContext callbackContext) {
        Intent intent = cordova.getActivity().getIntent();
        handleLaunchIntent(intent);
    }

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        handleLaunchIntent(intent);
    }

    private void handleLaunchIntent(Intent intent) {
        Intent launcherIntent = null;

        if (intent != null && intent.hasExtra("LAUNCHER_INTENT")) {
            launcherIntent = intent.getParcelableExtra("LAUNCHER_INTENT");
        } else {
            launcherIntent = intent;
        }

        if (launcherIntent != null) {

            String data = launcherIntent.getStringExtra("beacons.notification.data");
            boolean inside = launcherIntent.getBooleanExtra("beacons.notification.inside", false);
            if (data != null) {
                try {
                    final JSONObject jsonObject = new JSONObject(data);
                    jsonObject.put("state", inside ? "inside" : "outside");
                    sendMonitoringUpdateToWebView(jsonObject);
                    launcherIntent.removeExtra("beacons.notification.data");
                    launcherIntent.removeExtra("beacons.notification.inside");
                } catch (JSONException e) {

                }
            }
        }
    }

    /**
     * If Bluetooth is off, open a Bluetooth dialog.
     */
    private void checkBluetoothState(
            CordovaArgs cordovaArgs,
            final CallbackContext callbackContext)
            throws JSONException {
        Log.i(LOGTAG, "checkBluetoothState");

        // Check that no Bluetooth state request is in progress.
        if (null != mBluetoothStateCallbackContext) {
            callbackContext.error("Bluetooth state request already in progress");
            return;
        }

        // Check if Bluetooth is enabled.
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();

        if (!bluetoothAdapter.isEnabled()) {
            // Open Bluetooth dialog on the UI thread.
            final CordovaPlugin self = this;
            mBluetoothStateCallbackContext = callbackContext;
            Runnable openBluetoothDialog = new Runnable() {
                public void run() {
                    Intent enableIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                    mCordovaInterface.startActivityForResult(
                            self,
                            enableIntent,
                            REQUEST_ENABLE_BLUETOOTH);
                }
            };
            mCordovaInterface.getActivity().runOnUiThread(openBluetoothDialog);
        } else {
            // Bluetooth is enabled, return the result to JavaScript,
            sendResultForBluetoothEnabled(callbackContext);
        }
    }

    /**
     * Check if Bluetooth is enabled and return result to JavaScript.
     */
    public void sendResultForBluetoothEnabled(CallbackContext callbackContext) {
        BluetoothAdapter bluetoothAdapter = BluetoothAdapter.getDefaultAdapter();
        if (bluetoothAdapter.isEnabled()) {
            callbackContext.success(1);
        } else {
            callbackContext.success(0);
        }
    }

    /**
     * Called when the Bluetooth dialog is closed.
     */
    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent intent) {
        Log.i(LOGTAG, "onActivityResult");
        if (REQUEST_ENABLE_BLUETOOTH == requestCode) {
            sendResultForBluetoothEnabled(mBluetoothStateCallbackContext);
            mBluetoothStateCallbackContext = null;
        }
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        super.onRequestPermissionResult(requestCode, permissions, grantResults);
        if (REQUEST_LOCATION_PERMISSION == requestCode) {
            if (permissions[0].equals(Manifest.permission.ACCESS_COARSE_LOCATION)) {
                if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    this.mRequestLocationCallbackContext.success(1);
                } else {
                    this.mRequestLocationCallbackContext.success(0);
                }
            }
        }
    }

    /**
     * Start monitoring for region.
     */
    private void startMonitoringForRegion(
            CordovaArgs cordovaArgs,
            final CallbackContext callbackContext)
            throws JSONException {
        Log.i(LOGTAG, "startMonitoringForRegion");
        JSONObject json = cordovaArgs.getJSONObject(0);

        Region region = JSONUtils.fromJson(json.toString());
        if (region == null) {
            callbackContext.error("Invalid region");
            return;
        }

        if (mServiceMessenger != null) {
            Message msg = Message.obtain(null, BeaconsMonitoringService.MSG_START_MONITORING_REGION);
            msg.getData().putParcelable("region", region);
            msg.replyTo = mMessenger;
            try {
                mServiceMessenger.send(msg);
                callbackContext.success();
            } catch (RemoteException e) {
                callbackContext.error("Unable to talk with background monitoring service.");
            }
        } else {
            callbackContext.error("Perhaps your bluetooth is off or background service isn't yet ready?");
        }
    }

    /**
     * Stop monitoring for region.
     */
    private void stopMonitoringForRegion(
            CordovaArgs cordovaArgs,
            final CallbackContext callbackContext)
            throws JSONException {
        Log.i(LOGTAG, "stopMonitoringForRegion");

        JSONObject json = cordovaArgs.getJSONObject(0);

        Region region = JSONUtils.fromJson(json.toString());
        if (region == null) {
            callbackContext.error("Invalid region");
            return;
        }

        // Stop monitoring if connected.
        if (mServiceMessenger != null) {
            Message msg = Message.obtain(null, BeaconsMonitoringService.MSG_STOP_MONITORING_REGION);
            msg.getData().putParcelable("region", region);
            msg.replyTo = mMessenger;
            try {
                mServiceMessenger.send(msg);
                callbackContext.success();
            } catch (RemoteException e) {
                callbackContext.error("Unable to talk with background monitoring service.");
            }
        } else {
            callbackContext.error("Perhaps your bluetooth is off or background service isn't yet ready?");
        }
    }

    /**
     * Create JSON object representing beacon info.
     * <p>
     * beaconInfo format:
     * {
     * region: region,
     * beacons: array of beacon
     * }
     */
    private JSONObject makeJSONBeaconInfo(Region region, List<Beacon> beacons)
            throws JSONException {
        // Create JSON object.
        JSONObject json = new JSONObject();
        json.put("region", makeJSONRegion(region));
        json.put("beacons", makeJSONBeaconArray(beacons));
        return json;
    }

    /**
     * Create JSON object representing a beacon list.
     */
    private JSONArray makeJSONBeaconArray(List<Beacon> beacons)
            throws JSONException {
        JSONArray jsonArray = new JSONArray();
        for (Beacon b : beacons) {
            // Compute proximity value.
            Utils.Proximity proximityValue = Utils.computeProximity(b);
            int proximity = 0; // Unknown.
            if (Utils.Proximity.IMMEDIATE == proximityValue) {
                proximity = 1;
            } else if (Utils.Proximity.NEAR == proximityValue) {
                proximity = 2;
            } else if (Utils.Proximity.FAR == proximityValue) {
                proximity = 3;
            }

            // Compute distance value.
            double distance = Utils.computeAccuracy(b);

            // Normalize UUID.
            String uuid = Utils.normalizeProximityUUID(b.getProximityUUID().toString());

            // Construct JSON object for beacon.
            JSONObject json = new JSONObject();
            json.put("major", b.getMajor());
            json.put("minor", b.getMinor());
            json.put("rssi", b.getRssi());
            json.put("measuredPower", b.getMeasuredPower());
            json.put("proximityUUID", uuid);
            json.put("proximity", proximity);
            json.put("distance", distance);
            //json.put("name", b.getName());
            json.put("macAddress", b.getMacAddress());
            jsonArray.put(json);
        }
        return jsonArray;
    }

    private String regionHashMapKey(String uuid, Integer major, Integer minor) {
        if (uuid == null) {
            uuid = "0";
        }

        if (major == null) {
            major = 0;
        }

        if (minor == null) {
            minor = 0;
        }

        // use % for easier decomposition
        return uuid + "%" + major + "%" + minor;
    }

    private String regionHashMapKey(Region region) {
        UUID uuid = region.getProximityUUID();
        Integer major = region.getMajor();
        Integer minor = region.getMinor();
        if (uuid == null) {
            return regionHashMapKey(null, major, minor);
        } else {
            return regionHashMapKey(uuid.toString(), major, minor);
        }
    }

    /**
     * Create a Region object from Cordova arguments.
     */
    private Region createRegion(JSONObject json) throws NullPointerException, IllegalArgumentException {
        // null ranges all regions, if unset
        String uuidString = json.optString("uuid", null);
        UUID uuid = null;
        if (uuidString != null) {
            uuid = UUID.fromString(uuidString);
        }
        Integer major = optUInt16Null(json, "major");
        Integer minor = optUInt16Null(json, "minor");


        String identifier = json.optString(
                "identifier",
                regionHashMapKey(uuidString, major, minor)
        );

        return new Region(identifier, uuid, major, minor);
    }

    /**
     * Returns the value mapped by name if it exists and is a positive integer
     * no larger than 0xFFFF.
     * Returns null otherwise.
     */
    private Integer optUInt16Null(JSONObject json, String name) {
        int i = json.optInt(name, -1);
        if (i < 0 || i > (0xFFFF)) {
            return null;
        } else {
            return new Integer(i);
        }
    }

    private void registerServiceReadyBroadcastReceiver() {
        Log.d(LOGTAG, "registerServiceReadyBroadcastReceiver start");
        IntentFilter intentFilter = new IntentFilter(BeaconsMonitoringService.SERVICE_READY_ACTION);
        if (mServiceReadyBroadcastReceiver == null) {
            mServiceReadyBroadcastReceiver = new ServiceReadyBroadcastReceiver();
        }
        final Context context = this.webView.getContext();
        context.registerReceiver(mServiceReadyBroadcastReceiver, intentFilter);
        Log.d(LOGTAG, "registerServiceReadyBroadcastReceiver end");
    }

    private void unregisterServiceReadyBroadcastReceiver() {
        Log.d(LOGTAG, "unregisterServiceReadyBroadcastReceiver start");
        final Context context = this.webView.getContext();
        context.unregisterReceiver(mServiceReadyBroadcastReceiver);
        Log.d(LOGTAG, "unregisterServiceReadyBroadcastReceiver end");
    }

    //---------------------------------------
    //
    //
    //
    //---------------------------------------

    private void doBindService() {
        Log.d(LOGTAG, "doBindService start");
        final Context context = this.webView.getContext();
        if (!mBound) {
            context.startService(new Intent(context, BeaconsMonitoringService.class));
            mBound = context.bindService(new Intent(context, BeaconsMonitoringService.class),
                    mServiceConnection, Context.BIND_AUTO_CREATE);
        }
        Log.d(LOGTAG, "doBindService end");
    }

    private void doUnbindService() {
        Log.d(LOGTAG, "doUnBindService start");
        if (mServiceMessenger != null) {
            try {
                Message msg = Message.obtain(null, BeaconsMonitoringService.MSG_UNREGISTER_CLIENT);
                mServiceMessenger.send(msg);
            } catch (RemoteException re) {
                Log.e(LOGTAG, re.getMessage(), re);
            }

        }
        final Context context = this.webView.getContext();
        context.unbindService(mServiceConnection);
        mBound = false;
        mBeaconsServiceConnected = true;
        Log.d(LOGTAG, "doUnBindService end");
    }

    private void sendMonitoringServiceReady() {
        // Inform WebView that we are now ready to register regions
        try {
            if (mBeaconsServiceConnected && mInitServiceCallbackContext != null) {
                Log.d(LOGTAG, "Informing webview that we're ready!");
                JSONObject res = new JSONObject();
                res.put("ready", true);
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, res);
                pluginResult.setKeepCallback(true);
                mInitServiceCallbackContext.sendPluginResult(pluginResult);
            }
        } catch (JSONException e) {

        }
    }

    private void sendMonitoringRegionEnterUpdate(Region region) {
        try {
            final JSONObject jsonObject = JSONUtils.toJSONObject(region, "inside");
            if (jsonObject != null) {
                sendMonitoringUpdateToWebView(jsonObject);
            }
        } catch (JSONException e) {
            Log.e(LOGTAG, "sendMonitoringRegionEnterUpdate error: ", e);
        }
    }

    private void sendMonitoringRegionExitUpdate(Region region) {
        try {
            final JSONObject jsonObject = JSONUtils.toJSONObject(region, "outside");
            if (jsonObject != null) {
                sendMonitoringUpdateToWebView(jsonObject);
            }
        } catch (JSONException e) {
            Log.e(LOGTAG, "sendMonitoringRegionExitUpdate error: ", e);
        }
    }

    private void sendMonitoringUpdateToWebView(JSONObject jsonObject) {
        PluginResult pr = new PluginResult(PluginResult.Status.OK, jsonObject);
        pr.setKeepCallback(true);
        webView.sendPluginResult(pr, "EstimoteBeaconsStaticChannel");
        Log.d(LOGTAG, "sendMonitoringRegionEnterUpdate");
    }

    /**
     * Listener for ranging events.
     */
    class PluginRangingListener implements BeaconManager.RangingListener {
        @Override
        public void onBeaconsDiscovered(Region region, List<Beacon> beacons) {
            // Note that results are not delivered on UI thread.

            Log.i(LOGTAG, "onBeaconsDiscovered");

            try {
                // store in plugin
                mRangedBeacons.clear();
                mRangedBeacons.addAll(beacons);

                // Find region callback.
                String key = regionHashMapKey(region);
                CallbackContext rangingCallback = mRangingCallbackContexts.get(key);
                if (null == rangingCallback) {
                    // No callback found.
                    Log.e(LOGTAG,
                            "onBeaconsDiscovered no callback found for key: " + key);
                    return;
                }

                // Create JSON beacon info object.
                JSONObject json = makeJSONBeaconInfo(region, beacons);

                // Send result to JavaScript.
                PluginResult r = new PluginResult(PluginResult.Status.OK, json);
                r.setKeepCallback(true);
                rangingCallback.sendPluginResult(r);
            } catch (JSONException e) {
                Log.e(LOGTAG, "onBeaconsDiscovered error:", e);
            }
        }
    }

    private class ServiceReadyBroadcastReceiver extends BroadcastReceiver {
        @Override
        public void onReceive(Context context, Intent intent) {
            Log.d(LOGTAG, "ServiceReadyBroadcastReceiver::onReceive start");
            doBindService();
            Log.d(LOGTAG, "ServiceReadyBroadcastReceiver::onReceive end");
        }
    }

    private class IncomingHandler extends Handler {
        @Override
        public void handleMessage(Message msg) {
            Log.d(LOGTAG, "handleMessage start");

            final Bundle bundle = msg.getData();

            switch (msg.what) {
                case BeaconsMonitoringService.MSG_MONITOR_REGION_ON_ENTER: {
                    bundle.setClassLoader(Region.class.getClassLoader());
                    final Region region = bundle.getParcelable(BeaconsMonitoringService.MSG_KEY_MONITORING_RESULT);
                    sendMonitoringRegionEnterUpdate(region);
                    break;
                }
                case BeaconsMonitoringService.MSG_MONITOR_REGION_ON_EXIT: {
                    bundle.setClassLoader(Region.class.getClassLoader());
                    final Region region = bundle.getParcelable(BeaconsMonitoringService.MSG_KEY_MONITORING_RESULT);
                    sendMonitoringRegionExitUpdate(region);
                    break;
                }
                default:
                    Log.d(LOGTAG, "Received a msg: " + msg.what);
                    super.handleMessage(msg);
            }
            Log.d(LOGTAG, "handleMessage end");
        }
    }
}
