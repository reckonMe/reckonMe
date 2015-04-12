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

#import "SettingsViewController.h"
#import "Settings.h"
#import "UIImage+PDf.h"

const NSTimeInterval kAnimationDuration = 0.2;

@interface SettingsViewController ()

-(void)releaseSubviews;
-(void)userTappedBackground:(UITapGestureRecognizer *)sender;

@end

@implementation SettingsViewController {
    
    @private
    NSTimeInterval animationDuration;
}

@synthesize blurryBackground;
@synthesize stepLengthStepper, stepLengthLabel;
@synthesize satelliteImageSwitch, p2pExchangeSwitch, beaconSwitch, beaconLabel;
@synthesize rssiStepper, rssiLabel, rssiDescriptionLabel;
@synthesize minRequiredDistanceStepper, minRequiredDistanceLabel;
@synthesize delegate;

- (void)dealloc {
    
    self.delegate = nil;
    [self releaseSubviews];
    
    [super dealloc];
}

- (void)releaseSubviews {
    
    self.blurryBackground = nil;
    self.stepLengthStepper = nil;
    self.stepLengthLabel = nil;
    self.satelliteImageSwitch = nil;
    self.p2pExchangeSwitch = nil;
    self.beaconSwitch = nil;
    self.beaconLabel = nil;
    self.rssiStepper = nil;
    self.rssiLabel = nil;
    self.rssiDescriptionLabel = nil;
    self.minRequiredDistanceLabel = nil;
    self.minRequiredDistanceStepper = nil;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIVisualEffect *blurEffect;
    blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    self.blurryBackground = [[[UIVisualEffectView alloc] initWithEffect:blurEffect] autorelease];
    
    CGRect viewBounds = self.view.bounds;
    CGFloat originY = self.satelliteImageSwitch.frame.origin.y - 20;
    self.blurryBackground.frame = CGRectMake(viewBounds.origin.x,
                                             originY,
                                             viewBounds.size.width,
                                             viewBounds.size.height - originY);
    self.blurryBackground.autoresizingMask = (UIViewAutoresizingFlexibleWidth
                                            | UIViewAutoresizingFlexibleTopMargin);
    [self.view insertSubview:self.blurryBackground
                     atIndex:0];
    
    animationDuration = 0;
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(userTappedBackground:)];
    tapRecognizer.delegate = self;
    [self.view addGestureRecognizer:tapRecognizer];
    [tapRecognizer release];
    
    UISwipeGestureRecognizer *swipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(userSwipedDown:)];
    swipeRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    swipeRecognizer.delegate = self;
    [self.view addGestureRecognizer:swipeRecognizer];
    [swipeRecognizer release];
    
    self.stepLengthStepper.minimumValue = kMinStepLength;
    self.stepLengthStepper.maximumValue = kMaxStepLength;
    self.stepLengthStepper.stepValue = kStepLengthStepValue;
    self.stepLengthStepper.value = [Settings sharedInstance].stepLength;
    //update the label
    [self stepLengthChanged:self.stepLengthStepper];
    
    self.satelliteImageSwitch.on = [Settings sharedInstance].showSatelliteImagery;
    
    self.beaconSwitch.on = [Settings sharedInstance].beaconMode;
    //update the view
    [self beaconSwitchChanged:self.beaconSwitch];
    
    self.p2pExchangeSwitch.on = [Settings sharedInstance].exchangeEnabled;
    //update the view
    [self p2pExchangeChanged:self.p2pExchangeSwitch];
    
    self.minRequiredDistanceStepper.minimumValue = kMinDistBetweenMeetings;
    self.minRequiredDistanceStepper.maximumValue = kMaxDistBetweenMeetings;
    self.minRequiredDistanceStepper.stepValue = kDistBetweenMeetingsStepValue;
    self.minRequiredDistanceStepper.value = [Settings sharedInstance].distanceBetweenConsecutiveMeetings;
    //update the label
    [self minRequiredDistanceChanged:self.minRequiredDistanceStepper];
    
    CGFloat minMaxImageHeight = 20;
    self.rssiStepper.minimumValue = -100;
    self.rssiStepper.maximumValue = -20;
    self.rssiStepper.minimumValueImage = [UIImage imageWithPDFNamed:@"lowSignal.pdf"
                                                           atHeight:minMaxImageHeight];
    self.rssiStepper.maximumValueImage = [UIImage imageWithPDFNamed:@"fullSignal.pdf"
                                                           atHeight:minMaxImageHeight];
    self.rssiStepper.value = [Settings sharedInstance].rssi;
    //update the label
    [self rssiChanged:self.rssiStepper];
    
    animationDuration = kAnimationDuration;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    [self releaseSubviews];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(IBAction)stepLengthChanged:(UIStepper *)sender {
    
    [Settings sharedInstance].stepLength = sender.value;
    self.stepLengthLabel.text = [NSString stringWithFormat:@"Mean Step Length: %1.2f m", [Settings sharedInstance].stepLength];
}

-(IBAction)satelliteImageSwitchChanged:(UISwitch *)sender {
    
    [Settings sharedInstance].showSatelliteImagery = sender.isOn;
}

-(IBAction)p2pExchangeChanged:(UISwitch *)sender {

    [Settings sharedInstance].exchangeEnabled = sender.isOn;
    
    CGAffineTransform moveDetailControls;
    
    if ([Settings sharedInstance].exchangeEnabled) {
        
        moveDetailControls = CGAffineTransformIdentity;

    } else {
        
        //move controls downwards from beaconLabel out of view
        moveDetailControls = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height 
                                                                 - self.beaconLabel.frame.origin.y);
    }
    
    [UIView animateWithDuration:animationDuration
                     animations:^(void) {
                         
                         self.beaconLabel.transform = moveDetailControls;
                         self.beaconSwitch.transform = moveDetailControls;
                         
                         if (!self.beaconSwitch.isOn) {
                             
                             self.rssiLabel.transform = moveDetailControls;
                             self.rssiStepper.transform = moveDetailControls;
                             self.rssiDescriptionLabel.transform = moveDetailControls;
                             self.minRequiredDistanceStepper.transform = moveDetailControls;
                             self.minRequiredDistanceLabel.transform = moveDetailControls;
                             self.stepLengthLabel.transform = moveDetailControls;
                             self.stepLengthStepper.transform = moveDetailControls;
                         }
                     }];
    
}

-(IBAction)beaconSwitchChanged:(UISwitch *)sender {
    
    [Settings sharedInstance].beaconMode = sender.isOn;
    
    CGAffineTransform moveDetailControls;
    
    if ([Settings sharedInstance].beaconMode) {
        
        //move controls downwards from rssiLabel out of view
        moveDetailControls = CGAffineTransformMakeTranslation(0, self.view.bounds.size.height 
                                                              - self.stepLengthLabel.frame.origin.y);
        
    } else {
        
        moveDetailControls = CGAffineTransformIdentity;
    }
    
    [UIView animateWithDuration:animationDuration
                     animations:^(void) {
                         
                         self.rssiLabel.transform = moveDetailControls;
                         self.rssiStepper.transform = moveDetailControls;
                         self.rssiDescriptionLabel.transform = moveDetailControls;
                         self.minRequiredDistanceStepper.transform = moveDetailControls;
                         self.minRequiredDistanceLabel.transform = moveDetailControls;
                         self.stepLengthLabel.transform = moveDetailControls;
                         self.stepLengthStepper.transform = moveDetailControls;
                     }];
    
}

-(IBAction)rssiChanged:(UISlider *)sender {
    
    [Settings sharedInstance].rssi = sender.value;
    self.rssiLabel.text = [NSString stringWithFormat:@"RSSI > %ld db", (long)[Settings sharedInstance].rssi];
}

-(IBAction)minRequiredDistanceChanged:(UIStepper *)sender {
    
    [Settings sharedInstance].distanceBetweenConsecutiveMeetings = sender.value;
    self.minRequiredDistanceLabel.text = [NSString stringWithFormat:@"Exchange Every: %ld m", (long)[Settings sharedInstance].distanceBetweenConsecutiveMeetings];
}

-(void)userTappedBackground:(UITapGestureRecognizer *)sender {
    
    CGPoint touch = [sender locationInView:self.view];
    
    //above or left of controls?
    if (touch.y <= self.blurryBackground.frame.origin.y) {
        
        [self.delegate dismissSettingsViewController:self];
    }
}

-(void)userSwipedDown:(UISwipeGestureRecognizer *)sender {
    
    [self.delegate dismissSettingsViewController:self];
}

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    
    //prevent touches in the controls from being recognized
    return (touch.view == self.view) || (touch.view == self.blurryBackground);
}

@end
