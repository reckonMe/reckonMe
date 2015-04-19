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
#import "PDRExchange.h"
#import "PDRController.h"
#import "OutdoorMapView.h"
#import "PantsPocketDetector.h"
#import "SettingsViewController.h"

@interface FirstViewController : UIViewController <UIActionSheetDelegate, PDRView, PantsPocketDetectorDelegate, MapViewDelegate, SettingsViewControllerDelegate>
{
    
    PDRController *pdr;
    PantsPocketDetector *pocketDetector;
    
    NSMutableArray *path;//the path since the last start of PDR, necessary to preserve the state between memory warnings
    
    BOOL mapFollowsPosition;
    BOOL mapFollowsHeading;
    BOOL pdrOn;
    
    double yawOffset;
    double lastYaw;
    double lastHeading;
}

@property (nonatomic) BOOL pdrOn;
@property (nonatomic) BOOL testing;

-(void)testPDR;

@end
