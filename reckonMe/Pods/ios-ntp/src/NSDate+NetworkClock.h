
// Author: Juan Batiz-Benet

// Category on NSDate to provide convenience access to NetworkClock.
// To use, simply call [NSDate networkDate];

#import <Foundation/Foundation.h>
#import "NetworkClock.h"


@interface NSDate (NetworkClock)



- (NSTimeInterval) timeIntervalSinceNetworkDateWithServer:(NSString *)server;
+ (NSTimeInterval) timeIntervalSinceNetworkDateWithServer:(NSString *)server;

+ (NSDate *) networkDateWithServer:(NSString *)server;
+ (NSDate *) threadsafeNetworkDateWithServer:(NSString *)server;
  // the threadsafe version guards against reading a double that could be
  // potentially being updated at the same time. Since doubles are 8 words,
  // and arm is 32bit, this is not atomic and could provide bad values.


@end


