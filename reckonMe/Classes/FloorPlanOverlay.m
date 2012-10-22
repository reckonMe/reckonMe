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

#import "FloorPlanOverlay.h"

@implementation FloorPlanOverlay

@synthesize coordinate, boundingMapRect, floorPlanPath;

-(id)initWithCenter:(CLLocationCoordinate2D)center planPath:(NSString *)filePath scalePixelsPerMeter:(float)pixelsPerMeter {
    
    if (self = [super init]) {
        
        floorPlanPath = [filePath retain];
        
        //try to open the image to get its size and deallocate it afterwards
        CGRect mapRect = CGRectZero;
        
        if (filePath && ![filePath isEqualToString:@""]) {
            
            //PDF?
            if ([[filePath pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
                
                // Open the PDF document
                NSURL *pdfURL = [[NSURL alloc] initFileURLWithPath:filePath];
                CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)pdfURL);
                [pdfURL release];
                
                if (pdf) {
                    
                    // Get the PDF Page that we will be drawing
                    CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
                    
                    if (page) {
                        
                        // determine the size of the PDF page
                        mapRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
                    }
                    CGPDFDocumentRelease(pdf);
                }
                
                //bitmap?
            } else {
                
                UIImage *mapImage = [[UIImage alloc] initWithContentsOfFile:filePath];
                
                if (mapImage) {
                    
                    mapRect = CGRectMake(0,
                                         0,
                                         mapImage.size.width,
                                         mapImage.size.height);
                    [mapImage release];
                }
            }
        }
        
        double projectionScale = MKMapPointsPerMeterAtLatitude(center.latitude);
        MKMapPoint centerInMapPoints = MKMapPointForCoordinate(center);
        
        double widthInMapPoints = (mapRect.size.width / pixelsPerMeter) * projectionScale;
        double heightInMapPoints = (mapRect.size.height / pixelsPerMeter) * projectionScale;
        
        boundingMapRect = MKMapRectMake(centerInMapPoints.x - widthInMapPoints / 2,
                                        centerInMapPoints.y - heightInMapPoints / 2,
                                        widthInMapPoints,
                                        heightInMapPoints);
        
        coordinate = center;
    }    
    return self;
}

-(void)dealloc {
    
    [floorPlanPath release];
    
    [super dealloc];
}

@end
