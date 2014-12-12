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

#import <Foundation/Foundation.h>
#import "GeodeticProjection.h"
#import <CoreLocation/CoreLocation.h>

@interface LocationEntry : NSObject <NSCoding> {
    
    double timestamp, eastingDelta, northingDelta, deviation;
}

@property(nonatomic, assign) NSTimeInterval timestamp;
@property(nonatomic) double eastingDelta;
@property(nonatomic) double northingDelta;
@property(nonatomic) double deviation;

- (id)initWithTimestamp:(NSTimeInterval) _timestamp 
           eastingDelta:(double) _easting 
          northingDelta:(double) _northing 
              Deviation:(double) _deviation;

@end


@interface AbsoluteLocationEntry : LocationEntry {
    
    double originEasting, originNorthing;
    double mercatorScaleFactor;
}

@property(nonatomic)           CLLocationCoordinate2D origin;

@property(nonatomic, readonly) CLLocationCoordinate2D absolutePosition;
@property(nonatomic, readonly) double mercatorScaleFactor;

//absolute values
@property(nonatomic, readonly) double northing;
@property(nonatomic, readonly) double easting;

- (id)initWithTimestamp:(NSTimeInterval) _timestamp 
           eastingDelta:(double) _easting 
          northingDelta:(double) _northing 
                 origin:(CLLocationCoordinate2D) _origin
              Deviation:(double) _deviation;

- (instancetype)initWithBase64String:(NSString *)encodedPosition;

- (NSString *)stringRepresentationForRecording;
- (NSString *)toBase64Encoding;
    
@end
