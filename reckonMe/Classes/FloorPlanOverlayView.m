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

#import "FloorPlanOverlayView.h"

@implementation FloorPlanOverlayView {
    
@private
    BOOL isBitmap;
    UIImage *mapImage;
    
    BOOL isPDF;
    CGPDFDocumentRef pdf;
    CGPDFPageRef page;
    
    CGRect mapRect;
}

- (id)initWithOverlay:(FloorPlanOverlay *)overlay {
    
    if (self = [super initWithOverlay:overlay]) {
        
        isPDF = NO;
        isBitmap = NO;
        
        NSString *filePath = overlay.floorPlanPath;
        if (filePath && ![filePath isEqualToString:@""]) {
            
            //PDF?
            if ([[filePath pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
                
                // Open the PDF document
                NSURL *pdfURL = [[NSURL alloc] initFileURLWithPath:filePath];
                pdf = CGPDFDocumentCreateWithURL((CFURLRef)pdfURL);
                [pdfURL release];
                
                if (pdf != NULL) {
                    
                    isPDF = YES;
                    
                    // Get the PDF Page that we will be drawing
                    page = CGPDFDocumentGetPage(pdf, 1);
                    CGPDFPageRetain(page);
                    
                    // determine the size of the PDF page
                    mapRect = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
                }
                
            //bitmap?
            } else {
                
                mapImage = [[UIImage alloc] initWithContentsOfFile:filePath];
                
                if (mapImage != nil) {
                    
                    isBitmap = YES;
                    
                    mapRect = CGRectMake(0,
                                         0,
                                         mapImage.size.width,
                                         mapImage.size.height);
                }
            }
        }
    }
    return self;
}

-(void)dealloc {
    
    if (isPDF) {
        
        CGPDFPageRelease(page);
        CGPDFDocumentRelease(pdf);
    }
    
    if (isBitmap) {
        
        [mapImage release];
    }
    [super dealloc];
}

-(void)drawMapRect:(MKMapRect)MKmapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
    
    MKMapRect overlayMapRect = [self.overlay boundingMapRect];
    CGRect overlayDrawRect = [self rectForMapRect:overlayMapRect];
    CGRect clipDrawRect = [self rectForMapRect:MKmapRect];
    
    //save the current drawing properties before we make changes to
    CGContextSaveGState(context);
    
    //clip the graphics context to part of the map that actually needs to be drawn to
    CGContextClipToRect(context, clipDrawRect);
    
    //turn the provided context upside down, to match the native origin of Quartz which is lower left.
    CGContextTranslateCTM(context, 0.0, overlayDrawRect.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    if (isPDF) {
        
        //make the PDFMediaBox (=mapRect) fit the overlayDrawRect by translating and scaling up
        CGContextTranslateCTM(context, overlayDrawRect.origin.x, overlayDrawRect.origin.y);
        CGContextScaleCTM(context, overlayDrawRect.size.width / mapRect.size.width, overlayDrawRect.size.height / mapRect.size.height);
        CGContextTranslateCTM(context, -mapRect.origin.x, -mapRect.origin.y);
        
        //set low quality settings to speed up rendering
		CGContextSetRenderingIntent(context, kCGRenderingIntentDefault);//color mapping 
        CGContextSetInterpolationQuality(context, kCGInterpolationNone);
        
        CGContextDrawPDFPage(context, page);
    }
    
    if (isBitmap) {
        
        CGContextDrawImage(context, overlayDrawRect, mapImage.CGImage);
    }
    
    //restore the drawing properties
    CGContextRestoreGState(context);
}

@end
