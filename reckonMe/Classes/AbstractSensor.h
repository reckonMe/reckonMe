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
#import "PDRExchange.h"


@interface AbstractSensor : NSObject {
	
    /* Using NSMutableSet is a naive implementation for managing the listeners.
     * Performance could be gained by fetching the methods addresses from the runtime
     * and making a C-function call instead of Objective-C messaging.
     */
	NSMutableSet *listeners;
    //a mutex to make sure "listeners" isn't changed while being enumerated
    dispatch_semaphore_t listenersSemaphore;
    
	NSDate *beginningOfEpoch;
    BOOL isAvailable;
    BOOL isActive;

    //describes: 1. if the sensor has been stopped because there are no listeners
    //           2. why actuallyStart/actuallyStop are called
    BOOL shouldRestartIfListenersAvailable;
}

@property(nonatomic,readonly) BOOL isActive;
@property(nonatomic,readonly) BOOL isAvailable;

-(void)addListener:(id<SensorListener>)listener;
-(void)removeListener:(id<SensorListener>)listener;
-(void)removeAllListeners;

-(NSTimeInterval)getTimestamp;

//to be implemented by subclasses:
//raises an exception if called
- (void) actuallyStart;
- (void) actuallyStop;

//to be called by the users of sensors
-(void)start;
-(void)stop;

@end
