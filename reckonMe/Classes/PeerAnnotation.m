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

@synthesize coordinate, title, timestamp, circleOverlay;
@dynamic subtitle;

-(instancetype)initWithPosition:(AbsoluteLocationEntry *)position peerName:(NSString *)peerName {
    
    if (self = [super init]) {
        
        self.coordinate = position.absolutePosition;
        self.title = peerName;
        self.timestamp = [NSDate dateWithTimeIntervalSince1970:position.timestamp];
        self.circleOverlay = [MKCircle circleWithCenterCoordinate:position.absolutePosition
                                                           radius:position.deviation];
    }
    return self;
}

-(void)dealloc {
    
    self.title = nil;
    self.timestamp = nil;
    self.circleOverlay = nil;
    
    [super dealloc];
}

-(NSString *)subtitle {
    
    return [self.timestamp prettyTimestampSinceNow];
}

@end
