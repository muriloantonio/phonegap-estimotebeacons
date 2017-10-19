#import <Cordova/CDV.h>

@interface EstimoteBeacons : CDVPlugin
+ (NSDateFormatter *)getRegionDateFormatter;
+ (NSMutableDictionary*) getLogsPlistData;
+ (NSString*) getLogsPlistPath;
+ (NSMutableDictionary*) getBeaconsPlistData;
+ (NSString*) getBeaconsPlistPath;

- (EstimoteBeacons*) pluginInitialize;
- (void) onReset;

@end
