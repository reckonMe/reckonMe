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

@class SettingsViewController;
@protocol SettingsViewControllerDelegate <NSObject>

-(void)dismissSettingsViewController:(SettingsViewController *)sender;

@end

@interface SettingsViewController : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic, assign) id<SettingsViewControllerDelegate> delegate;

@property (nonatomic, retain) UIVisualEffectView *blurryBackground;

@property (nonatomic, retain) IBOutlet UIStepper *stepLengthStepper;
@property (nonatomic, retain) IBOutlet UILabel *stepLengthLabel;

@property (nonatomic, retain) IBOutlet UISwitch *satelliteImageSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *p2pExchangeSwitch;
@property (nonatomic, retain) IBOutlet UISwitch *beaconSwitch;
@property (nonatomic, retain) IBOutlet UILabel *beaconLabel;

@property (nonatomic, retain) IBOutlet UISlider *rssiStepper;
@property (nonatomic, retain) IBOutlet UILabel *rssiLabel;
@property (nonatomic, retain) IBOutlet UILabel *rssiDescriptionLabel;

@property (nonatomic, retain) IBOutlet UIStepper *minRequiredDistanceStepper;
@property (nonatomic, retain) IBOutlet UILabel *minRequiredDistanceLabel;

-(IBAction)stepLengthChanged:(UIStepper *)sender;

-(IBAction)satelliteImageSwitchChanged:(UISwitch *)sender;
-(IBAction)p2pExchangeChanged:(UISwitch *)sender;
-(IBAction)beaconSwitchChanged:(UISwitch *)sender;

-(IBAction)rssiChanged:(UISlider *)sender;
-(IBAction)minRequiredDistanceChanged:(UIStepper *)sender;

@end
