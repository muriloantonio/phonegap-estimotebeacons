//
//  OutSystemsAppDelegate+Beacons.m
//  OutSystems
//
//  Created by Danilo Costa on 08/03/16.
//
//

#import "AppDelegate+Beacons.h"

ESTBeaconManager *knewbeaconManager;
@implementation AppDelegate (Beacons)



@dynamic beaconManager;

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
        SEL swizzledSelector = @selector(xxx_application:didFinishLaunchingWithOptions:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
    });
}

- (BOOL) xxx_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
     NSLog(@"---------- extra thing ----------");
    knewbeaconManager = [ESTBeaconManager new];
    knewbeaconManager.delegate = self;
    [knewbeaconManager requestAlwaysAuthorization];
    
    // Request to Permissions to Send Local Notifications
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    
    
    return [self xxx_application:application didFinishLaunchingWithOptions:launchOptions];
}


-(void) application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
    //NSLog(@"-------- CENAS ---------");
}


-(void)beaconManager:(ESTBeaconManager *)manager didEnterRegion:(CLBeaconRegion *)region
{
  /*      NSLog(@"---------- Enter Region ----------");
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = @"Enter region";
        notification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification]; */
}

-(void)beaconManager:(ESTBeaconManager *)manager didExitRegion:(CLBeaconRegion *)region
{
  /*      UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = @"Exit region";
        notification.soundName = UILocalNotificationDefaultSoundName;
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification]; */
}

@end
