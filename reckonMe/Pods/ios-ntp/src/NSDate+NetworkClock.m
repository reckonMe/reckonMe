

#import "NSDate+NetworkClock.h"

@implementation NSDate (NetworkClock)


- (NSTimeInterval) timeIntervalSinceNetworkDateWithServer:(NSString *)server {
    return [self timeIntervalSinceDate:[NSDate networkDateWithServer:server]];
}

+ (NSTimeInterval) timeIntervalSinceNetworkDateWithServer:(NSString *)server {
    return [[self date] timeIntervalSinceNetworkDateWithServer:server];
}



+ (NSDate *) networkDateWithServer:(NSString *)server {
    return [[NetworkClock sharedNetworkClockWithServer:server] networkTime];
}

+ (NSDate *) threadsafeNetworkDateWithServer:(NSString *)server {
    NetworkClock *sharedClock = [NetworkClock sharedNetworkClockWithServer:server];
    @synchronized(sharedClock) {
        return [sharedClock networkTime];
    }
}


@end