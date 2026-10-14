#pragma once
#import <Foundation/Foundation.h>

// Bluetooth names select a candidate channel, never a device capability.
static inline NSString *CNRingCoolWearModel(NSString *name) {
    if (![name isKindOfClass:NSString.class]) return nil;
    NSString *upper = [[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    for (NSString *model in @[@"HR01", @"HR05", @"K80", @"R7ULTRA", @"R7PRO", @"R7Y", @"R7"]) {
        if (![upper containsString:model]) continue;
        if ([model isEqualToString:@"R7ULTRA"]) return @"R7Ultra";
        return [model isEqualToString:@"R7PRO"] ? @"R7Pro" : model;
    }
    return nil;
}

static inline BOOL CNRingIsQRingName(NSString *name) {
    if (![name isKindOfClass:NSString.class] || CNRingCoolWearModel(name)) return NO;
    NSString *upper = [[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    return [upper containsString:@"R8"] || [upper containsString:@"R21"] || [upper containsString:@"R22"] ||
        [upper hasPrefix:@"Q_"] || [upper hasPrefix:@"O_"] || [upper hasPrefix:@"R2"];
}
