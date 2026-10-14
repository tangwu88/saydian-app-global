#import <Foundation/Foundation.h>
#import "../../ios/Runner/CNRingDeviceSettingsPolicy.h"
int main(void) {
    @autoreleasepool {
        for (NSString *method in @[@"readAutoMeasureSettings", @"setAutoMeasureSetting", @"readAutoMeasureIntervals", @"setAutoMeasureInterval"]) {
            NSCAssert(!CNRingDeviceSettingsCommandAllowed(method, @{}), @"iOS physiological setting exposed");
            NSCAssert(!CNActivitySleepCommandAllowed(method, @{}), @"watch policy accidentally widened");
        }
        for (NSString *method in @[@"startMeasurement", @"readHeartRateWarning", @"calibrateBloodGlucose"])
            NSCAssert(!CNRingDeviceSettingsCommandAllowed(method, @{}), @"unrequested command enabled");
        NSCAssert(!CNRingDeviceSettingsCommandAllowed(@"writeDeviceFeature", @{@"feature":@"health_reminders"}), @"iOS physiological reminder exposed");
        NSCAssert(!CNActivitySleepCommandAllowed(@"writeDeviceFeature", @{@"feature":@"health_reminders"}), @"watch policy widened");
        NSDictionary *original = @{@"metrics": @[@"steps", @"heart_rate"], @"manualMetrics": @[@"heart_rate"],
          @"features": @[@"health_monitoring", @"health_assessment", @"gesture_control"], @"integratedFeatures": @[@"health_monitoring", @"gesture_control"]};
        NSDictionary *ring = CNRingDeviceSettingsCapabilities(original);
        NSCAssert([ring[@"metrics"] isEqual:@[@"steps"]], @"health display scope widened");
        NSCAssert([ring[@"manualMetrics"] count] == 0, @"manual measurement exposed");
        NSCAssert(![ring[@"features"] containsObject:@"health_monitoring"], @"iOS monitoring capability exposed");
        NSCAssert(![ring[@"features"] containsObject:@"health_assessment"], @"assessment exposed");
        NSCAssert(![CNRingDeviceSettingsCapabilities(@{})[@"features"] containsObject:@"health_monitoring"], @"invented monitoring capability");
        NSCAssert([original[@"metrics"] containsObject:@"heart_rate"], @"original mutated");
        NSCAssert(CNRingDeviceSettingsCommandAllowed(@"writeDeviceFeature", @{@"feature":@"gesture_control"}), @"ordinary gesture control removed");
        NSCAssert(CNRingDeviceSettingsCommandAllowed(@"syncHealthData", @{}), @"activity sleep sync removed");
        NSDictionary *timeline = @{@"deviceId":@"qring:fixture", @"sdkDate":@"2020-04-13", @"timezone":@"+08:00", @"apneaRisk":@1,
            @"rawSummary":@{@"totalSeconds":@28800, @"heartRate":@70},
            @"sessions":@[@{@"kind":@"night", @"heartRate":@70, @"segments":@[@{@"stage":@"light", @"startAt":@"2020-04-12T14:00:00Z", @"endAt":@"2020-04-12T22:00:00Z", @"bloodOxygen":@98}]}]};
        NSDictionary *safe = CNActivitySleepTimeline(timeline);
        NSCAssert(!safe[@"apneaRisk"] && !safe[@"rawSummary"][@"heartRate"], @"physiological summary retained");
        NSDictionary *session = [safe[@"sessions"] firstObject];
        NSDictionary *segment = [session[@"segments"] firstObject];
        NSCAssert(!session[@"heartRate"] && !segment[@"bloodOxygen"], @"physiological interval retained");
        NSCAssert([segment[@"startAt"] isEqual:@"2020-04-12T14:00:00Z"], @"actual interval changed");
        NSCAssert(timeline[@"apneaRisk"] != nil, @"original timeline changed");
        puts("Ring settings scope passed");
    }
}
