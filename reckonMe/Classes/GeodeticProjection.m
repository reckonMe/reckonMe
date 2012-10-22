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

#import "GeodeticProjection.h"
#import "proj_api.h"

NSString const *googleProjection = @"+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +no_defs";

@implementation GeodeticProjection


+ (GeodeticProjection *)sharedInstance
{
    static dispatch_once_t once;
    static GeodeticProjection *sharedSingleton;

    dispatch_once(&once, ^{
        
        sharedSingleton = [[GeodeticProjection alloc] init];
    });
    
    return sharedSingleton;
}


-(id)init {
    
    if (self = [super init]) {
        
        projection = pj_init_plus([googleProjection UTF8String]);
        
        if (projection == NULL) {
            
            NSLog(@"Error creating Proj4 projection.");
            [self release];
            
            return nil;
        }
    }
    return self;
}

-(void)dealloc {
    
    if (projection) {
        
        pj_free(projection);
    }
    
    [super dealloc];
}

+(ProjectedPoint)coordinatesToCartesian:(CLLocationCoordinate2D)coordinates {
    
    return [[self sharedInstance] coordinatesToCartesian:coordinates];
}

-(ProjectedPoint)coordinatesToCartesian:(CLLocationCoordinate2D)coordinates {

    projUV uv;
    uv.u = coordinates.longitude * DEG_TO_RAD;
    uv.v = coordinates.latitude * DEG_TO_RAD;
    
    projUV result = pj_fwd(uv, projection);
    
    ProjectedPoint result_point;
    result_point.easting = result.u;
    result_point.northing = result.v;

    return result_point;
}

+(CLLocationCoordinate2D)cartesianToCoordinates:(ProjectedPoint)cartesian {
    
    return [[self sharedInstance] cartesianToCoordinates:cartesian];
}

-(CLLocationCoordinate2D)cartesianToCoordinates:(ProjectedPoint)cartesian {

    projUV uv;
    uv.u = cartesian.easting;
    uv.v = cartesian.northing;

    projUV result = pj_inv(uv, projection);

    CLLocationCoordinate2D result_coordinate;
    result_coordinate.longitude = result.u * RAD_TO_DEG;
    result_coordinate.latitude = result.v * RAD_TO_DEG;

    return result_coordinate;

}


+(double)mercatorScaleForLatitude:(double)latitude {

    return 1 / cos(latitude * DEG_TO_RAD);
}


@end
