/**
*	The BSD 2-Clause License (aka "FreeBSD License")
*
*	Copyright (c) 2012, Benjamin Thiel, Kamil Kloch
*	All rights reserved.
*
*	Redistribution and use in source and binary forms, with or without
*	modification, are permitted provided that the following conditions are met: 
*
*	1. Redistributions of source code must retain the above copyright notice, this
*	   list of conditions and the following disclaimer. 
*	2. Redistributions in binary form must reproduce the above copyright notice,
*	   this list of conditions and the following disclaimer in the documentation
*	   and/or other materials provided with the distribution. 
*
*	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
*	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
*	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
*	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
*	ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
*	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
*	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
*	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

#import "LocationEntry.h"

NSString* const timestampKey = @"timestamp";
NSString* const eastingDeltaKey = @"eastingDelta";
NSString* const northingDeltaKey = @"northingDelta";
NSString* const deviationKey = @"deviation";
NSString* const originNorthingKey = @"originNorthing";
NSString* const originEastingKey = @"originEasting";

@implementation LocationEntry

@synthesize timestamp, northingDelta, eastingDelta, deviation;

- (id)initWithTimestamp:(NSTimeInterval) _timestamp eastingDelta:(double) _easting northingDelta:(double) _northing 
      Deviation:(double) _deviation
{
    self = [super init];
    if (self) {
        timestamp = _timestamp;
        eastingDelta = _easting;
        northingDelta = _northing;
        deviation = _deviation;
    }
    return self;
}

- (id)init
{
    return [self initWithTimestamp:0 eastingDelta:0 northingDelta:0 Deviation:0];
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    [aCoder encodeDouble:timestamp forKey:timestampKey];
    [aCoder encodeDouble:eastingDelta forKey:eastingDeltaKey];
    [aCoder encodeDouble:northingDelta forKey:northingDeltaKey];
    [aCoder encodeDouble:deviation forKey:deviationKey];
}

- (id)initWithCoder:(NSCoder *)coder {
    
    self = [self init];
    
    timestamp = [coder decodeDoubleForKey:timestampKey];
    eastingDelta = [coder decodeDoubleForKey:eastingDeltaKey];
    northingDelta = [coder decodeDoubleForKey:northingDeltaKey];
    deviation = [coder decodeDoubleForKey:deviationKey];

    return self;
}

@end

@implementation AbsoluteLocationEntry

@synthesize mercatorScaleFactor;

-(double)easting {
    
    return originEasting + (eastingDelta * mercatorScaleFactor);
}

-(double)northing {
    
    return originNorthing + (northingDelta * mercatorScaleFactor);
}

- (id)initWithTimestamp:(NSTimeInterval) _timestamp 
           eastingDelta:(double) _easting 
          northingDelta:(double) _northing 
                 origin:(CLLocationCoordinate2D)_origin
              Deviation:(double) _deviation {
    
    self = [super initWithTimestamp:_timestamp
                       eastingDelta:_easting
                      northingDelta:_northing
                          Deviation:_deviation];
    if (self) {
        
        //also implicitly sets mercatorScaleFactor
        self.origin = _origin;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        originEasting = [aDecoder decodeDoubleForKey:originEastingKey];
        originNorthing = [aDecoder decodeDoubleForKey:originNorthingKey];
        
        mercatorScaleFactor = [GeodeticProjection mercatorScaleForLatitude:self.origin.latitude];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    
    [super encodeWithCoder:aCoder];
    [aCoder encodeDouble:originEasting forKey:originEastingKey];
    [aCoder encodeDouble:originNorthing forKey:originNorthingKey];
    //we omit encoding mercatorScaleFactor as it is implicitly specified by the origin
}


-(void)setOrigin:(CLLocationCoordinate2D)origin {
    
    ProjectedPoint newOrigin = [GeodeticProjection coordinatesToCartesian:origin];
    
    originNorthing = newOrigin.northing;
    originEasting = newOrigin.easting;
    
    mercatorScaleFactor = [GeodeticProjection mercatorScaleForLatitude:origin.latitude];
}

-(CLLocationCoordinate2D)origin {
    
    ProjectedPoint origin;
    origin.easting = originEasting;
    origin.northing = originNorthing;
    
    return [GeodeticProjection cartesianToCoordinates:origin];
}

-(CLLocationCoordinate2D)absolutePosition {
    
    ProjectedPoint absPoint;
    absPoint.easting = self.easting;
    absPoint.northing = self.northing;
    
    return [GeodeticProjection cartesianToCoordinates:absPoint];
}

- (NSString *)stringRepresentationForRecording {
    
    return [NSString stringWithFormat:@"%10.3f\t %f\t %f\t %f\t %f\t %f\t",
            timestamp,
            northingDelta,
            eastingDelta,
            originNorthing,
            originEasting,
            deviation];
}

@end
