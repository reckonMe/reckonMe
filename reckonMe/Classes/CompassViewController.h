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

const double kDegreeThreshold = 4;//degrees from north
const double kDeviationThreshold = 25.0;//degrees
const int kDismissalInterval = 3;//seconds

NSString* const defaultStatus = @"Please point the device northwards.\nSwipe down to abort.";
NSString* const calibrateStatus = @"Please recalibrate the compass.";
NSString* const waitingStatusFormat = @"Please hold still for %.0f seconds.";

@protocol CompassViewDelegate <NSObject>

-(void)compassPointingNorthwards;
-(void)userAbortedWaitingForHeading;

@end

@interface CompassViewController : UIViewController

@property (nonatomic, retain) IBOutlet UIImageView *compassImageView;
@property (nonatomic, retain) IBOutlet UILabel *degreesText;
@property (nonatomic, retain) IBOutlet UILabel *deviationText;
@property (nonatomic, retain) IBOutlet UILabel *statusText;
@property (nonatomic, assign) id<CompassViewDelegate> delegate;

-(void)didReceiveCompassValueWithTrueHeading:(double)trueHeading 
                             headingAccuracy:(double)headingAccuracy
                                   timestamp:(double)timestamp;

@end
