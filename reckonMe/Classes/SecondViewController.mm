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

#import "SecondViewController.h"
#import "Settings.h"

@implementation SecondViewController

@synthesize logView;

@synthesize delegate;
@synthesize slider;

+ (SecondViewController *)sharedInstance
{
    static dispatch_once_t once;
    static SecondViewController *sharedSingleton;
    
    dispatch_once(&once, ^{
        
        sharedSingleton = [[SecondViewController alloc] initWithCoder:nil];
    });
    
    return sharedSingleton;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    
    if (self = [super initWithCoder:aDecoder]) {
        
        log = [[NSMutableString alloc] initWithCapacity:(kMaxCharactersInLogView * 1.1)];
        timeFormatter = [[NSDateFormatter alloc] init];
        timeFormatter.dateFormat = @"HH':'mm':'ss";
        
        self.delegate = nil;
    }
    return self;
}

- (void)dealloc {
    
    self.logView = nil;
    self.slider = nil;
    [log release];
    [timeFormatter release];
    
    [super dealloc];
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logView.text = log;    
    /*
    ANSlider * anSlider = [[ANSlider alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 95, 320, 95)];
	[anSlider startAnimating:self];
	[self.view addSubview:[anSlider autorelease]];
     */
}

- (void)viewDidUnload {
    
    [super viewDidUnload];
    
    self.slider = nil;
    self.logView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackOpaque
                                                animated:animated];
    
    self.logView.scrollEnabled = [Settings sharedInstance].beaconMode;
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    [[UIScreen mainScreen] setBrightness:0.3];
}

- (void)viewDidDisappear:(BOOL)animated {
    
    [super viewWillDisappear:animated];
    [[UIScreen mainScreen] setBrightness:1.0];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)addToLogFromMainThread:(NSString *)message {
        
        [log appendFormat:@"[%@] %@\n", [timeFormatter stringFromDate:[NSDate date]], message];
        
        int tooLargeBy = [log length] - kMaxCharactersInLogView;
        if (tooLargeBy > 0) {
            
            NSRange throwAway = NSMakeRange(0, tooLargeBy);
            [log deleteCharactersInRange:throwAway];
        }
        
        self.logView.text = log;
        [self.logView scrollRangeToVisible:NSMakeRange(log.length - 11, 11)];
}

- (void)addToLog:(NSString *)message {
    
    if ([NSThread isMainThread]) {
        
        [self addToLogFromMainThread:message];
    
    } else {

        [self performSelectorOnMainThread:@selector(addToLogFromMainThread:)
                               withObject:message
                            waitUntilDone:NO];
    }
}


- (void)clearLog {
    
    [log setString:@""];
}

-(void)userUnlockedSlider:(UnlockSlider *)sender {
    
    [self.delegate userUnlockedScreen];
}

@end
