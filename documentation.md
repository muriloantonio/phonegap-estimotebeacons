# JavaScript API guide for the Estimote Beacons Cordova plugin

See file [changelog.md](changelog.md) for a list of all updates.

## JavaScript API documentation

## Overview of the JavaScript API

The plugin currently supports:

* Monitoring beacons with both application opened or closed. (iOS and Android)

## Estimote Beacons API

### Start and stop monitoring beacons (iOS and Android)

    estimote.beacons.startMonitoringForRegion(
        region,
        successCallback,
        errorCallback)

    estimote.beacons.stopMonitoringForRegion(
        region,
        successCallback,
        errorCallback)

#### `Region` object structure

    {
        "identifier":   // String,
        "major":        // Integer,
        "minor":        // Integer,
        "idle":         // Integer,
        "enterTitle":   // String,
        "enterMessage": // String,
        "exitTitle":    // String,
        "exitMessage":  // String,
        "deeplink":     // URL to be opened as a deeplink,
        "logHistory":   // Boolean
    }

In order to receive either enter or exit notifications, register event listeners for the following events:

* `beacon-monitor-enter`
* `beacon-monitor-exit`

If the application was opened from clicking the notification, when 
Both of this events hold a property named `notificationData` with the following structure:

```javascript
{
    "identifier": // String
    "major": // Integer,
    "minor": // Integer,
    "idle":  //Inreger
    "enterTitle": // String,
    "enterMessage": // String,
    "exitTitle": // String,
    "exitMessage": // String,
    "deeplink": // URL to be opened as a deeplink,
    "state": // String with "inside" or "outside",
    "openedFromNotification": // Boolean
}
```

Example:

```javascript
document.addEventListener("beacon-monitor-enter", function(event) {
    console.log(event.notificationData);
})}, false);

document.addEventListener("beacon-monitor-exit", function(event) {
    console.log(event.notificationData);
})}, false);

estimote.beacons.startMonitoringForRegion(
    region,
    onMonitoringSuccess,
    onError)
```

### Authorization iOS 8+ and Android 23+

On iOS 8 your app should ask for permission to use location services (required for monitoring and ranging on iOS 8 - on Android and iOS 7 this function does nothing). The same applies for Android 23+ (Android M and above):

```javascript
estimote.beacons.requestAlwaysAuthorization(
    successCallback,
    errorCallback)
```