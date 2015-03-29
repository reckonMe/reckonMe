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
#import <CoreLocation/CoreLocation.h>
#import <CoreMotion/CMDeviceMotion.h>
#import "LocationEntry.h"

@protocol SensorListener

-(void)didReceiveDeviceMotion:(CMDeviceMotion *)motion timestamp:(NSTimeInterval)timestamp;

@optional

- (void)didReceiveGPSvalueWithLongitude:(double)longitude latitude:(double)latitude altitude:(double)altitude speed:(double)speed course:(double)course horizontalAccuracy:(double)horizontalAccuracy verticalAccuracy:(double)verticalAccuracy timestamp:(NSTimeInterval)timestamp label:(int)label;

- (void)didReceiveCompassValueWithMagneticHeading:(double)magneticHeading trueHeading:(double)trueHeading headingAccuracy:(double)headingAccuracy X:(double)x Y:(double)y Z:(double)z timestamp:(NSTimeInterval)timestamp label:(int)label;

@end


@protocol PDRControllerProtocol

- (void)startPDRsessionWithGPSfix:(AbsoluteLocationEntry *)startingPosition; 

- (void)stopPDRsession;

- (void)didReceiveManualPostionCorrection:(AbsoluteLocationEntry *)position;

/* data is exchanged if at least one party responds with YES */
- (bool)shouldConnectToPeerID:(NSString *) peerID;

- (void)didReceivePosition:(AbsoluteLocationEntry *)position ofPeer:(NSString *)peerID isRealName:(BOOL)isRealName;

- (AbsoluteLocationEntry *)positionForExchange;

- (void)rotatePathBy:(double)radians;

- (NSMutableArray *)partOfPathToBeManuallyRotatedWithPinLocation:(AbsoluteLocationEntry *)pinLocation;

@end


@protocol PDRView

- (void)didReceivePosition:(AbsoluteLocationEntry *)position isResultOfExchange:(BOOL)fromExchange;

- (void)didReceivePeerPosition:(AbsoluteLocationEntry *)position ofPeer:(NSString *)peerName isRealName:(BOOL)isRealName;

- (void)didReceiveCompletePath:(NSArray *)path;

@end


@protocol PDRLogger 

// raw PDR trace
- (void)didReceivePDRPosition:(AbsoluteLocationEntry *)position;

// collaborative localisation trace
- (void)didReceiveCollaborativeLocalisationPosition:(AbsoluteLocationEntry *)position;

// manual position corrections of the user
- (void)didReceiveManualPositionCorrection:(AbsoluteLocationEntry *)position;

// manual position corrections of the user
- (void)didReceiveManualHeadingCorrectionAround:(AbsoluteLocationEntry *)position By:(double)radians Cumulative:(double)cumulative;

// collaborative localisation position update
- (void)didReceiveCollaborativePositionCorrectionFrom:(AbsoluteLocationEntry *)before ToPosition:(AbsoluteLocationEntry *)after FromPeer:(NSString *) peerID;

// track of connection queries
- (void)didReceiveConnectionQueryToPeer:(NSString *) peerID WithTimestamp:(NSTimeInterval) timestamp ShouldConnect:(bool) shouldConnect;

// complete collaborative path (rotated / manually corrected)
- (void)didReceiveCompleteCollaborativePath:(NSArray *)path;
                                                                           
@end
