#import <Cordova/CDV.h>
#import <EstimoteSDK/ESTUtilityManager.h>
#import <EstimoteSDK/ESTBeaconManager.h>
#import <EstimoteSDK/ESTCloudManager.h>
#import <EstimoteSDK/ESTEddystone.h>
#import <EstimoteSDK/ESTEddystoneManager.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BeaconsManager.h"

#import "EstimoteBeacons.h"

#pragma mark - Estimote Beacons Interface

/*********************************************************/
/************** Estimote Beacons Interface ***************/
/*********************************************************/

@interface EstimoteBeacons ()
<	ESTUtilityManagerDelegate,
ESTBeaconManagerDelegate,
ESTBeaconManagerDelegate,
CBCentralManagerDelegate >

/**
 * Estimote Utility manager.
 */
@property (nonatomic, strong) ESTUtilityManager* utilityManager;

/**
 * The beacon manager in the Estimote API.
 */
@property (nonatomic, strong) ESTBeaconManager* beaconManager;


/**
 * Dictionary of callback ids for startRangingBeaconsInRegion.
 * Region identifiers are used as keys.
 */
@property NSMutableDictionary* callbackIds_beaconsMonitoring;

/**
 * Bluetooth manager.
 */
@property CBCentralManager* bluetoothManager;

/**
 * Variable that tracks Bluetooth state.
 */
@property bool bluetoothState;

@end

#pragma mark - Estimote Beacons Implementation

@implementation EstimoteBeacons

/*********************************************************/
/****************** Initialise/Reset *********************/
/*********************************************************/

#pragma mark - Initialization

- (EstimoteBeacons*)pluginInitialize
{
    [self beacons_pluginInitialize];
    [self bluetooth_pluginInitialize];
    
    return self;
}

/**
 * From interface CDVPlugin.
 * Called when the WebView navigates or refreshes.
 */
- (void) onReset
{
    [self beacons_onReset];
    [self bluetooth_onReset];
}

/*********************************************************/
/************ Estimote Beacons Implementation ************/
/*********************************************************/

- (void) beacons_pluginInitialize
{
    //NSLog(@"OBJC EstimoteBeacons pluginInitialize");
    
    // Crete utility manager instance.
    self.utilityManager = [ESTUtilityManager new];
    self.utilityManager.delegate = self;
    
    // Crete beacon manager instance.
    self.beaconManager = [ESTBeaconManager new];
    self.beaconManager.delegate = self;
    // This will skip beacons with proximity CLProximityUnknown when ranging.
    self.beaconManager.avoidUnknownStateBeacons = YES;
    
    // Variables that track callback ids.
    self.callbackIds_beaconsMonitoring = [NSMutableDictionary new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveLocalNotification:)
                                                 name:@"CDVLocalNotificationBeacon"
                                               object:nil];
}

- (void) beacons_onReset
{
    // Reset callback variables.
    self.callbackIds_beaconsMonitoring = [NSMutableDictionary new];
    
    // Stop any ongoing scanning.
    [self.utilityManager stopEstimoteBeaconDiscovery];
    
}

#pragma mark - Helper methods

/**
 * Create a region object from a dictionary.
 */
- (CLBeaconRegion*) createRegionFromDictionary: (NSDictionary*)regionDict andSave: (BOOL) save
{
    // Default values for the region object.
    NSUUID* uuid = ESTIMOTE_PROXIMITY_UUID;
    NSString* identifier = [self regionHashMapKeyWithUUID:[regionDict objectForKey:@"uuid"] andMajor:[regionDict objectForKey:@"major"] andMinor:[regionDict objectForKey:@"minor"]];
    CLBeaconMajorValue major = 0;
    CLBeaconMinorValue minor = 0;
    BOOL secure = false;
    BOOL majorIsDefined = NO;
    BOOL minorIsDefined = NO;
    BOOL secureIsDefined = NO;
    
    // Get region values.
    for (id key in regionDict)
    {
        NSString* value = regionDict[key];
        if ([key isEqualToString:@"uuid"])
        {
            uuid = [[NSUUID alloc] initWithUUIDString: value];
        }
        else if ([key isEqualToString:@"identifier"])
        {
            identifier = value;
        }
        else if ([key isEqualToString:@"major"])
        {
            major = [value integerValue];
            majorIsDefined = YES; }
        else if ([key isEqualToString:@"minor"])
        {
            minor = [value integerValue];
            minorIsDefined = YES; }
        else if ([key isEqualToString:@"secure"])
        {
            secure = [value boolValue];
            secureIsDefined = YES;
        }
    }
    
    if(save) {
        //add to plist and store beacon info
        NSString *filePath = [EstimoteBeacons getBeaconsPlistPath];
        NSMutableDictionary *myDictionary = [EstimoteBeacons getBeaconsPlistData];
        if([myDictionary count] == 0)
        {
            myDictionary=[[NSMutableDictionary alloc]init];
        }
        
        [myDictionary setObject:regionDict forKey:[regionDict objectForKey:@"identifier"]];
        [myDictionary writeToFile:filePath atomically:YES];
    }
    
    // Create a beacon region object.
    if (majorIsDefined && minorIsDefined)
    {
        return [[CLBeaconRegion alloc]
                initWithProximityUUID: uuid
                major: major
                minor: minor
                identifier: identifier];
    }
    else if (majorIsDefined)
    {
        return [[CLBeaconRegion alloc]
                initWithProximityUUID: uuid
                major: major
                identifier: identifier];
    }
    else
    {
        return [[CLBeaconRegion alloc]
                initWithProximityUUID: uuid
                identifier: identifier];
    }
}

-(void) ClearHistory: (CDVInvokedUrlCommand*) command {
    [self.commandDelegate runInBackground:^{
        //Get all dicionary entries and convert them into a json
        NSMutableDictionary *historyEntries = [EstimoteBeacons getLogsPlistData];
        [historyEntries removeAllObjects];
        NSString *filePath = [EstimoteBeacons getLogsPlistPath];
        [historyEntries writeToFile:filePath atomically:YES];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

- (void) GetAllEvents:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        //Get all dicionary entries and convert them into a json
        NSMutableDictionary *historyEntries = [EstimoteBeacons getLogsPlistData];
        
        if([historyEntries count] > 0)
        {
            NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
            NSMutableDictionary *completedici = [[NSMutableDictionary alloc]init];
            
            for (NSMutableDictionary* key in historyEntries) {
                NSMutableDictionary *partialconvert = [historyEntries objectForKey:key];
                if(![[partialconvert objectForKey:@"TimeStamp"] isKindOfClass:[NSString class]])
                {
                    NSString *dateStringnow = [formatter stringFromDate:[partialconvert objectForKey:@"TimeStamp"]];
                    [partialconvert setValue:dateStringnow forKey:@"TimeStamp"];
                }
                else
                {
                    [partialconvert setValue:[partialconvert objectForKey:@"TimeStamp"] forKey:@"TimeStamp"];
                }
                [completedici setObject:partialconvert forKey:key];
            }
            NSArray * values = [completedici allValues];
            NSRange endRange = NSMakeRange(values.count >= 50 ? values.count - 50 : 0, MIN(values.count, 50));
            NSArray *last50Objects= [values subarrayWithRange:endRange];
            
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsArray:last50Objects];
            
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    }];
}

- (void) GetLastEvent:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        
        //Get last entry from logs list and convert them into a json
        NSMutableDictionary *logsHistoryItems = [EstimoteBeacons getLogsPlistData];
        NSArray * values = [logsHistoryItems keysSortedByValueUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSMutableDictionary* obj1Dict = obj1;
            NSMutableDictionary* obj2Dict = obj2;
            
            NSString* dateStr1 = [obj1Dict objectForKey:@"TimeStamp"];
            NSString* dateStr2 = [obj2Dict objectForKey:@"TimeStamp"];
            NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
            NSDate* date1 = [formatter dateFromString:dateStr1];
            NSDate* date2 = [formatter dateFromString:dateStr2];
            
            return [date1 compare:date2];
        }];
        
        NSString* lastItemKey = [values lastObject];
        NSDictionary *lastItem = [logsHistoryItems objectForKey:lastItemKey];
        
        if([lastItem count] > 0)
        {
            if(![[lastItem objectForKey:@"TimeStamp"] isKindOfClass:[NSString class]])
            {
                NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
                NSString *dateStringnow = [formatter stringFromDate:[lastItem objectForKey:@"TimeStamp"]];
                [lastItem setValue:dateStringnow forKey:@"TimeStamp"];
            }
            else
            {
                [lastItem setValue:[lastItem objectForKey:@"TimeStamp"] forKey:@"TimeStamp"];
            }
            
            NSMutableDictionary *completedici = [[NSMutableDictionary alloc] init];
            [completedici setObject:lastItem forKey:@"Last"];
            
            CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                    messageAsDictionary: [completedici objectForKey:@"Last"]];
            
            [self.commandDelegate sendPluginResult: result
                                        callbackId: command.callbackId];
        }
        else
        {
            CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                        messageAsString:@"null"];
            
            [self.commandDelegate sendPluginResult: result
                                        callbackId: command.callbackId];
        }
    }];
}

- (void)didReceiveLocalNotification: (NSNotification *)notification {
    NSLog(@"didReceiveLocalNotification by Notification Center");
    UILocalNotification *castedotification = notification.object;
    NSDictionary *userInfo = castedotification.userInfo;
    if([userInfo objectForKey:@"beacon.notification.data"] != nil)
    {
        [self dispatchPush:[userInfo valueForKey:@"beacon.notification.data"] forStateEvent:[userInfo valueForKey:@"event"]];
    }
}

+ (NSString*) getBeaconsPlistPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
    return [path copy];
}

+ (NSMutableDictionary*) getBeaconsPlistData
{
    NSString* filePath = [EstimoteBeacons getBeaconsPlistPath];
    NSMutableDictionary *myDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile: filePath];
    return myDictionary;
}

+ (NSMutableDictionary*) getLogsPlistData
{
    NSString *filePath = [self getLogsPlistPath];
    NSMutableDictionary *myDictionary= [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    return myDictionary;
}

+ (NSString*) getLogsPlistPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Log.plist"];
    return [path copy];
}


- (void)dispatchPush:(NSDictionary *)region forStateEvent: (NSString *) event {
    NSLog(@"DispatchPush for region");
    
    NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
    NSInteger logHistory = [[region objectForKey:@"logHistory"] integerValue];
    if(logHistory == 1)
    {
        NSMutableDictionary *logsHistoryDict =[EstimoteBeacons getLogsPlistData];
        
        if(!logsHistoryDict) {
            logsHistoryDict = [[NSMutableDictionary alloc] init];
        }
        
        NSMutableDictionary *NewLog = [[NSMutableDictionary alloc]init];
        [NewLog setObject:[region objectForKey:@"identifier"] forKey:@"RegionId"];
        NSString *dateStringnow = [formatter stringFromDate:[NSDate date]];
        [NewLog setObject:dateStringnow forKey:@"TimeStamp"];
        if([[region objectForKey:@"state"] isEqualToString:@"inside"])
        {
            [NewLog setObject:@"enter" forKey:@"Action"];
        } else {
            [NewLog setObject:@"exit" forKey:@"Action"];
        }
        NSString *dateString = [formatter stringFromDate:[NSDate date]];
        NSString *filePath = [EstimoteBeacons getLogsPlistPath];
        [logsHistoryDict setObject:NewLog forKey:[dateString stringByAppendingString:[region objectForKey:@"uuid"]]];
        [logsHistoryDict writeToFile:filePath atomically:YES];
    }
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:region];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:@"EstimoteBeaconsStaticChannel"];
    
}

- (NSString *) regionHashMapKeyWithUUID: (NSString *)uuid andMajor: (NSNumber *)major andMinor: (NSNumber *)minor {
    if (!uuid) {
        uuid = @"0";
    }
    
    if (major == 0) {
        major = 0;
    }
    
    if (minor == 0) {
        minor = 0;
    }
    
    // use % for easier decomposition
    return [NSString stringWithFormat:@"%@:%@:%@",uuid, major, minor];
}


/**
 * Create a dictionary object from a region.
 */
- (NSDictionary*) regionToDictionary:(CLBeaconRegion*)region
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [dict setValue:region.proximityUUID.UUIDString forKey:@"uuid"];
    [dict setValue:region.identifier forKey:@"identifier"];
    [dict setValue:region.major forKey:@"major"];
    [dict setValue:region.minor forKey:@"minor"];
    
    return dict;
}

/**
 * Create a dictionary key for a region.
 */
- (NSString*) regionDictionaryKey:(CLBeaconRegion*)region
{
    NSString* uuid = region.proximityUUID.UUIDString;
    int major = nil != region.major ? [region.major intValue] : 0;
    int minor = nil != region.minor ? [region.minor intValue] : 0;
    
    return [NSString stringWithFormat: @"%@-%i-%i", uuid, major, minor];
}

// Helper to re-write the beacon data on plist file
- (void) writeToPlistDictionary: (NSMutableDictionary *) beaconData {
    NSString *path = [EstimoteBeacons getBeaconsPlistPath];
    [beaconData writeToFile:path atomically:YES];
}

+ (NSDateFormatter *)getRegionDateFormatter {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
    return formatter;
}

- (BOOL) validateIdleTimeWithLastNotificationDate: (NSString *) lastNotificationDate andIdleValue: (NSInteger) idle {
    NSDate *now =[NSDate date];
    NSDateFormatter * formatter = [EstimoteBeacons getRegionDateFormatter];
    NSString *strLastNotification = lastNotificationDate;
    NSDate *lastNotification = [formatter dateFromString:strLastNotification];
    
    NSInteger mins = 0;
    if(lastNotification != nil)
    {
        NSTimeInterval distanceBetweenDates = [now timeIntervalSinceDate:lastNotification];
        long seconds = lroundf(distanceBetweenDates);
        mins = (seconds % 3600) / 60;
    }
    else{mins = 9999999;}
    
    NSInteger verify = idle;
    
    if(mins >= verify || verify == 0)
    {
        return YES;
    }
    
    return NO;
}


#pragma mark - CoreBluetooth discovery

- (void) initService:(CDVInvokedUrlCommand*) command {
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSNumber numberWithBool:YES], @"ready",
                          nil];
    
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) deviceReady:(CDVInvokedUrlCommand*) command {
    
    BeaconsManager *beaconsManager = [BeaconsManager sharedManager];
    NSMutableArray *noti = beaconsManager.notifications;
    
    for (id localNotificationItem in noti) {
        UILocalNotification *localNotification = localNotificationItem;
        
        NSDictionary *userInfo = localNotification.userInfo;
        [self dispatchPush:[userInfo valueForKey:@"beacon.notification.data"] forStateEvent:[userInfo valueForKey:@"event"]];
        //Remove notification dispatched
        [beaconsManager removeNotification:localNotification];
    }
}

#pragma mark - CoreLocation monitoring

/**
 * Start CoreLocation monitoring.
 */
- (void) beacons_startMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self beacons_impl_startMonitoringForRegion:command
                                            manager:self.beaconManager];
    }];
}

/**
 * Stop CoreLocation monitoring.
 */
- (void) beacons_stopMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        [self beacons_impl_stopMonitoringForRegion:command
                                           manager:self.beaconManager];
    }];
    
}

/**
 * Start CoreLocation monitoring.
 */
- (void) beacons_impl_startMonitoringForRegion:(CDVInvokedUrlCommand*)command
                                       manager:(id)aManager
{
    //NSLog(@"OBJC startMonitoringForRegion");
    
    // Get region dictionary passed from JavaScript and
    // create a beacon region object.
    NSDictionary* regionDictionary = [command argumentAtIndex:0];
    CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary andSave:YES];
    
    // Set region notification when display is activated.
    region.notifyEntryStateOnDisplay = (BOOL)[command argumentAtIndex:1];
    
    // Stop any ongoing monitoring for the given region.
    [self helper_stopMonitoringForRegion:region manager:aManager];
    
    // Save callback id for the region.
    [self.callbackIds_beaconsMonitoring setObject: command.callbackId
                                           forKey: [self regionDictionaryKey:region]];
    
    // Start monitoring.
    [aManager startMonitoringForRegion:region];
    
    CDVPluginResult* result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK
                               messageAsDictionary:regionDictionary];
    // [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    
    // This will get the initial state faster.
    //[aManager requestStateForRegion:region];
}

/**
 * Stop CoreLocation monitoring.
 */
- (void) beacons_impl_stopMonitoringForRegion:(CDVInvokedUrlCommand*)command
                                      manager:(id)aManager
{
    // Get region dictionary passed from JavaScript and
    // create a beacon region object.
    NSDictionary* regionDictionary = [command argumentAtIndex:0];
    CLBeaconRegion* region = [self createRegionFromDictionary:regionDictionary andSave:NO];
    
    // Stop monitoring.
    [self helper_stopMonitoringForRegion:region manager:aManager];
    
    // Respond to JavaScript with OK.
    [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
                                callbackId:command.callbackId];
}

- (void) helper_stopMonitoringForRegion:(CLBeaconRegion*)region
                                manager:(id)aManager
{
    // Stop monitoring the region.
    for (CLRegion* registeredRegion in [aManager monitoredRegions]) {
        if([registeredRegion.identifier isEqual:region.identifier]) {
            [aManager stopMonitoringForRegion:registeredRegion];
        }
    }
    
    // Clear any existing callback.
    NSString* callbackId = [self.callbackIds_beaconsMonitoring
                            objectForKey:[self regionDictionaryKey:region]];
    if (nil != callbackId)
    {
        // Clear callback on the JS side.
        CDVPluginResult* result = [CDVPluginResult
                                   resultWithStatus:CDVCommandStatus_NO_RESULT];
        [result setKeepCallbackAsBool:NO];
        [self.commandDelegate
         sendPluginResult:result
         callbackId:callbackId];
        
        // Clear callback id.
        [self.callbackIds_beaconsMonitoring removeObjectForKey: [self regionDictionaryKey:region]];
    }
}

- (void) beaconManager:(id)manager didStartMonitoringForRegion:(CLBeaconRegion *)region
{
    // Not used.
}

- (void) beaconManager:(id)manager
        didEnterRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive)
    {
        [self handleRegionEvent:manager region:region forEventType:@"ENTER"];
    }
}

- (void) beaconManager:(id)manager
         didExitRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive)
    {
        [self handleRegionEvent:manager region:region forEventType:@"EXIT"];
    }
}

- (void) handleRegionEvent: (CLLocationManager*) manager
                    region: (CLBeaconRegion*) region
              forEventType: (NSString*) eventType {
    
    NSMutableDictionary *beaconsData = [EstimoteBeacons getBeaconsPlistData];
    NSMutableDictionary *beacon = [beaconsData valueForKey:region.identifier];
    NSString *strLastNotification = [beacon objectForKey:@"sentnotification"];
    NSInteger idleTime = [[beacon objectForKey:@"idle"] integerValue];
    BOOL resultIdleValidation = [self validateIdleTimeWithLastNotificationDate:strLastNotification andIdleValue:idleTime];
    
    if(idleTime == 0)
    {
        [beacon setValue:0 forKey:@"idle"];
    }
    
    if(resultIdleValidation)
    {
        NSString* state = [eventType isEqualToString:@"ENTER"] ? @"inside" : @"outside";
        NSString* event = [eventType isEqualToString:@"ENTER"] ? @"beacon-monitor-enter" : @"beacon-monitor-exit";
        
        [beacon setValue:state forKey:@"state"];
        [beacon setValue:@"false" forKey:@"openedFromNotification"];
        [self dispatchPush:beacon forStateEvent:event];
        NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
        NSString *dateString = [formatter stringFromDate:[NSDate date]];
        [beacon setValue:dateString forKey:@"sentnotification"];
        [beaconsData setObject:beacon forKey:region.identifier];
        [self writeToPlistDictionary:beaconsData];
    }
    
}

/**
 * CoreLocation monitoring event.
 */
- (void) beaconManager:(id)manager
     didDetermineState:(CLRegionState)state
             forRegion:(CLBeaconRegion*)region
{
    
    // Send result to JavaScript.
    NSString* callbackId = [self.callbackIds_beaconsMonitoring
                            objectForKey:[self regionDictionaryKey:region]];
    if (nil != callbackId)
    {
        // Create state string.
        NSString* stateString;
        switch (state)
        {
            case CLRegionStateInside:
                stateString = @"inside";
                break;
            case CLRegionStateOutside:
                stateString = @"outside";
                break;
            case CLRegionStateUnknown:
            default:
                stateString = @"unknown";
        }
        
        // Create result object.
        NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:8];
        [dict setValue:region.proximityUUID.UUIDString forKey:@"uuid"];
        [dict setValue:region.identifier forKey:@"identifier"];
        [dict setValue:region.major forKey:@"major"];
        [dict setValue:region.minor forKey:@"minor"];
        [dict setValue:stateString forKey:@"state"];
        
        // Send result.
        /*	CDVPluginResult* result = [CDVPluginResult
         resultWithStatus:CDVCommandStatus_OK
         messageAsDictionary:dict];
         [result setKeepCallback:[NSNumber numberWithBool:YES]];
         [self.commandDelegate sendPluginResult:result callbackId:callbackId]; */
    }
}

/**
 * CoreLocation monitoring error event.
 */
- (void) beaconManager:(id)manager monitoringDidFailForRegion:(CLBeaconRegion*)region
             withError:(NSError*)error
{
    // Send error message before callback is cleared.
    NSString* callbackId = [self.callbackIds_beaconsMonitoring
                            objectForKey:[self regionDictionaryKey:region]];
    if (nil != callbackId)
    {
        // Pass error to JavaScript.
        [self.commandDelegate
         sendPluginResult:[CDVPluginResult
                           resultWithStatus:CDVCommandStatus_ERROR
                           messageAsString: error.localizedDescription]
         callbackId: callbackId];
    }
    
    // Stop monitoring and clear callback.
    [self helper_stopMonitoringForRegion:region manager:manager];
}

#pragma mark - CoreLocation authorization

/**
 * Request authorisation for use when app is in foreground.
 */
- (void) beacons_requestWhenInUseAuthorization:(CDVInvokedUrlCommand*)command
{
    //NSLog(@"OBJC requestWhenInUseAuthorization");
    
    // Only applicable on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
    {
        [self.beaconManager requestWhenInUseAuthorization];
    }
    
    // Return OK to JavaScript.
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK]
     callbackId:command.callbackId];
}

/**
 * Request authorisation for use also when app is in background.
 */
- (void) beacons_requestAlwaysAuthorization:(CDVInvokedUrlCommand*)command
{
    //NSLog(@"OBJC requestAlwaysAuthorization");
    
    // Only applicable on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
    {
        [self.beaconManager requestAlwaysAuthorization];
    }
    
    // Return OK to JavaScript.
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK]
     callbackId:command.callbackId];
}

/**
 * Get authorisation status.
 */
- (void) beacons_authorizationStatus:(CDVInvokedUrlCommand*)command
{
    // Default value.
    // TODO: Should we use the real value also on iOS 7? Is it available?
    CLAuthorizationStatus status = kCLAuthorizationStatusNotDetermined;
    
    // Only available on iOS 8 and above.
    if (IsAtLeastiOSVersion(@"8.0"))
    {
        status = [ESTBeaconManager authorizationStatus];
    }
    
    // Return status value to JavaScript.
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK
                       messageAsInt:status]
     callbackId:command.callbackId];
}

#pragma mark - Bluetooth State Implementation

/*********************************************************/
/************ Bluetooth State Implementation *************/
/*********************************************************/

/**
 * Read Bluetooth state.
 */
- (void) bluetooth_bluetoothState: (CDVInvokedUrlCommand*)command
{
    // Return value to JavaScript.
    [self.commandDelegate
     sendPluginResult: [CDVPluginResult
                        resultWithStatus: CDVCommandStatus_OK
                        messageAsBool: self.bluetoothState]
     callbackId: command.callbackId];
}

- (void) bluetooth_pluginInitialize
{
    // Create CoreBluetooth manager.
    self.bluetoothManager = [[CBCentralManager alloc]
                             initWithDelegate: self
                             queue: dispatch_get_main_queue()
                             options: @{CBCentralManagerOptionShowPowerAlertKey: @(NO)}];
    
    // This sets the initial state.
    [self centralManagerDidUpdateState: self.bluetoothManager];
}

- (void) bluetooth_onReset
{
    self.bluetoothManager = nil;
}

#pragma mark - Bluetooth on/off handler

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if ([central state] == CBCentralManagerStatePoweredOn)
    {
        self.bluetoothState = YES;
    }
    else
    {
        self.bluetoothState = NO;
    }
}

@end // End of implementation of class EstimoteBeacons
