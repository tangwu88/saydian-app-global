#pragma once
#import "CNActivitySleepPolicy.h"

// The same permanent activity/sleep boundary applies to watches and rings.
static inline BOOL CNRingDeviceSettingsCommandAllowed(NSString *method, NSDictionary *arguments) {
    return CNActivitySleepCommandAllowed(method, arguments);
}
static inline NSDictionary *CNRingDeviceSettingsCapabilities(NSDictionary *source) {
    return CNActivitySleepCapabilities(source);
}
static inline id CNRingDeviceSettingsResult(NSString *method, id source) {
    if ([method isEqual:@"getCapabilities"] && [source isKindOfClass:NSDictionary.class]) return CNRingDeviceSettingsCapabilities(source);
    return CNActivitySleepResult(method, source);
}
static inline NSDictionary *CNRingDeviceSettingsEvent(NSString *type, NSDictionary *source) {
    if ([@[@"capabilities", @"capabilitiesUpdated"] containsObject:type]) return CNRingDeviceSettingsCapabilities(source);
    return CNActivitySleepEvent(type, source);
}
