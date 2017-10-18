#import <Cordova/CDV.h>
#import <EstimoteSDK/ESTUtilityManager.h>
#import <EstimoteSDK/ESTBeaconManager.h>
#import <EstimoteSDK/ESTSecureBeaconManager.h>
#import <EstimoteSDK/ESTCloudManager.h>
#import <EstimoteSDK/ESTEddystone.h>
#import <EstimoteSDK/ESTEddystoneManager.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "BeaconsManager.h"

#import "EstimoteBeacons.h"

#define WRITEJS(VAL) [NSString stringWithFormat:@"setTimeout(function() { %@; }, 0);", VAL]

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
 * Secure beacon manager in the Estimote API.
 */
@property (nonatomic, strong) ESTSecureBeaconManager* secureBeaconManager;

/**
 * Estimote Cloud manager.
 */
@property (nonatomic, strong) ESTCloudManager* cloudManager;

/**
 * Dictionary with beacon colors fetched from the cloud.
 * Contains mappings @"UUID:major:minor" -> NSNumber (ESTColor).
 * During fetching of value mapping is @"UUID:major:minor" -> ESTColorUnknown
 */
@property NSMutableDictionary* beaconColors;

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

    // Crete secure beacon manager instance.
    self.secureBeaconManager = [ESTSecureBeaconManager new];
    self.secureBeaconManager.delegate = self;

    // Create clound manager.
    self.cloudManager = [ESTCloudManager new];
    self.beaconColors = [NSMutableDictionary new];

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

    // TODO: Stop any ongoing ranging or monitoring.
}

#pragma mark - Helper methods

/**
 * Create a region object from a dictionary.
 */
- (CLBeaconRegion*) createRegionFromDictionary: (NSDictionary*)regionDict andSave: (BOOL) save
{
    // Default values for the region object.
    NSUUID* uuid = ESTIMOTE_PROXIMITY_UUID;
    //NSString* identifier = @"EstimoteSampleRegion";
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
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
        NSMutableDictionary *myDictionary=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
        if([myDictionary count] == 0)
        {
            myDictionary=[[NSMutableDictionary alloc]init];
        }
        
        [myDictionary setObject:regionDict forKey:[regionDict objectForKey:@"identifier"]];
        [myDictionary writeToFile:path atomically:YES];
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

-(void)ClearHistory: (CDVInvokedUrlCommand*) command {
    [self.commandDelegate runInBackground:^{
        //Get all dicionary entries and convert them into a json
        NSMutableDictionary *historyEntries = [self getLogsPlistData];
        [historyEntries removeAllObjects];
        NSString *filePath = [self getLogsPlistPath];
        [historyEntries writeToFile:filePath atomically:YES];
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }];
}

-(void)GetAllEvents:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        //Get all dicionary entries and convert them into a json
        NSMutableDictionary *historyEntries = [self getLogsPlistData];
        
        if([historyEntries count]>0)
        {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
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

-(void)GetLastEvent:(CDVInvokedUrlCommand*)command
{
    [self.commandDelegate runInBackground:^{
        
        //Get last entry from logs list and convert them into a json
        NSMutableDictionary *myDictionary = [self getLogsPlistData];
        NSArray * values = [myDictionary allValues];
        NSDictionary *LastDici = [values lastObject];
        
        if([LastDici count]>0)
        {
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
            NSString *dateStringnow = [formatter stringFromDate:[LastDici objectForKey:@"TimeStamp"]];
            if(![[LastDici objectForKey:@"TimeStamp"] isKindOfClass:[NSString class]])
            {
                NSString *dateStringnow = [formatter stringFromDate:[LastDici objectForKey:@"TimeStamp"]];
                [LastDici setValue:dateStringnow forKey:@"TimeStamp"];
            }
            else
            {
                [LastDici setValue:[LastDici objectForKey:@"TimeStamp"] forKey:@"TimeStamp"];
            }
            
            NSMutableDictionary *completedici = [[NSMutableDictionary alloc]init];
            [completedici setObject:LastDici forKey:@"Last"];
            
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsDictionary:[completedici objectForKey:@"Last"]];
            
            [self.commandDelegate
             sendPluginResult:result
             callbackId:command.callbackId];
        }
        else
        {
            CDVPluginResult* result = [CDVPluginResult
                                       resultWithStatus:CDVCommandStatus_OK
                                       messageAsString:@"null"];
            
            [self.commandDelegate
             sendPluginResult:result
             callbackId:command.callbackId];
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

-(NSMutableDictionary*) getLogsPlistData
{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Log.plist"];
    NSMutableDictionary *myDictionary=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
    
    return myDictionary;
}

-(NSString*) getLogsPlistPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Log.plist"];
    return [path copy];
}


- (void)dispatchPush:(NSDictionary *)region forStateEvent: (NSString *) event {
    NSLog(@"dispatchPush for region");
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZ"];
    NSInteger logHistory = [[region objectForKey:@"logHistory"] integerValue];
    if(logHistory == 1)
    {
        NSMutableDictionary *LogsHistoryDici =[self getLogsPlistData];
        
        if([LogsHistoryDici count] > 0)
        {
            if([[region objectForKey:@"state"] isEqualToString:@"inside"])
            {
                NSMutableDictionary *NewLog = [[NSMutableDictionary alloc]init];
                [NewLog setObject:[region objectForKey:@"uuid"] forKey:@"RegionId"];
                NSString *dateStringnow = [formatter stringFromDate:[NSDate date]];
                
                
                [NewLog setObject:dateStringnow forKey:@"TimeStamp"];
                [NewLog setObject:@"entry" forKey:@"Action"];
                
                NSString *dateString = [formatter stringFromDate:[NSDate date]];
                
                
                NSString *filePath = [self getLogsPlistPath];
                
                [LogsHistoryDici setObject:NewLog forKey:[dateString stringByAppendingString:[region objectForKey:@"uuid"]]];
                [LogsHistoryDici writeToFile:filePath atomically:YES];
            }
            else
            {
                NSMutableDictionary *NewLog = [[NSMutableDictionary alloc]init];
                [NewLog setObject:[region objectForKey:@"uuid"] forKey:@"RegionId"];
                NSString *dateStringnow = [formatter stringFromDate:[NSDate date]];
                
                
                [NewLog setObject:dateStringnow forKey:@"TimeStamp"];
                [NewLog setObject:@"exit" forKey:@"Action"];
                
                NSString *dateString = [formatter stringFromDate:[NSDate date]];

                NSString *path1 = [self getLogsPlistPath];
                
                [LogsHistoryDici setObject:NewLog forKey:[dateString stringByAppendingString:[region objectForKey:@"uuid"]]];
                [LogsHistoryDici writeToFile:path1 atomically:YES];
            }
        }
        else
        {
            if([[region objectForKey:@"state"] isEqualToString:@"inside"])
            {
                LogsHistoryDici = [[NSMutableDictionary alloc]init];
                NSMutableDictionary *NewLog = [[NSMutableDictionary alloc]init];
                [NewLog setObject:[region objectForKey:@"uuid"] forKey:@"RegionId"];
                NSDate *now =[NSDate date];
                [NewLog setObject:now forKey:@"TimeStamp"];
                [NewLog setObject:@"entry" forKey:@"Action"];
                 NSString *dateString = [formatter stringFromDate:[NSDate date]];

                NSString *filePath = [self getLogsPlistPath];
                
                [LogsHistoryDici setObject:NewLog forKey:[dateString stringByAppendingString:[region objectForKey:@"uuid"]]];
                [LogsHistoryDici writeToFile:filePath atomically:YES];
            }
            else
            {
                LogsHistoryDici = [[NSMutableDictionary alloc]init];
                NSMutableDictionary *NewLog = [[NSMutableDictionary alloc]init];
                [NewLog setObject:[region objectForKey:@"uuid"] forKey:@"RegionId"];
                NSDate *now =[NSDate date];
                [NewLog setObject:now forKey:@"TimeStamp"];
                [NewLog setObject:@"exit" forKey:@"Action"];
                 NSString *dateString = [formatter stringFromDate:[NSDate date]];
                
                NSString *filePath = [self getLogsPlistPath];
                
                [LogsHistoryDici setObject:NewLog forKey:[dateString stringByAppendingString:[region objectForKey:@"uuid"]]];
                [LogsHistoryDici writeToFile:filePath atomically:YES];
            }
            
        }
    }
    else
    {
        NSData *json = [NSJSONSerialization dataWithJSONObject:region options:NSJSONWritingPrettyPrinted error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];

        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:region];
        [pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:@"EstimoteBeaconsStaticChannel"];

    }
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

/**
 * Create a dictionary from a CLBeacon object (used to
 * pass beacon data back to JavaScript).
 */
- (NSDictionary*) coreLocationBeaconToDictionary:(CLBeacon*)beacon
{
    /////////////////////////////////////////////////////
    // Get beacon color. Fetch color async if not set. //
    /////////////////////////////////////////////////////

    // Create key for color dictionary.
    NSString* beaconKey = [NSString stringWithFormat: @"%@:%@:%@",
        beacon.proximityUUID.UUIDString,
        beacon.major,
        beacon.minor];

    // We store colors in this dictionary.
    NSNumber* beaconColor = self.beaconColors[beaconKey];

    // Check if color is set.
    if (nil == beaconColor)
    {
        // Color is not set. Set color to unknown to begin with.
        self.beaconColors[beaconKey] = [NSNumber numberWithInt: ESTColorUnknown];

        // Fetch color from cloud.
        [self.cloudManager
            fetchColorForBeacon:beacon
            completion:^(NSObject *value, NSError *error)
            {
                // TODO: Check error? Where are errors documented?
                // Any threading problems setting color value async?
                self.beaconColors[beaconKey] = value;
            }];
    }

    //////////////////////////////////////////////
    // Store beacon properties in a dictionary. //
    //////////////////////////////////////////////

    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:8];

    [dict setValue:beacon.proximityUUID.UUIDString forKey:@"proximityUUID"];
    [dict setValue:beacon.major forKey:@"major"];
    [dict setValue:beacon.minor forKey:@"minor"];
    [dict setValue:[NSNumber numberWithInteger:beacon.rssi] forKey:@"rssi"];
    [dict setValue:[NSNumber numberWithInt:beacon.proximity] forKey:@"proximity"];
    [dict setValue:[NSNumber numberWithDouble:beacon.accuracy] forKey:@"distance"];
    [dict setValue:beaconColor forKey:@"color"];

    return dict;
}

/**
 * Create a dictionary from an ESTBluetoothBeacon object (used to
 * pass beacon data back to JavaScript).
 */
- (NSDictionary*) bluetoothBeaconToDictionary:(ESTBluetoothBeacon*)beacon
{
    NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:8];
        [dict setValue:beacon.major forKey:@"major"];
    [dict setValue:beacon.minor forKey:@"minor"];
    [dict setValue:[NSNumber numberWithInteger:beacon.rssi] forKey:@"rssi"];
    [dict setValue:beacon.macAddress forKey:@"macAddress"];
    [dict setValue:beacon.measuredPower forKey:@"measuredPower"];
    [dict setValue:[NSNumber numberWithInteger:beacon.firmwareState] forKey:@"firmwareState"];

    // Properties available on ESTBluetoothBeacon but not used.
    //@property (nonatomic, strong) CBPeripheral *peripheral;
    //@property (nonatomic, strong) NSDate *discoveryDate;
    //@property (nonatomic, strong) NSData *advertisementData;

    // TODO: How to find beacon color during Bluetooth scan?
    //[dict setValue:[NSNumber numberWithInteger:beacon.color] forKey:@"color"];

    // TODO: Is it possible to find UUID and proximity/distance with new API?
    //[dict setValue:beacon.proximityUUID.UUIDString forKey:@"proximityUUID"];
    //[dict setValue:beacon.distance forKey:@"distance"];
    //[dict setValue:[NSNumber numberWithInt:beacon.proximity] forKey:@"proximity"];

    return dict;
}

/**
 * Create a dictionary object with ESTBluetoothBeacon beacons.
 */
- (NSDictionary*) dictionaryWithBluetoothBeacons:(NSArray*)beacons
{
    // Convert beacons to a an array of property-value objects.
    NSMutableArray* beaconArray = [NSMutableArray array];
    for (ESTBluetoothBeacon* beacon in beacons)
    {
        [beaconArray addObject:[self bluetoothBeaconToDictionary:beacon]];
    }
    
    return @{
             @"beacons" : beaconArray
             };
}

/**
 * Create a dictionary object with a CLBeaconRegion and CLBeacon beacons.
 */
- (NSDictionary*) dictionaryWithRegion:(CLBeaconRegion*)region
                            andBeacons:(NSArray*)beacons
{
    // Convert beacons to a an array of property-value objects.
    NSMutableArray* beaconArray = [NSMutableArray array];
    for (CLBeacon* beacon in beacons)
    {
        [beaconArray addObject:[self coreLocationBeaconToDictionary:beacon]];
    }
    
    NSDictionary* regionDictionary = [self regionToDictionary:region];
    
    return @{
             @"region" : regionDictionary,
             @"beacons" : beaconArray
             };
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
        [self
         beacons_impl_startMonitoringForRegion:command
         manager:self.beaconManager];
    }];
}

/**
 * Stop CoreLocation monitoring.
 */
- (void) beacons_stopMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
    [self beacons_impl_stopMonitoringForRegion:command manager:self.beaconManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
    NSFileManager *Manager = [NSFileManager defaultManager];
    [Manager removeItemAtPath: path error:NULL];
}
/**
 * Start secure CoreLocation monitoring.
 */
- (void) beacons_startSecureMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
    [self
     beacons_impl_startMonitoringForRegion:command
     manager:self.secureBeaconManager];
}

/**
 * Stop secure CoreLocation monitoring.
 */
- (void) beacons_stopSecureMonitoringForRegion:(CDVInvokedUrlCommand*)command
{
    [self
     beacons_impl_stopMonitoringForRegion:command
     manager:self.secureBeaconManager];
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
    [self.callbackIds_beaconsMonitoring
     setObject:command.callbackId
     forKey:[self regionDictionaryKey:region]];
    
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
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
     callbackId:command.callbackId];
}

- (void) helper_stopMonitoringForRegion:(CLBeaconRegion*)region
                                manager:(id)aManager
{
    // Stop monitoring the region.
    [aManager stopMonitoringForRegion:region];
    
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
        [self.callbackIds_beaconsMonitoring
         removeObjectForKey:[self regionDictionaryKey:region]];
    }
}

- (void) beaconManager:(id)manager
didStartMonitoringForRegion:(CLBeaconRegion *)region
{
    // Not used.
}
-(NSMutableDictionary*) getPlistData
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
    NSMutableDictionary *myDictionary=[[NSMutableDictionary alloc] initWithContentsOfFile:path];
    
    return myDictionary;
}

// Helper to re-write the beacon data on plist file
-(void) writeToPlistDictionarity: (NSMutableDictionary *) beaconData {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
    [beaconData writeToFile:path atomically:YES];
}

-(BOOL) validateIdleTimeWithLastNotificationDate: (NSString *) lastNotificationDate andIdleValue: (NSInteger) idle {
    NSDate *now =[NSDate date];
    //NSDate *lastNotification = [beacondata objectForKey:@"sentnotification"];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
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

- (void) beaconManager:(id)manager
        didEnterRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive)
    {
        NSMutableDictionary *Beacondata = [self getPlistData];
        NSMutableDictionary *SelectedBeacon = [Beacondata valueForKey:region.identifier];
        
        NSString *strLastNotification = [SelectedBeacon objectForKey:@"sentnotification"];
        NSInteger verify = [[SelectedBeacon objectForKey:@"idle"] integerValue];
        BOOL resultIdleValidation = [self validateIdleTimeWithLastNotificationDate:strLastNotification andIdleValue:verify];
        
        if(verify == 0)
            [SelectedBeacon setValue:0 forKey:@"idle"];
        
        if(resultIdleValidation)
        {
            [SelectedBeacon setValue:@"inside" forKey:@"state"];
            [SelectedBeacon setValue:@"false" forKey:@"openedFromNotification"];
            [self dispatchPush:SelectedBeacon forStateEvent:@"beacon-monitor-enter"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
            NSString *dateString = [formatter stringFromDate:[NSDate date]];
            
            [SelectedBeacon setValue:dateString forKey:@"sentnotification"];
            
            [Beacondata setObject:SelectedBeacon forKey:region.identifier];
            [self writeToPlistDictionarity:Beacondata];
        }
    }
    // Not used.
}

- (void) beaconManager:(id)manager
         didExitRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (state == UIApplicationStateActive)
    {
        NSMutableDictionary *Beacondata = [self getPlistData];
        NSMutableDictionary *SelectedBeacon = [Beacondata valueForKey:region.identifier];
        
        NSString *strLastNotification = [SelectedBeacon objectForKey:@"sentnotification"];
        NSInteger verify = [[SelectedBeacon objectForKey:@"idle"] integerValue];
        BOOL resultIdleValidation = [self validateIdleTimeWithLastNotificationDate:strLastNotification andIdleValue:verify];
        
        if(verify == 0)
        [SelectedBeacon setValue:0 forKey:@"idle"];
        
        if(resultIdleValidation)
        {
            [SelectedBeacon setValue:@"outside" forKey:@"state"];
            [SelectedBeacon setValue:@"false" forKey:@"openedFromNotification"];
            [self dispatchPush:SelectedBeacon forStateEvent:@"beacon-monitor-exit"];
            
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSZ"];
            NSString *dateString = [formatter stringFromDate:[NSDate date]];
            
            [SelectedBeacon setValue:dateString forKey:@"sentnotification"];
            
            
            [Beacondata setObject:SelectedBeacon forKey:region.identifier];
            [self writeToPlistDictionarity:Beacondata];
            
            //[beacondata setValue:nowregister forKey:@"sentnotification"];
            
            
          /*  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *path = [documentsDirectory stringByAppendingPathComponent:@"Beacons.plist"];
            [Beacondata writeToFile:path atomically:YES]; */

        }
    }
}

/**
 * CoreLocation monitoring event.
 */
- (void) beaconManager:(id)manager
     didDetermineState:(CLRegionState)state
             forRegion:(CLBeaconRegion*)region
{
    //NSLog(@"OBJC didDetermineStateforRegion");
    
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
- (void) beaconManager:(id)manager
monitoringDidFailForRegion:(CLBeaconRegion*)region
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

#pragma mark - Config methods

- (void) beacons_enableAnalytics: (CDVInvokedUrlCommand*)command
{
    BOOL enable = [[command argumentAtIndex: 0] boolValue];
    
    [ESTCloudManager enableAnalytics: enable];
    
    [self.commandDelegate
     sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
     callbackId: command.callbackId];
}

- (void) beacons_isAnalyticsEnabled: (CDVInvokedUrlCommand*)command
{
    BOOL isAnalyticsEnabled = [ESTCloudManager isAnalyticsEnabled];
    
    [self.commandDelegate
     sendPluginResult: [CDVPluginResult
                        resultWithStatus: CDVCommandStatus_OK
                        messageAsBool: isAnalyticsEnabled]
     callbackId: command.callbackId];
}

- (void) beacons_isAuthorized: (CDVInvokedUrlCommand*)command
{
    BOOL isAuthorized = [ESTCloudManager isAuthorized];
    
    [self.commandDelegate
     sendPluginResult: [CDVPluginResult
                        resultWithStatus: CDVCommandStatus_OK
                        messageAsBool: isAuthorized]
     callbackId: command.callbackId];
}

- (void) beacons_setupAppIDAndAppToken: (CDVInvokedUrlCommand*)command
{
    NSString* appID = [command argumentAtIndex: 0];
    NSString* appToken = [command argumentAtIndex: 1];
    
    [ESTCloudManager setupAppID: appID andAppToken: appToken];
    
    [self.commandDelegate
     sendPluginResult: [CDVPluginResult resultWithStatus: CDVCommandStatus_OK]
     callbackId: command.callbackId];
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

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
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
