#import <Foundation/Foundation.h>
#import "../../ios/Runner/RingNamePolicy.h"

int main(void) {
    @autoreleasepool {
        NSArray<NSString *> *accepted = @[
            @"R12", @" r12 ", @"R12_fixture", @"r12-fixture",
            @"R8", @"custom-R21-tail", @"R22", @"Q_fixture", @"O_fixture", @"R2"
        ];
        NSArray<NSString *> *rejected = @[
            @"R120", @"R123", @"XR12", @"custom-R12-tail", @"R18",
            @"R12-HR05", @"R7", @"HR01", @"K80", @"Q_HR01", @"R8-R7", @""
        ];
        for (NSString *name in accepted) NSCAssert(CNRingIsQRingName(name), @"Missing QRing candidate: %@", name);
        for (NSString *name in rejected) NSCAssert(!CNRingIsQRingName(name), @"Unverified QRing candidate: %@", name);
        NSCAssert(!CNRingIsQRingName(nil), @"Missing name must not select an SDK");
        NSCAssert(CNRingCoolWearModel(@"R12-HR05") != nil, @"Preserve existing LuckRing precedence");
        puts("Ring name policy: 24 assertions passed");
    }
    return 0;
}
