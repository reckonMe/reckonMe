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

#import "UIImage+PDF.h"


@implementation  UIImage( PDF )


#pragma mark - Convenience methods

+(UIImage *) imageOrPDFNamed:(NSString *)resourceName
{
    if([[ resourceName pathExtension ] isEqualToString: @"pdf" ])
    {
        return [ UIImage originalSizeImageWithPDFNamed:resourceName ];
    }
    else
    {
        return [ UIImage imageNamed:resourceName ];
    }
}


+(UIImage *) imageOrPDFWithContentsOfFile:(NSString *)path
{
    if([[ path pathExtension ] isEqualToString: @"pdf" ])
    {
        return [ UIImage originalSizeImageWithPDFURL:[ NSURL fileURLWithPath:path ]];
    }
    else
    {
        return [ UIImage imageWithContentsOfFile:path ];
    }
}


#pragma mark - Cacheing

+(NSString *)cacheFilenameForURL:(NSURL *)resourceURL atSize:(CGSize)size atScaleFactor:(CGFloat)scaleFactor
{
    NSString *cacheFilename = nil;
    
#ifdef UIIMAGE_PDF_CACHEING
    
    NSFileManager *fileManager = [ NSFileManager defaultManager ];
    
    NSString *filePath = [ resourceURL path ];
    
    //NSLog( @"filePath: %@", filePath );
    
    NSDictionary *fileAttributes = [ fileManager attributesOfItemAtPath:filePath error:NULL ];
    
    //NSLog( @"fileAttributes: %@", fileAttributes );
    
    NSString *cacheRoot = [ NSString stringWithFormat:@"%@ - %@ - %@ - %@", [ filePath lastPathComponent ], [ fileAttributes objectForKey:NSFileSize ], [ fileAttributes objectForKey:NSFileModificationDate ], NSStringFromCGSize(CGSizeMake( size.width * scaleFactor, size.height * scaleFactor ))];
    
    //NSLog( @"cacheRoot: %@", cacheRoot );
    
    NSString *MD5 = [ cacheRoot MD5 ];
    
    //NSLog( @"MD5: %@", MD5 );
    
    NSString *cachesDirectory = [ NSSearchPathForDirectoriesInDomains( NSCachesDirectory, NSUserDomainMask, YES ) objectAtIndex:0 ];
    
    NSString *cacheDirectory = [ NSString stringWithFormat:@"%@/__PDF_CACHE__", cachesDirectory ];
    
    //NSLog( @"cacheDirectory: %@", cacheDirectory );
    
    [ fileManager createDirectoryAtPath:cacheDirectory withIntermediateDirectories:YES attributes:nil error:NULL ];
    
    cacheFilename = [ NSString stringWithFormat:@"%@/%@.png", cacheDirectory, MD5 ];
    
    //NSLog( @"cacheFilename: %@", cacheFilename );
    
#endif
    
    return cacheFilename;
}



#pragma mark - Resource name

+(UIImage *) imageWithPDFNamed:(NSString *)resourceName atSize:(CGSize)size
{
    return [ self imageWithPDFURL:[ PDFView resourceURLForName:resourceName ] atSize:size ];
}


+(UIImage *) imageWithPDFNamed:(NSString *)resourceName atWidth:(CGFloat)width
{
    return [ self imageWithPDFURL:[ PDFView resourceURLForName:resourceName ] atWidth:width ];
}


+(UIImage *) imageWithPDFNamed:(NSString *)resourceName atHeight:(CGFloat)height
{
    return [ self imageWithPDFURL:[ PDFView resourceURLForName:resourceName ] atHeight:height ];
}


+(UIImage *) originalSizeImageWithPDFNamed:(NSString *)resourceName
{
    return [ self originalSizeImageWithPDFURL:[ PDFView resourceURLForName:resourceName ]];
}



#pragma mark - Resource URLs

+(UIImage *) imageWithPDFURL:(NSURL *)URL atSize:(CGSize)size
{
    UIImage *pdfImage = nil;
    
    PDFView *pdfView = [[ PDFView alloc ] initWithFrame:CGRectMake( 0, 0, size.width, size.height ) ];
    
    //NSFileManager *fileManager = [ NSFileManager defaultManager ];
    NSString *cacheFilename = [ self cacheFilenameForURL:URL atSize:size atScaleFactor:pdfView.contentScaleFactor ];
    
    if([[ NSFileManager defaultManager ] fileExistsAtPath:cacheFilename ])
    {
        //NSLog( @"Cache hit" );
        
        pdfImage = [ UIImage imageWithCGImage:[[ UIImage imageWithContentsOfFile:cacheFilename ] CGImage ] scale:pdfView.contentScaleFactor orientation:UIImageOrientationUp ];
    }
    else 
    {
        //NSLog( @"Cache miss" );
    
        pdfView.backgroundColor = [ UIColor clearColor ];
        pdfView.resourceURL = URL;
        
        pdfImage = [ pdfView image ];
        
        if( cacheFilename )
        {
            [ UIImagePNGRepresentation( pdfImage ) writeToFile:cacheFilename atomically:NO ];
        }
    }
    
    [ pdfView release ];
    
	return pdfImage;
}


+(UIImage *) imageWithPDFURL:(NSURL *)URL atWidth:(CGFloat)width
{
    CGRect mediaRect = [ PDFView mediaRectForURL:URL ];
    CGFloat aspectRatio = mediaRect.size.width / mediaRect.size.height;
    
    CGSize size = CGSizeMake( width, ceilf( width / aspectRatio ));
    
    return [ UIImage imageWithPDFURL:URL atSize:size ];
}


+(UIImage *) imageWithPDFURL:(NSURL *)URL atHeight:(CGFloat)height
{
    CGRect mediaRect = [ PDFView mediaRectForURL:URL ];
    CGFloat aspectRatio = mediaRect.size.width / mediaRect.size.height;
    
    CGSize size = CGSizeMake( ceilf( height * aspectRatio ), height );
    
    return [ UIImage imageWithPDFURL:URL atSize:size ];
}


+(UIImage *) originalSizeImageWithPDFURL:(NSURL *)URL
{
    CGRect mediaRect = [ PDFView mediaRectForURL:URL ];
    
    return [ UIImage imageWithPDFURL:URL atSize:mediaRect.size ];
}



@end
