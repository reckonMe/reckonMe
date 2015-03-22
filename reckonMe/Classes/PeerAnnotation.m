//
//  PeerAnnotation.m
//  reckonMe
//
//  Created by Benjamin Thiel on 22.03.15.
//
//

#import "PeerAnnotation.h"
#import "NSDate+PrettyTimestamp.h"

@implementation PeerAnnotation

@synthesize coordinate, title, timestamp;
@dynamic subtitle;

-(instancetype)initWithPosition:(AbsoluteLocationEntry *)position peerName:(NSString *)peerName {
    
    if (self = [super init]) {
        
        self.coordinate = position.absolutePosition;
        self.title = peerName;
        self.timestamp = [NSDate dateWithTimeIntervalSince1970:position.timestamp];
    }
    return self;
}

-(NSString *)subtitle {
    
    return [self.timestamp prettyTimestampSinceNow];
}

@end
