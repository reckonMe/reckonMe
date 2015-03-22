//
//  PeerAnnotation.h
//  reckonMe
//
//  Created by Benjamin Thiel on 22.03.15.
//
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "LocationEntry.h"

@interface PeerAnnotation : NSObject <MKAnnotation>

@property(nonatomic) CLLocationCoordinate2D coordinate;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, readonly) NSString *subtitle;
@property(nonatomic, retain) NSDate *timestamp;

-(instancetype)initWithPosition:(AbsoluteLocationEntry *)position peerName:(NSString *)peerName;

@end
