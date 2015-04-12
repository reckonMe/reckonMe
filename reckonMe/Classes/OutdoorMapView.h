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

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "LocationEntry.h"

@class OutdoorMapView; //forward declaration
@protocol MapViewDelegate <NSObject>

-(void)userCorrectedPositionTo:(AbsoluteLocationEntry *)correctedPosition onMapView:(OutdoorMapView *)view;
-(void)userMovedRotationAnchorTo:(AbsoluteLocationEntry *)rotationAnchor;
-(void)userTappedMoveToGPSbutton;
-(void)userTouchedMap;

@end

@interface OutdoorMapView : UIView <MKMapViewDelegate>

@property(nonatomic, assign)id<MapViewDelegate> mapViewDelegate;
@property(nonatomic) BOOL showGPSfix;
@property(nonatomic) BOOL showSatelliteImages;

-(void)addExchangeWithPeerAtPosition:(AbsoluteLocationEntry *)peerPosition peerName:(NSString *)peerName;
-(void)removeExchanges;
-(void)addPathLineTo:(AbsoluteLocationEntry *)mapPoint;
-(void)replacePathBy:(NSArray *)path;
-(void)clearPath;

//moves the marker symbolizing the starting position to the specified point
-(void)setStartingPosition:(AbsoluteLocationEntry *)mapPoint;
-(void)moveMapCenterTo:(AbsoluteLocationEntry *)mapPoint;
-(void)moveCurrentPositionMarkerTo:(AbsoluteLocationEntry *)newPosition;
-(void)updateGPSposition:(AbsoluteLocationEntry *)gpsPosition;

-(void)startStartingPositionFixingMode;
-(void)stopStartingPositionFixingMode;

-(void)startPathRotationModeForSubPath:(NSArray *)subPath aroundPosition:(AbsoluteLocationEntry *)rotationCenter;
-(void)rotatePathViewBy:(CGFloat)radians;
-(void)stopPathRotationMode;

-(void)rotateMapByDegrees:(double)degrees timestamp:(NSTimeInterval)timestamp;

@end
