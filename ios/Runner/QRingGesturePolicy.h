#pragma once
#import <Foundation/Foundation.h>

// Vendor enum order: music=1, video=2, prayer=3, book=4, photo=5,
// call=6, game=7. Physiological measurement and raw touch events are not modes
// exposed by this settings page. Every non-off choice needs its feature flag.
static inline NSArray<NSNumber *> *QRingGestureModes(NSArray *flags) {
    NSMutableArray *modes = [NSMutableArray arrayWithObject:@0];
    if (flags.count != 7) return modes;
    for (NSUInteger index = 0; index < flags.count; index++) {
        id value = flags[index];
        if ([value isKindOfClass:NSNumber.class] && [value doubleValue] == 1)
            [modes addObject:@(index + 1)];
    }
    return modes;
}
