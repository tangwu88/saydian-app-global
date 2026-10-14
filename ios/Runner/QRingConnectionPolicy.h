#import <Foundation/Foundation.h>

// A cached name alone is not discovery evidence. Only an exact, previously
// handshaken UUID with a current system link may supplement scan results.
static inline BOOL QRingCanListRememberedSystemLink(BOOL sameUUID,
                                                   BOOL systemConnected,
                                                   BOOL alreadyListed) {
    return sameUUID && systemConnected && !alreadyListed;
}

// Release a missing cancellation callback only with actual radio-state proof,
// while the original operation and exact peripheral still own the channel.
static inline BOOL QRingCanFinishCancellation(BOOL sameGeneration,
                                              BOOL samePeripheral,
                                              BOOL cancelling,
                                              BOOL radioDisconnected) {
    return sameGeneration && samePeripheral && cancelling && radioDisconnected;
}
