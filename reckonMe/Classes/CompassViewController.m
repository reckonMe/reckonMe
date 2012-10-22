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

#import "CompassViewController.h"
#import "UIImage+PDF.h"

@interface CompassViewController ()

@property(nonatomic, retain) CAGradientLayer *gradientLayer;
@property(nonatomic, retain) UISwipeGestureRecognizer *gestureRecognizer;

-(void)userSwiped:(UISwipeGestureRecognizer *)sender;

@end


@implementation CompassViewController {
    
    @private
    double lastTimestampCriteriaFulfilled;
}

@synthesize degreesText, deviationText, compassImageView, gradientLayer, statusText, gestureRecognizer;
@synthesize delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        lastTimestampCriteriaFulfilled = -1;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    // Initialize the gradient layer
    self.gradientLayer = [[[CAGradientLayer alloc] init] autorelease];
    
    // Set its bounds to be the same of its parent
    CGRect bounds = self.view.bounds;
    self.gradientLayer.bounds = bounds;
    
    // Center the layer inside the parent layer
    self.gradientLayer.position = CGPointMake(bounds.size.width / 2,
                                              bounds.size.height / 2);
    
    // Insert the layer at position zero to make sure the 
    // text of the button is not obscured
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];
    
    self.compassImageView.image = [UIImage imageWithPDFNamed:@"compass.pdf"
                                                     atWidth:self.compassImageView.bounds.size.width];
    
    self.gestureRecognizer = [[[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                       action:@selector(userSwiped:)] autorelease];
    self.gestureRecognizer.numberOfTouchesRequired = 1;//fingers
    self.gestureRecognizer.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:self.gestureRecognizer];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.compassImageView = nil;
    self.deviationText = nil;
    self.degreesText = nil;
    self.gradientLayer = nil;
    self.statusText = nil;
    self.gestureRecognizer = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque 
                                                animated:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

-(void)didReceiveCompassValueWithTrueHeading:(double)trueHeading 
                             headingAccuracy:(double)headingAccuracy 
                                   timestamp:(double)timestamp {
    
    //rotate the icon
    #define DEG_TO_RAD	.0174532925199432958
    self.compassImageView.transform = CGAffineTransformMakeRotation(DEG_TO_RAD * -trueHeading);
    
    //update the text
    self.degreesText.text = [NSString stringWithFormat:@"%.0f°", trueHeading];
    self.deviationText.text = [NSString stringWithFormat:@"Accuracy: %.0f°", headingAccuracy];

    //update the background color
    float accuracy = fabsf(trueHeading - 180) / 180.0;
    float logAccuracy = 1 - log2f(2 - accuracy);
    UIColor *centerColor = [UIColor colorWithRed:1 - logAccuracy
                                          green:logAccuracy
                                           blue:0
                                          alpha:1];
    
    self.gradientLayer.colors = [NSArray arrayWithObjects:
                                 (id) [[UIColor blackColor] CGColor],
                                 (id) [centerColor CGColor], 
                                 (id) [[UIColor blackColor] CGColor],
                                 nil];
    
    //heading north?
    if (   (trueHeading >= (360 - kDegreeThreshold)
        || trueHeading <= kDegreeThreshold)
        && trueHeading != -1.0)//in rare cases, the heading remains wrongly at -1
    {
        
        //accurate measurement?
        if (   headingAccuracy <= kDeviationThreshold
            && headingAccuracy >= 0) {
            
            if (lastTimestampCriteriaFulfilled < 0) {
                
                lastTimestampCriteriaFulfilled = timestamp;
                
            }
            
            double finishTime = lastTimestampCriteriaFulfilled + kDismissalInterval;

            //update the status string
            double countdown = fabs(ceil(finishTime - timestamp));
            self.statusText.text = [NSString stringWithFormat:waitingStatusFormat, countdown];
            
            //success?
            if (finishTime <= timestamp) {
                
                [self.delegate compassPointingNorthwards];
                
                lastTimestampCriteriaFulfilled = -1;
                
            }
            
        //not accurate
        } else {
            
            self.statusText.text = calibrateStatus;
            lastTimestampCriteriaFulfilled = -1;
        }
        
    //not northwards
    } else {
        
        self.statusText.text = defaultStatus;
        lastTimestampCriteriaFulfilled = -1;
    }
#ifdef SOUND_TESTS
[self.delegate compassPointingNorthwards];
#endif
}

-(void)userSwiped:(UISwipeGestureRecognizer *)sender {
    
    [self.delegate userAbortedWaitingForHeading];
}

@end
