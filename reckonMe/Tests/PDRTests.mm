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

#import "PDRTests.h"
#import "FakeCMDeviceMotion.h"

@interface PDRTests () 

- (void)sendSensorDataToPDR:(FakeCMDeviceMotion *) dm;
- (void)runTestPathWithName: (NSString *) testName;

@end

@implementation PDRTests


- (void)sendSensorDataToPDR:(FakeCMDeviceMotion *) dm {
    
    [pdr didReceiveDeviceMotion:(CMDeviceMotion*)dm timestamp:dm.timestamp];   
    static int counter = 0;
    counter++;
    //if (counter % 100 == 1)
    //NSLog(@"%d", counter);
}

- (void)sendExchangeToPDR {
    
    AbsoluteLocationEntry *peerLocation = [[AbsoluteLocationEntry alloc] initWithTimestamp:[[NSDate date] timeIntervalSince1970]
                                                                              eastingDelta:4
                                                                             northingDelta:1
                                                                                    origin:pdr.positionForExchange.absolutePosition
                                                                                 Deviation:3];
    [pdr didReceivePosition:peerLocation
                     ofPeer:@"foobar"
                 isRealName:NO];
    [peerLocation release];
}

- (void)sendInPocketToVC:(NSNumber *)isInPocket {
    
    [firstViewController devicesPocketStatusChanged:[isInPocket boolValue]];
}

- (void)runTestPathWithName:(NSString *) testName {
    
    double delayOffset = 8;
    [firstViewController performSelector:@selector(testPDR)
                              withObject:nil
                              afterDelay:delayOffset];
    delayOffset += 3.5;
    [self performSelector:@selector(sendInPocketToVC:)
               withObject:@YES
               afterDelay:delayOffset];
    
    NSString *gyroFilename = [NSString stringWithFormat:@"%@-GYRO", testName];
    NSString *accFilename = [NSString stringWithFormat:@"%@-ACC", testName];
    
    NSString *gyroPath = [[NSBundle mainBundle] pathForResource:gyroFilename ofType:@"txt" inDirectory:nil]; 
    NSString *accPath = [[NSBundle mainBundle] pathForResource:accFilename ofType:@"txt" inDirectory:nil]; 
    
    NSLog(@"\n\n****\n%@ %@\n*******\n\n",gyroPath, accPath);
    NSLog(@"\n\n****\n%@ %@\n*******\n\n",gyroFilename, accFilename);
    
    double timestamp, t2, t3, t4, t5, t6, t7, t8, t13;
    CMQuaternion q;
    CMAcceleration acc;
    NSMutableArray *quaternionArr = [NSMutableArray array];
    NSMutableArray *accArr = [NSMutableArray array];
    NSMutableArray *timestampArr = [NSMutableArray array];
    
    FILE *gyroFile = fopen([gyroPath cStringUsingEncoding: [NSString defaultCStringEncoding]], "r");    
    if (gyroFile) 
        while (fscanf(gyroFile, "%lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf %lf", 
                      &timestamp, &t2, &t3, &t4, &t5, &t6, &t7, &t8, &q.x, &q.y, &q.z, &q.w, &t13, &t13, &t13, &t13, &t13) != EOF) 
        {            
            NSValue *quaternionWrapper = [NSValue value:&q withObjCType:@encode(CMQuaternion)];
            [quaternionArr addObject:quaternionWrapper];
            NSValue *timestampWrapper = [NSValue value:&timestamp withObjCType:@encode(double)];
            [timestampArr addObject:timestampWrapper];
        }
    fclose(gyroFile);
    
    FILE *accFile = fopen([accPath cStringUsingEncoding: [NSString defaultCStringEncoding]], "r");  
    if (gyroFile) 
        while (fscanf(accFile, "%lf %lf %lf %lf %lf %lf", &timestamp, &t2, &acc.x, &acc.y, &acc.z, &t6) != EOF) 
        {            
            NSValue *arrWrapper = [NSValue value:&acc withObjCType:@encode(CMAcceleration)];
            [accArr addObject:arrWrapper];
        }
   
    NSLog(@"%d\n%d", [quaternionArr count], [accArr count]);
    
    fclose(accFile);
    
    STAssertTrue([quaternionArr count] == [accArr count], @"Different sizes of GYRO and ACC raw data.");
    
    for (int i = 0; i < [quaternionArr count]; ++i) 
    {
        // decode structs from objects
        [[quaternionArr objectAtIndex:i] getValue:&q];
        [[accArr objectAtIndex:i] getValue:&acc];
        [[timestampArr objectAtIndex:i] getValue:&timestamp];
        double delay = (i+1.)/75.;
        
        FakeCMDeviceMotion *dm = [[FakeCMDeviceMotion alloc] initWithQuaternion:q
                                                               userAcceleration:acc
                                                                      timestamp:timestamp];
        
        double totalDelay = delayOffset + delay;
        [self performSelector:@selector(sendSensorDataToPDR:)
                   withObject:dm
                   afterDelay:totalDelay];
        
        if (i == 1500) {
            
            [self performSelector:@selector(sendInPocketToVC:)
                       withObject:@NO
                       afterDelay:totalDelay];
        }
        //perform heading correction by hand
        if (i == 2300) {
            
            [self performSelector:@selector(sendInPocketToVC:)
                       withObject:@YES
                       afterDelay:totalDelay];
        }
        
        if (i == 4150) {
            
            [self performSelector:@selector(sendExchangeToPDR)
                       withObject:nil
                       afterDelay:totalDelay];
        }
        
        // dm is retained by performSelector, we can release it
        [dm release];  
    }
  
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:10000];
    
    [[NSRunLoop currentRunLoop] runUntilDate:timeoutDate];
    
    STAssertTrue(YES, @"YES");
}


- (void)setUp {
    
    /* The setUp method is called automatically for each test-case method (methods whose name starts with 'test').
     */

    [super setUp];

    appDelegate = (PDRAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // dirty pointer to FirstViewController
    firstViewController = (FirstViewController *) appDelegate.window.rootViewController;
    firstViewController.testing = YES;
    
    pdr = [PDRController sharedInstance];
    STAssertTrue(pdr.pdrRunning == NO, @"PDR should not be running during setUp");
}


- (void)tearDown {
    
    /* The tearDown method is called automatically after each test-case method (methods whose name starts with 'test').
     */
    [super tearDown];
    [pdr stopPDRsession];
}


-(void)test0References {
    
    STAssertNotNil(appDelegate, @"Cannot find the application delegate");
    STAssertTrue([firstViewController isMemberOfClass:[FirstViewController class]], @"bad FirstViewController reference");
}


//- (void)testPath01 {
//    
//    [self runTestPathWithName:@"test04"];
//}

- (void)testPath02 {
    
    [self runTestPathWithName:@"test05"];
}


@end
