//
//  SocketServer.m
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//
//	Thanks to Big Nerd Ranch for the singleton code.
//

#import "SocketServer.h"
#import "Rogue.h"
#import <CoreFoundation/CFSocket.h>
#import <CFNetwork/CFSocketStream.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

static void handleListen(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info) {
	if (callbackType == kCFSocketAcceptCallBack) {
		// record a hit first thing, because that's what we really care about ... HITS!
		SocketServer *server = [SocketServer singleton];
		NSNumber *hits = server.hits;
		server.hits = [NSNumber numberWithInteger:[hits integerValue]+1];

		CFSocketNativeHandle nativeSocket = *(CFSocketNativeHandle *)data;
		Rogue *handler = [[[Rogue alloc] initWithNativeSocket:nativeSocket] autorelease];
		if (!handler)
			close(nativeSocket);
	}	
}

static SocketServer *globalServer = nil;

@implementation SocketServer

@synthesize port;
@synthesize hits;

+ (SocketServer*) singleton {
	if (!globalServer) {
		globalServer = [[super allocWithZone:NULL] init];
	}
	return globalServer;
}

+ (id) allocWithZone:(NSZone*)zone {
	return [self singleton];
}

- (id) init {
	
	if (globalServer)
		return globalServer;
	
	self = [super init];
	if (self) {
		self.port = [NSNumber numberWithInteger:0];
		self.hits = [NSNumber numberWithInteger:0];

		CFRunLoopRef mainLoop = CFRunLoopGetMain();
		
		CFSocketRef socket = CFSocketCreate (
											 kCFAllocatorDefault,
											 PF_INET6,
											 SOCK_STREAM,
											 IPPROTO_TCP,
											 kCFSocketAcceptCallBack,
											 handleListen,
											 NULL
											 );
		
		int isOn = 1;
		setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, &isOn, sizeof(isOn));
		
		/*	Bind the socket to all local addresses, on whatever port the system gives us.
		 
			It's a little sad, actually.  CoreFoundation has all these interesting APIs, but then you're forced to
			bit-twiddle the sockaddr_in6 structure like an animal.  But then again, socket programming is never
			really clean, is it?
		 */
		struct sockaddr_in6 addr;
		memset(&addr, 0, sizeof(addr));
		addr.sin6_len = sizeof(addr);
		addr.sin6_family = AF_INET6;
		addr.sin6_port = 0;
		addr.sin6_flowinfo = 0;
		addr.sin6_addr = in6addr_any;
		NSData *addressData = [NSData dataWithBytes:&addr length:sizeof(addr)];
		
		if (CFSocketSetAddress(socket, (CFDataRef)addressData) != kCFSocketSuccess) {
			NSLog(@"Failed to set socket address");
		} else {			
			// now that the binding was successful, we get the port number 
			// -- we will need it for the NSNetService
			NSData *actualAddress = [(NSData *)CFSocketCopyAddress(socket) autorelease];
			memcpy(&addr, [actualAddress bytes], [actualAddress length]);
			self.port = [NSNumber numberWithInteger:ntohs(addr.sin6_port)];
			
			CFRunLoopSourceRef loopSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, socket, 0);
			CFRunLoopAddSource(mainLoop, loopSource, kCFRunLoopCommonModes);
			CFRelease(loopSource);
		}
		
	
	}
	return self;
}

@end
