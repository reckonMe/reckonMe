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

#import "PacketEncoderDecoder.h"

@implementation PacketEncoderDecoder

+(NSMutableData *)startNewPacketOfType:(PacketType)type withPayloadLength:(int)length {
    
    header_t header = (header_t) type;
    
    NSMutableData *newPacket = [NSMutableData dataWithCapacity:length + sizeof(header_t)];
    [newPacket appendBytes:&header length:sizeof(header)];
    
    return newPacket;
}

//MARK: - value encoding

+(void)encodeDouble:(double)value into:(NSMutableData *)data {
    
    CFSwappedFloat64 swappedValue = CFConvertDoubleHostToSwapped(value);
    [data appendBytes:&swappedValue length:sizeof(CFSwappedFloat64)];
}

/*
 * Returns the decoded value AND increases *offset for the next potential
 * call of a decode... method.
 */
+(double)decodeDoubleFrom:(NSData *)data atOffset:(int *)offset {
    
    NSRange range = {*offset, sizeof(CFSwappedFloat64)};
    *offset += range.length;
    
    CFSwappedFloat64 swappedValue;
    [data getBytes:&swappedValue range:range];
    
    return CFConvertDoubleSwappedToHost(swappedValue);
}

+(void)encodeInt32:(uint32_t)value into:(NSMutableData *)data {
    
    uint32_t swappedValue = CFSwapInt32HostToLittle(value);
    [data appendBytes:&swappedValue length:sizeof(uint32_t)];
}

+(uint32_t)decodeInt32From:(NSData *)data atOffset:(int *)offset {
    
    NSRange range = {*offset, sizeof(uint32_t)};
    *offset += range.length;
    
    uint32_t swappedValue;
    [data getBytes:&swappedValue range:range];
    
    return CFSwapInt32LittleToHost(swappedValue);
}

@end
