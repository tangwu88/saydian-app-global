#import <Foundation/Foundation.h>
#import "../../ios/Runner/CoolWearPolicy.h"
#import "../../ios/Runner/CoolWearHistory.h"
#import "../../ios/Runner/CoolWearRecovery.h"
#import "../../ios/Runner/CNActivitySleepPolicy.h"

int main(void) {
    @autoreleasepool {
        for (NSString *name in @[@"HR01", @"HR05", @"K80", @"R7", @"r7pro", @"R7Ultra-AB12", @" R7Y ", @"K80_AB:CD:EF:12:34:56",
            @"K800", @"R70", @"R7Pro Max", @"R7Ultra Max", @"R7Ultra-other", @"K80-other", @"HR05X",
            @"custom-hr01-tail", @"custom-R7-tail", @"Q_HR01", @"R8-R7"])
            NSCAssert(CoolWearModel(name) != nil, @"Known vendor model rejected");
        for (NSString *name in @[@"LUCKRING", @"", @"HR04", @"K79", @"R6", @"R9", @"custom-R8-tail"])
            NSCAssert(CoolWearModel(name) == nil, @"Unconfirmed name selected LUCKRING");
        for (NSString *name in @[@"R8", @"custom-r8-tail", @"R80", @"prefix-R21-other", @"custom-r22-tail", @"Q_fixture", @"O_fixture"])
            NSCAssert(CNRingIsQRingName(name), @"Confirmed QRing keyword rejected");
        for (NSString *name in @[@"prefix-R7-tail", @"custom-K80-tail", @"Q_HR01", @"R8-HR05", @"Unknown", @""])
            NSCAssert(!CNRingIsQRingName(name), @"Name entered wrong or duplicate QRing channel");
        NSCAssert(CoolWearModel(nil) == nil && !CNRingIsQRingName(nil), @"Missing name accepted");
        NSCAssert([CoolWearModel(@"R7Pro-AB12") isEqual:@"R7Pro"], @"Case/suffix lost");
        NSCAssert([CoolWearModel(@"r7ultra") isEqual:@"R7Ultra"], @"Ultra casing lost");
        NSCAssert([CoolWearModel(@"custom-r7pro-max") isEqual:@"R7Pro"], @"Embedded model casing lost");
        NSCAssert(!CoolWearHasKnownCapabilities(@{}), @"Missing handshake became ready");
        NSCAssert(!CoolWearFlag(@{@"manualHr":@2}, @"manualHr"), @"Invalid capability enabled");
        NSCAssert(CoolWearNumber(@YES) == nil, @"Boolean became health data");
        __block int completed = 0;
        CoolWearCompletion completion = CoolWearCompleteOnce(^(id value) { completed++; });
        completion(@1); completion(@2);
        NSCAssert(completed == 1, @"Duplicate native callback completed twice");
        NSString *uuid = @"00000000-0000-0000-0000-000000000001";
        NSCAssert(CoolWearRecoveryTargetValid(uuid, @"HR01", @"owner-fixture"), @"Exact owner target rejected");
        NSCAssert(!CoolWearRecoveryTargetValid(uuid, @"HR01", nil), @"Ownerless recovery adopted");
        NSCAssert(!CoolWearRecoveryMatches(@"00000000-0000-0000-0000-000000000002", @"HR01", uuid, @"HR01", @"owner-fixture", 1, 1), @"Same name chose another UUID");
        NSDictionary *projected = CNActivitySleepCapabilities(@{
            @"metrics":@[@"steps",@"sleep",@"heart_rate"], @"manualMetrics":@[@"heart_rate"],
            @"historyMetrics":@[@"sleep",@"blood_oxygen"],
            @"features":@[@"camera",@"health_monitoring"], @"integratedFeatures":@[@"camera",@"health_monitoring"]});
        NSCAssert(([projected[@"metrics"] isEqual:@[@"steps",@"sleep"]] && [projected[@"manualMetrics"] count] == 0), @"iOS product boundary changed");
        NSCAssert(!CNActivitySleepCommandAllowed(@"startMeasurement", @{@"metric":@"heart_rate"}), @"Blocked health command sent");
        NSDate *now = [NSDate dateWithTimeIntervalSince1970:1800000000];
        NSArray *closed = @[
            @{@"SleepStartTime":@1799900000,@"SleepType":@1},
            @{@"SleepStartTime":@1799900001,@"SleepType":@2},
            @{@"SleepStartTime":@1799903601,@"SleepType":@3},
            @{@"SleepStartTime":@1799907201,@"SleepType":@4}];
        NSArray *records = CoolWearClosedSleepSummaries(closed, now);
        NSCAssert(records.count == 1 && [records[0][@"values"][@"value"] doubleValue] == 2, @"Vendor sleep units changed");
        NSArray *segments = records[0][@"segments"];
        NSCAssert(segments.count == 3 && [segments[0][@"stage"] isEqual:@"unknown"] &&
            [segments[1][@"stage"] isEqual:@"deep"] && [segments[2][@"stage"] isEqual:@"light"], @"Real boundaries or unknown START interval lost");
        NSISO8601DateFormatter *iso = [NSISO8601DateFormatter new];
        NSCAssert([[iso dateFromString:segments[0][@"startAt"]] timeIntervalSince1970] == 1799900000 &&
            [[iso dateFromString:segments[2][@"endAt"]] timeIntervalSince1970] == 1799907201, @"Sleep timestamps were inferred");
        NSArray *conflicting = [closed arrayByAddingObject:@{@"SleepStartTime":@1799903601,@"SleepType":@2}];
        NSCAssert(CoolWearClosedSleepSummaries(conflicting, now).count == 0, @"Conflicting timeline accepted");
        NSArray *unknown = @[
            closed[0], closed[1], @{@"SleepStartTime":@1799901801,@"SleepType":@99}, closed[2], closed[3]];
        NSDictionary *unknownRecord = CoolWearClosedSleepSummaries(unknown, now).firstObject;
        NSCAssert([unknownRecord[@"values"][@"value"] doubleValue] == 1.5 &&
            [unknownRecord[@"segments"][2][@"stage"] isEqual:@"unknown"], @"Unknown interval became sleep");
        NSCAssert(CoolWearClosedSleepSummaries([closed subarrayWithRange:NSMakeRange(0, 3)], now).count == 0, @"Unfinished sleep became complete");
        puts("CoolWear native contracts passed: model whitelist, handshake gates, completion once, exact UUID/owner, iOS scope, closed sleep.");
    }
    return 0;
}
