var exec = cordova.require('cordova/exec');
var channel = cordova.require('cordova/channel');

/*********************************************************/
/***************** Estimote Namespaces *******************/
/*********************************************************/

/**
 * Main exported module.
 * @namespace estimote
 */
var estimote = estimote || {};

// Export module.
module.exports = estimote;

/**
 * Submodule for beacons.
 * @namespace beacons
 * @memberof estimote
 */
estimote.beacons = estimote.beacons || {};

/**
 * Namespace alias for estimote.beacons, for backwards compatibility.
 * Deprecated, use {@link estimote.beacons}
 * @deprecated
 * @global
 */
window.EstimoteBeacons = estimote.beacons;


/*********************************************************/
/****************** Debugging Functions ******************/
/*********************************************************/

/**
 * Print an object. Useful for debugging.
 * @param {object} obj Object to print.
 * @param {function} [printFun=console.log] Print function, defaults to console.log (optional).
 * @example Example calls:
 *   estimote.printObject(obj);
 *   estimote.printObject(obj, console.log);
 * @function estimote.printObject
 */
estimote.printObject = function(obj, printFun)
{
    if (!printFun) { printFun = console.log; }
    function print(obj, level)
    {
        var indent = new Array(level + 1).join('  ');
        for (var prop in obj) {
            if (obj.hasOwnProperty(prop)) {
                var value = obj[prop];
                if (typeof value == 'object') {
                    printFun(indent + prop + ':');
                    print(value, level + 1);
                }
                else {
                    printFun(indent + prop + ': ' + value);
                }
            }
        }
    }
    print(obj, 0);
};

/*********************************************************/
/************** Generic Bluetooth Functions **************/
/*********************************************************/

/**
 * Ask for the Bluetooth state. Implemented on iOS.
 * If Bluetooth is off, this call initially displays a
 * dialog to the user in addition to returning the value
 * false to the success callback.
 * @todo Is there a way to make the dialog not show?
 *
 * @param {function} [success] Function called on success.
 * Takes a boolean parameter. Format success(boolean).
 * If true Bluetooth is on, if false it is off.
 * @param {ErrorCallback} [error] Function called on error.
 *
 * @example
 * estimote.bluetoothState(
 *   function(result) {
 *      console.log('Bluetooth state: ' + result) },
 *   function(errorMessage) {
 *      console.log('Error: ' + errorMessage) })
 */
estimote.bluetoothState = function(success, error)
{
    exec(success,
        error,
        'EstimoteBeacons',
        'bluetooth_bluetoothState',
        []
    );

    return true;
};

/*********************************************************/
/*************** Basic Callback Functions ****************/
/*********************************************************/

/**
 * Success callback function that takes no parameters.
 * @callback SuccessCallbackNoParams
 */

/**
 * Error callback function.
 * @callback ErrorCallback
 * @param {string} error Error message.
 */

/*********************************************************/
/**************** Estimote Beacons Module ****************/
/*********************************************************/

/**
 * For backwards compatibility. Use {@link estimote.printObject}
 * @deprecated
 * @memberof estimote.beacons
 */
estimote.beacons.printObject = estimote.printObject;

/**
 * Proximity value.
 */
estimote.beacons.ProximityUnknown = 0;

/**
 * Proximity value.
 */
estimote.beacons.ProximityImmediate = 1;

/**
 * Proximity value.
 */
estimote.beacons.ProximityNear = 2;

/**
 * Proximity value.
 */
estimote.beacons.ProximityFar = 3;

/**
 * Beacon colour.
 * @memberof estimote.beacons
 */
estimote.beacons.BeaconColorUnknown = 0;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorMintCocktail = 1;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorIcyMarshmallow = 2;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorBlueberryPie = 3;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorSweetBeetroot = 4;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorCandyFloss = 5;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorLemonTart = 6;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorVanillaJello = 7;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorLiquoriceSwirl = 8;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorWhite = 9;

/**
 * Beacon colour.
 */
estimote.beacons.BeaconColorTransparent = 10;

/**
 * Region state.
 */
estimote.beacons.RegionStateUnknown = 'unknown';

/**
 * Region state.
 */
estimote.beacons.RegionStateOutside = 'outside';

/**
 * Region state.
 */
estimote.beacons.RegionStateInside = 'inside';

/**
 * Ask the user for permission to use location services
 * while the app is in the foreground.
 * You need to call this function or requestAlwaysAuthorization
 * on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param {SuccessCallbackNoParams} [success] Function called on success (optional).
 * @param {ErrorCallback} [error] Function called on error (optional).
 *
 * @example Example call:
 *   estimote.beacons.requestWhenInUseAuthorization()
 *
 * @see {@link https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services|Estimote SDK and iOS 8 Location Services}
 */
estimote.beacons.requestWhenInUseAuthorization = function(success, error)
{
    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_requestWhenInUseAuthorization',
        []
    );

    return true;
};

/**
 * Ask the user for permission to use location services
 * whenever the app is running.
 * You need to call this function or requestWhenInUseAuthorization
 * on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param {SuccessCallbackNoParams} [success] Function called on success (optional).
 * @param {ErrorCallback} [error] Function called on error (optional).
 *
 * @example Example call:
 *   estimote.beacons.requestAlwaysAuthorization()
 *
 * @see {@link https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services|Estimote SDK and iOS 8 Location Services}
 */
estimote.beacons.requestAlwaysAuthorization = function(success, error)
{
    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_requestAlwaysAuthorization',
        []
    );

    return true;
};

/**
 * Get the current location authorization status.
 * Implemented on iOS 8+.
 * Does nothing on other platforms.
 *
 * @param {function} success Function called on success, the result param of the
 * function contains the current authorization status (mandatory).
 * @param {ErrorCallback} error Function called on error (mandatory).
 *
 * @example success callback format:
 *   success(authorizationStatus)
 *
 * @example Example call:
 *   estimote.beacons.authorizationStatus(
 *     function(result) {
 *       console.log('Location authorization status: ' + result) },
 *     function(errorMessage) {
 *       console.log('Error: ' + errorMessage) })
 *
 * @see {@link https://community.estimote.com/hc/en-us/articles/203393036-Estimote-SDK-and-iOS-8-Location-Services|Estimote SDK and iOS 8 Location Services}
 */
estimote.beacons.authorizationStatus = function(success, error)
{
    if (!checkExecParamsSuccessError(success, error)) {
        return false;
    }

    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_authorizationStatus',
        []
    );

    return true;
};

/**
 * Beacon region object.
 * @typedef {Object} BeaconRegion
 * @property {string} identifier Region identifier
 * (id set by the application, not related actual beacons).
 * @property {string} uuid The UUID of the region.
 * @property {number} major The UUID major value of the region.
 * @property {number} major The UUID minor value of the region.
 */

/**
 * Beacon info object. Consists of a region and an array of beacons.
 * @typedef {Object} BeaconInfo
 * @property {BeaconRegion} region Beacon region. Not available when scanning on iOS.
 * @property {Beacon[]} beacons Array of {@link Beacon} objects.
 */

/**
 * Start monitoring beacons. Available on iOS and Android.
 *
 * @param {BeaconRegion} region Dictionary with region properties (mandatory).
 * @param success Function called when beacons are enter/exit the region (mandatory).
 * @param {function} success Function called when beacons enter/exit the region,
 * takes a {@link RegionState} object as parameter (mandatory).
 * @param {ErrorCallback} error Function called on error (mandatory).
 * @param {boolean} [notifyEntryStateOnDisplay=false] Set to true to detect if you
 * are inside a region when the user turns display on, see
 * {@link https://developer.apple.com/library/prerelease/ios/documentation/CoreLocation/Reference/CLBeaconRegion_class/index.html#//apple_ref/occ/instp/CLBeaconRegion/notifyEntryStateOnDisplay|iOS documentation}
 * for further details (optional, defaults to false, iOS only).
 *
 * @example success callback format:
 *   success(RegionState)
 *
 * @example Example that prints regionState properties:
 *   estimote.beacons.startMonitoringForRegion(
 *     {}, // Empty region matches all beacons.
 *     function(state) {
 *       console.log('Region state:')
 *       estimote.printObject(state) },
 *     function(errorMessage) {
 *       console.log('Monitoring error: ' + errorMessage) })
 */
estimote.beacons.startMonitoringForRegion = function(
    region, success, error, notifyEntryStateOnDisplay)
{
    if (!checkExecParamsRegionSuccessError(region, success, error)) {
        return false;
    }

    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_startMonitoringForRegion',
        [region, !!notifyEntryStateOnDisplay]
    );

    return true;
};

/**
 * Stop monitoring beacons. Available on iOS and Android.
 *
 * @param {BeaconRegion} region Dictionary with region properties (mandatory).
 * @param {ErrorCallbackNoParams} [success] Function called when monitoring
 * is stopped (optional).
 * @param {ErrorCallback} [error] Function called on error (optional).
 *
 * @example Example that stops monitoring:
 *   estimote.beacons.stopMonitoringForRegion({})
 */
estimote.beacons.stopMonitoringForRegion = function (region, success, error)
{
    if (!checkExecParamsRegion(region)) {
        return false;
    }

    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_stopMonitoringForRegion',
        [region]
    );

    return true;
};

/**
 * Start monitoring secure beacons. Available on iOS.
 * This function has the same parameters/behaviour as
 * estimote.beacons.startMonitoringForRegion.
 * To use secure beacons set the App ID and App Token using
 * {@link estimote.beacons.setupAppIDAndAppToken}.
 * @see {@link estimote.beacons.startMonitoringForRegion}
 */
estimote.beacons.startSecureMonitoringForRegion = function(
    region, success, error, notifyEntryStateOnDisplay)
{
    if (!checkExecParamsRegionSuccessError(region, success, error)) {
        return false;
    }

    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_startSecureMonitoringForRegion',
        [region, !!notifyEntryStateOnDisplay]
    );

    return true;
};


/**
 * Stop monitoring secure beacons. Available on iOS.
 * This function has the same parameters/behaviour as
 * {@link estimote.beacons.stopMonitoringForRegion}.
 */
estimote.beacons.stopSecureMonitoringForRegion = function (region, success, error)
{
    if (!checkExecParamsRegion(region)) {
        return false;
    }

    exec(success,
        error,
        'EstimoteBeacons',
        'beacons_stopSecureMonitoringForRegion',
        [region]
    );

    return true;
};

/**
 *
 */
estimote.beacons.getOpenedFromNotificationData = function() {
    if(localNotificationData !== undefined) {
        var clonedData = JSON.parse(JSON.stringify(localNotificationData));
        localNotificationData = undefined;
        return clonedData;
    }
    return undefined;
};

/**
 * Get Last Log
 */
estimote.beacons.getLastEvent = function(success, error)
{
    return exec(success,error,'EstimoteBeacons','GetLastEvent', []);
};

/**
 * Get All Log
 */
estimote.beacons.getAllEvents = function(success, error)
{
    return exec(success,error,'EstimoteBeacons','GetAllEvents', []);
};

/**
 * Clear all history entries
 */
estimote.beacons.clearHistory = function(success, error)
{
    return exec(success,error,'EstimoteBeacons','ClearHistory', []);
};

/*********************************************************/
/******************* Helper Functions ********************/
/*********************************************************/

/**
 * Internal helper function.
 * @private
 */
function isString(value)
{
    return (typeof value == 'string' || value instanceof String);
}

/**
 * Internal helper function.
 * @private
 */
function isInt(value)
{
    return !isNaN(parseInt(value, 10)) &&
        (parseFloat(value, 10) == parseInt(value, 10));
}

/**
 * Internal helper function.
 * @private
 */
function checkExecParamsRegionSuccessError(region, success, error)
{
    var caller = checkExecParamsRegionSuccessError.caller.name;

    if (typeof region != 'object') {
        console.error('Error: region parameter is not an object in: ' + caller);
        return false;
    }

    if (typeof success != 'function') {
        console.error('Error: success parameter is not a function in: ' + caller);
        return false;
    }

    if (typeof error != 'function') {
        console.error('Error: error parameter is not a function in: ' + caller);
        return false;
    }

    return true;
}

/**
 * Internal helper function.
 * @private
 */
function checkExecParamsSuccessError(success, error)
{
    var caller = checkExecParamsSuccessError.caller.name;

    if (typeof success != 'function') {
        console.error('Error: success parameter is not a function in: ' + caller);
        return false;
    }

    if (typeof error != 'function') {
        console.error('Error: error parameter is not a function in: ' + caller);
        return false;
    }

    return true;
}

/**
 * Internal helper function.
 * @private
 */
function checkExecParamsRegion(region)
{
    var caller = checkExecParamsRegion.caller.name;

    if (typeof region != 'object') {
        console.error('Error: region parameter is not an object in: ' + caller);
        return false;
    }

    return true;
}

channel.createSticky('onBeaconsServiceReady');
channel.waitForInitialization('onBeaconsServiceReady');

channel.onCordovaReady.subscribe(function() {
    exec( function(data) {
        if(data.ready === true) {
            console.log("Init Service called and successfully initialized");
            if(channel.onBeaconsServiceReady.state !== 2) {
                channel.onBeaconsServiceReady.fire();
            }
        }
    },
    function(){
        console.log("Error initializing service...");
        if(channel.onBeaconsServiceReady.state !== 2) {
            channel.onBeaconsServiceReady.fire();
        }
    }, 'EstimoteBeacons', 'initService', []);
});

var localNotificationData;

cordova.callbacks.EstimoteBeaconsStaticChannel = {
    success: function(data) {
        console.log("EstimoteBeaconsStaticChannel success");
        if(data !== undefined) {
            var notificationData = {"notificationData" : data};

            if(data.openedFromNotification === true) {
                localNotificationData = notificationData;
            }

            switch(data.state) {

                case "inside":
                    cordova.fireDocumentEvent("beacon-monitor-enter", notificationData);
                    break;
                case "outside":
                    cordova.fireDocumentEvent("beacon-monitor-exit", notificationData);
                    break;
            }
        }
    },
    fail: function() {

    }
};

channel.deviceready.subscribe(function() {
    exec(null, null, 'EstimoteBeacons', 'deviceReady', []);
});
