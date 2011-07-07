//
//  Rogue.h
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CFNetwork/CFHTTPMessage.h>


@interface Rogue : NSObject {
	CFSocketRef socket;
	CFHTTPMessageRef request;
	CFHTTPMessageRef response;
	NSFileManager *fileManager;
}

- (id)initWithNativeSocket:(CFSocketNativeHandle)nativeSocket;
- (void)socket:(CFSocketRef)socket hasData:(NSData*)data;
- (void)socket:(CFSocketRef)socket isWritable:(BOOL)writable;
- (void)socket:(CFSocketRef)socket connectedWithError:(NSInteger)error;
- (void)processRequest;

@end
