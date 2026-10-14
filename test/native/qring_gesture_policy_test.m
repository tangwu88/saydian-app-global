#import <Foundation/Foundation.h>
#import "../../ios/Runner/QRingGesturePolicy.h"
int main(void) {
    @autoreleasepool {
        NSCAssert(([QRingGestureModes(@[]) isEqual:@[@0]]), @"unknown flags invented modes");
        NSCAssert(([QRingGestureModes(@[@NO, @NO, @NO, @NO, @YES, @NO, @NO]) isEqual:@[@0, @5]]), @"QRing photo must be mode 5, not CoolWear mode 4");
        NSCAssert(([QRingGestureModes(@[@1, @1, @1, @1, @1, @1, @1]) isEqual:@[@0, @1, @2, @3, @4, @5, @6, @7]]), @"unexpected mode exposed");
        NSCAssert(([QRingGestureModes(@[@2, @"1", NSNull.null, @NO, @YES, @(-1), @0]) isEqual:@[@0, @5]]), @"unverified feature enabled");
        puts("QRing gesture flag and SDK mode mapping passed");
    }
}
