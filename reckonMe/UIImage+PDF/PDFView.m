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

#import "PDFView.h"


@implementation PDFView

@synthesize resourceName = m_resourceName;
@synthesize resourceURL = m_resourceURL;


- (id)initWithFrame:(CGRect)frame 
{
    self = [super initWithFrame:frame];
	
    if (self) 
	{
        // Initialization code.
    }
    return self;
}


-(void)setResourceName:(NSString *)resourceName
{
	m_resourceName = resourceName;
	
    self.resourceURL = [ PDFView resourceURLForName: self.resourceName ];
}


-(void)setResourceURL:(NSURL *)resourceURL
{
    m_resourceURL = resourceURL;
    
    [ self setNeedsDisplay ];
}


+(CGRect) mediaRect:(NSString *)resourceName
{
    return [ PDFView mediaRectForURL:[ PDFView resourceURLForName: resourceName ]];
}


+(CGRect) mediaRectForURL:(NSString *)resourceURL
{
    CGRect rect = CGRectNull;
    
    if( resourceURL )
	{
		CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef) [NSURL URLWithString:resourceURL]);
		CGPDFPageRef page1 = CGPDFDocumentGetPage( pdf, 1 );
		
		rect = CGPDFPageGetBoxRect( page1, kCGPDFCropBox );
		
		CGPDFDocumentRelease( pdf );
	}
    
    return rect;
}


+(NSURL *)resourceURLForName:(NSString *)resourceName
{
    return ( resourceName ) ? [ NSURL fileURLWithPath:[[ NSBundle mainBundle ] pathForResource:resourceName ofType:nil ]] : nil;
}



/**/
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect 
{
    // Drawing code.
    if( self.resourceURL )
	//if( self.resourceName )
	{
		/* 
		 * Reference: http://www.cocoanetics.com/2010/06/rendering-pdf-is-easier-than-you-thought/
		 */
		CGContextRef ctx = UIGraphicsGetCurrentContext();
		
		[ self.backgroundColor set ];
		CGContextFillRect( ctx, rect );
		
		CGContextGetCTM( ctx );
		CGContextScaleCTM( ctx, 1, -1 );
		CGContextTranslateCTM( ctx, 0, -self.bounds.size.height );
		
        CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL( (CFURLRef) self.resourceURL );
		CGPDFPageRef page1 = CGPDFDocumentGetPage( pdf, 1 );
		
		CGRect mediaRect = CGPDFPageGetBoxRect( page1, kCGPDFCropBox );
		CGContextScaleCTM( ctx, rect.size.width / mediaRect.size.width, rect.size.height / mediaRect.size.height );
		CGContextTranslateCTM( ctx, -mediaRect.origin.x, -mediaRect.origin.y );
		
		CGContextDrawPDFPage( ctx, page1 );
		CGPDFDocumentRelease( pdf );
	}
}


- (void)dealloc 
{
    [super dealloc];
}


@end
