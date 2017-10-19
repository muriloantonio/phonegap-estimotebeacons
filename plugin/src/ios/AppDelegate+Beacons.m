//
//  OutSystemsAppDelegate+Beacons.m
//  OutSystems
//
//  Created by Danilo Costa on 08/03/16.
//
//

#import "AppDelegate+Beacons.h"
#import "BeaconsManager.h"
#import <objc/runtime.h>
#import "EstimoteBeacons.h"
ESTBeaconManager *knewbeaconManager;
@implementation AppDelegate (Beacons)

@dynamic beaconManager;

/**
 *
 * This is horrible. I should bath myself on acid after this : (
 *
 */
+(int) hasSwizzledDidReceiveLocalNotification
{
    NSNumber* hasSwizzledDidReceiveLocalNotification = objc_getAssociatedObject(self, @selector(hasSwizzledDidReceiveLocalNotification));
    
    if (hasSwizzledDidReceiveLocalNotification == nil)
    {
        hasSwizzledDidReceiveLocalNotification = @0;
    }
    
    self.hasSwizzledDiDReceiveLocalNotification = [hasSwizzledDidReceiveLocalNotification intValue];
    
    return [hasSwizzledDidReceiveLocalNotification intValue];
}

+(void)setHasSwizzledDiDReceiveLocalNotification:(int)value
{
    objc_setAssociatedObject(self, @selector(hasSwizzledDidReceiveLocalNotification), @(value), OBJC_ASSOCIATION_RETAIN);
}

- (void)setBeaconManager:(ESTBeaconManager *)beaconManager
{
    objc_setAssociatedObject(self, (__bridge const void *)(knewbeaconManager), beaconManager, OBJC_ASSOCIATION_ASSIGN);
}

- (id)beaconManager
{
    return objc_getAssociatedObject(self, (__bridge const void *)(knewbeaconManager));
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        Class class = [self class];
        
        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = @selector(beacons_application:didFinishLaunchingWithOptions:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        
        
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        SEL originalSelectorNoti = @selector(application:didReceiveLocalNotification:);
        SEL swizzledSelectorNoti = @selector(beacons_application:didReceiveLocalNotification:);
        
        Method originalMethodNoti = class_getInstanceMethod(class, originalSelectorNoti);
        Method swizzledMethodNoti = class_getInstanceMethod(class, swizzledSelectorNoti);
        
        BOOL didAddMethodNoti = class_addMethod(class, originalSelectorNoti, method_getImplementation(swizzledMethodNoti), method_getTypeEncoding(swizzledMethodNoti));
        
        if (didAddMethodNoti) {
            class_replaceMethod(class, swizzledSelectorNoti, method_getImplementation(originalMethodNoti), method_getTypeEncoding(originalMethodNoti));
            [self setHasSwizzledDiDReceiveLocalNotification:-1];
        } else {
            method_exchangeImplementations(originalMethodNoti, swizzledMethodNoti);
            [self setHasSwizzledDiDReceiveLocalNotification:1];
        }
    });
}

- (BOOL) beacons_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"---------- beacons_application_didFinishLaunchingWithOptions ----------");
    knewbeaconManager = [ESTBeaconManager new];
    knewbeaconManager.delegate = self;
    [knewbeaconManager requestAlwaysAuthorization];
    
    // Request to Permissions to Send Local Notifications
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    
    return [self beacons_application:application didFinishLaunchingWithOptions:launchOptions];
}

-(void) beacons_application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    NSLog(@"Did Receive Local Notification Delegate - Beacons");
    
    if(notification != nil && notification.userInfo && [notification.userInfo objectForKey:@"beacon.notification.data"]) {
        NSDictionary *userInfo = notification.userInfo;
        
        NSURL *siteURL = [NSURL URLWithString:[userInfo objectForKey:@"deeplink"]];
        
        if(siteURL && [userInfo objectForKey:@"deeplink"] && ![[userInfo objectForKey:@"deeplink"] isEqualToString:@""]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [[UIApplication sharedApplication] openURL:siteURL];
            });
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"CDVLocalNotificationBeacon" object:notification];
    }
    int a = [[self class] hasSwizzledDidReceiveLocalNotification];
    if(a == 1) {
        [self beacons_application:application didReceiveLocalNotification:notification];
    }
}

-(void) beaconManager:(ESTBeaconManager *)manager didEnterRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (!(state == UIApplicationStateBackground || state == UIApplicationStateInactive))
    {
        return;
    }
    
    [self handleRegionEvent:manager forRegion:region onEventType:@"ENTER"];
}

-(void) beaconManager:(ESTBeaconManager *)manager didExitRegion:(CLBeaconRegion *)region
{
    UIApplicationState state = [[UIApplication sharedApplication] applicationState];
    if (!(state == UIApplicationStateBackground || state == UIApplicationStateInactive))
    {
        return;
    }
    
    [self handleRegionEvent:manager forRegion:region onEventType:@"EXIT"];
    
}

- (void) handleRegionEvent: (ESTBeaconManager*) manager
                 forRegion: (CLBeaconRegion*) region
                onEventType: (NSString*) eventType {
    
    NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
    NSMutableDictionary *beaconsData= [EstimoteBeacons getBeaconsPlistData];
    NSMutableDictionary *beaconData = [beaconsData objectForKey:region.identifier];
    NSInteger logHistory = [[beaconData objectForKey:@"logHistory"] integerValue];
    if(logHistory == 1)
    {
        NSMutableDictionary *LogsHistoryDici =[EstimoteBeacons getLogsPlistData];
        if(!LogsHistoryDici) {
            LogsHistoryDici = [[NSMutableDictionary alloc] init];
        }
        
        NSMutableDictionary *NewLog = [[NSMutableDictionary alloc] init];
        [NewLog setObject:[beaconData objectForKey:@"identifier"] forKey:@"BeaconId"];
        NSString *dateStringnow = [formatter stringFromDate:[NSDate date]];
        [NewLog setObject:dateStringnow forKey:@"TimeStamp"];
        NSString* action = [eventType isEqualToString:@"ENTER"] ? @"enter" : @"exit";
        [NewLog setObject:action forKey:@"Action"];
        NSString *dateString = [formatter stringFromDate:[NSDate date]];
        NSString *filePath = [EstimoteBeacons getLogsPlistPath];
        [LogsHistoryDici setObject:NewLog forKey:[dateString stringByAppendingString:[beaconData objectForKey:@"uuid"]]];
        [LogsHistoryDici writeToFile:filePath atomically:YES];
        
    }
    else
    {
        NSString* messageKey = [eventType isEqualToString:@"ENTER"] ? @"enterMessage" : @"exitMessage";
        NSString* titleKey = [eventType isEqualToString:@"ENTER"] ? @"enterTitle" : @"exitTitle";
        NSString* state = [eventType isEqualToString:@"ENTER"] ? @"inside" : @"outside";
        NSString* event = [eventType isEqualToString:@"ENTER"] ? @"beacon-monitor-enter" : @"beacon-monitor-exit";
        
        NSString *message = [beaconData objectForKey:messageKey];
        if(message.length > 0)
        {
            UILocalNotification *notification = [[UILocalNotification alloc] init];
            NSDate *now = [NSDate date];
            NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
            NSString *strLastNotification = [beaconData objectForKey:@"sentnotification"];
            NSDate *lastNotification = [formatter dateFromString:strLastNotification];
            NSInteger mins = 0;
            if(lastNotification != nil)
            {
                NSTimeInterval distanceBetweenDates = [now timeIntervalSinceDate:lastNotification];
                long seconds = lroundf(distanceBetweenDates);
                mins = (seconds % 3600) / 60;
            }
            else
            {
                mins = 9999999;
            }
            NSInteger idleTime = [[beaconData objectForKey:@"idle"] integerValue];
            if(idleTime == 0)
            {
                [beaconData setValue:0 forKey:@"idle"];
            }
            if(mins >= idleTime || [beaconData objectForKey:@"idle"] == 0)
            {
                if (NSFoundationVersionNumber > NSFoundationVersionNumber_iOS_8_1)
                {
                    notification.alertTitle = [beaconData objectForKey:titleKey];
                }
                notification.alertBody =[beaconData objectForKey:messageKey];
                notification.soundName = UILocalNotificationDefaultSoundName;
                
                [beaconData setValue:state forKey:@"state"];
                [beaconData setValue:@"true" forKey:@"openedFromNotification"];
                
                NSMutableDictionary *userInfoDict =[[NSMutableDictionary alloc] init];
                [userInfoDict setObject:beaconData forKey:@"beacon.notification.data"];
                [userInfoDict setValue:event forKey:@"event"];
                
                if([beaconData objectForKey:@"deeplink"])
                {
                    [userInfoDict setValue:[beaconData objectForKey:@"deeplink"] forKey:@"deeplink"];
                }
                
                notification.userInfo = userInfoDict;
                [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
                NSDateFormatter *formatter = [EstimoteBeacons getRegionDateFormatter];
                NSString *dateString = [formatter stringFromDate:[NSDate date]];
                [beaconData setValue:dateString forKey:@"sentnotification"];
                [beaconsData setObject:beaconData forKey:region.identifier];
                [beaconsData writeToFile:[EstimoteBeacons getBeaconsPlistPath] atomically:YES];
            }
        }
    }
}

@end
