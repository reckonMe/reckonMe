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

#import "CompassAndGPS.h"
#import "AlertSoundPlayer.h"

@interface CompassAndGPS ()

- (void)actuallyStopGPS;
- (void)actuallyStopCompass;

@end

@implementation CompassAndGPS

@synthesize isCompassActive;
@synthesize isGPSactive;

static CompassAndGPS *sharedSingleton;

+(CompassAndGPS *)sharedInstance {
    
    return sharedSingleton;
}

#pragma mark -
#pragma mark initialization methods

//Is called by the runtime in a thread-safe manner exactly once, before the first use of the class.
//This makes it the ideal place to set up the singleton.
+ (void)initialize
{
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[CompassAndGPS alloc] init];
    }
}

- (id) init {
	
    self = [super init];
	
    if (self != nil) {
        
        //By the time of writing (March 2011), the availability of a compass 
        //seams to be the only reliable source for determining
        //whether a GPS-chip (and not just WiFi triangulation as in iPods)
        //is available or not.
        isAvailable = [CLLocationManager headingAvailable];
        isGPSactive = NO;
        isCompassActive = NO;
        
        shouldRestartCompassIfListenersAvailable = NO;
        shouldRestartGPSIfListenersAvailable = NO;
        
        if (isAvailable) {
            
            locationManager = [[CLLocationManager alloc] init];
            
            //ask for authorization on iOS>=8
            if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
                
                [locationManager requestWhenInUseAuthorization];
            }
            
            locationManager.delegate = self; // Tells the location manager to send updates to this object
            
            // set accuracy to the maximum level
            locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            
            // we want to be notified about all movements
            locationManager.distanceFilter = kCLDistanceFilterNone;
            
            // we want to be notified about all heading changes
            locationManager.headingFilter = kCLHeadingFilterNone;

        }
	}
	return self;
}

-(void)dealloc {
    
    if (locationManager) {
     
        [self stop];
        locationManager.delegate = nil;
        [locationManager release];
    }
    
    [super dealloc];
}

#pragma mark -
#pragma mark sensor methods

//starts both
- (void) actuallyStart {
    
    if (isAvailable) {
        
        if (shouldRestartIfListenersAvailable) {
            
            if (shouldRestartGPSIfListenersAvailable) {
                
                [self startGPS];
                NSLog(@"(Re)started GPS because a listener has been added.");
            }
            if (shouldRestartCompassIfListenersAvailable) {
                
                [self startCompass];
                NSLog(@"(Re)started Compass because a listener has been added.");
            }
            
            shouldRestartCompassIfListenersAvailable = NO;
            shouldRestartGPSIfListenersAvailable = NO;
            
        } else {
            
            [self startGPS];
            [self startCompass];
        }
    }
}

//stops both
- (void) actuallyStop {
    
    if (isAvailable) {
        
        if (shouldRestartIfListenersAvailable) {
            
            shouldRestartGPSIfListenersAvailable = isGPSactive;
            shouldRestartCompassIfListenersAvailable = isCompassActive;
            
        } else {
            
            shouldRestartGPSIfListenersAvailable = NO;
            shouldRestartCompassIfListenersAvailable = NO;
        
        }
        
        [self actuallyStopGPS];
        [self actuallyStopCompass];
    
    }
}

- (void) startGPS {
    
    if (isAvailable && !isGPSactive) {
        
        dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
            
            if ([listeners count] > 0) {//start GPS immediately
                
                shouldRestartGPSIfListenersAvailable = NO;
                isGPSactive = YES;
                isActive = YES;
                
                [locationManager startUpdatingLocation];
                
            } else {//later
                
                shouldRestartIfListenersAvailable = YES;
                shouldRestartGPSIfListenersAvailable = YES;
            }
        dispatch_semaphore_signal(listenersSemaphore);
    }
}

- (void) stopGPS {
    
    shouldRestartGPSIfListenersAvailable = NO;
    shouldRestartIfListenersAvailable = shouldRestartCompassIfListenersAvailable || shouldRestartGPSIfListenersAvailable;
    
    [self actuallyStopGPS];
}

- (void) actuallyStopGPS {
    
    if (isAvailable && isGPSactive) {
        
        isGPSactive = NO;
        isActive = (isGPSactive || isCompassActive);
        
        [locationManager stopUpdatingLocation];
        
        if (!shouldRestartIfListenersAvailable) shouldRestartGPSIfListenersAvailable = NO;
    }
}


- (void) startCompass {
    
    // do not start compass
//    return;
    
    if (isAvailable && !isCompassActive) {
        
        dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
            
            if ([listeners count] > 0) {//start compass immediately
                
                shouldRestartCompassIfListenersAvailable = NO;
                
                isCompassActive = YES;
                isActive = YES;
                
                [locationManager startUpdatingHeading];
                
            } else {//later
                
                shouldRestartIfListenersAvailable = YES;
                shouldRestartCompassIfListenersAvailable = YES;
            }
            
        dispatch_semaphore_signal(listenersSemaphore);
    }
}

- (void) stopCompass {
    
    shouldRestartCompassIfListenersAvailable = NO;
    shouldRestartIfListenersAvailable = shouldRestartCompassIfListenersAvailable || shouldRestartGPSIfListenersAvailable;
    
    [self actuallyStopCompass];
}

- (void) actuallyStopCompass {
    
    if (isAvailable && isCompassActive) {
        
        isCompassActive = NO;
        isActive = (isCompassActive || isGPSactive);
        
        [locationManager stopUpdatingHeading];
        
        if (!shouldRestartIfListenersAvailable) shouldRestartCompassIfListenersAvailable = NO;
    }
}


#pragma mark -
#pragma mark CLLManagerDelegate methods

// Called when the location is updated
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
	
    int label = 0;
    NSTimeInterval timestamp = [newLocation.timestamp timeIntervalSince1970];
	id<SensorListener> listener;
    
    /* 
     * We shouldn't need the semaphore here, as this method is called from the main thread
     * like the adding/removing listeners methods in our AbstractSensor superclass.
     */
    //dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
    
    for (listener in listeners) {
        
        [listener didReceiveGPSvalueWithLongitude:newLocation.coordinate.longitude
                                         latitude:newLocation.coordinate.latitude
                                         altitude:newLocation.altitude
                                            speed:newLocation.speed
                                           course:newLocation.course
                               horizontalAccuracy:newLocation.horizontalAccuracy 
                                 verticalAccuracy:newLocation.verticalAccuracy
                                        timestamp:timestamp 
                                            label:label];
    }
    
    //dispatch_semaphore_signal(listenersSemaphore);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
    
    NSTimeInterval timestamp = [newHeading.timestamp timeIntervalSince1970];
	id<SensorListener> listener;
    
    /* 
     * We shouldn't need the semaphore here, as this method is called from the main thread
     * like the adding/removing listeners methods in our AbstractSensor superclass.
     */
    //dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
        
    for (listener in listeners) {
        
        [listener didReceiveCompassValueWithMagneticHeading:newHeading.magneticHeading
                                                trueHeading:newHeading.trueHeading
                                            headingAccuracy:newHeading.headingAccuracy
                                                          X:newHeading.x
                                                          Y:newHeading.y
                                                          Z:newHeading.z
                                                  timestamp:timestamp
                                                      label:0];
    }
    
    //dispatch_semaphore_signal(listenersSemaphore);
}


// Called when there is an error getting the location
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	
	if ([error domain] == kCLErrorDomain) {
		
		// We handle CoreLocation-related errors here
		switch ([error code]) {
                
			case kCLErrorDenied:
				// user denied location-access
				NSLog(@"GPS-Error: The user doesn't want to be located!");
				break;
				
			case kCLErrorLocationUnknown:
				// location can't be retrieved
				NSLog(@"GPS-Error: The location can't be retrieved!");
				break;
				
                
			default:
				// default error behaviour
				NSLog(@"GPS-Error: default error");
				break;
		}
	} else {
		// We handle all non-CoreLocation errors here
		NSLog(@"Error: non GPS-related error occured during GPS Operation");
        
	}
	
}

- (BOOL)locationManagerShouldDisplayHeadingCalibration:(CLLocationManager *)manager {
    
    NSLog(@"Compass calibration required!");
    
    // Since we want to display the calibration window whenever necessary, we return YES
	return YES;
}

@end
