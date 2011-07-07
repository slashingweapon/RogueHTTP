//
//  SocketServer.h
//  RogueHTTP
//
//  Created by Courtney Holmes on 7/6/11.
//  Copyright 2011 Unemployed. All rights reserved.
//
//	This is a singleton socket server that listens on an OS-assigned port on all available addresses,
//	and then dispatches accepted connections.
//

#import <Foundation/Foundation.h>


@interface SocketServer : NSObject {
	NSNumber *port;
	NSNumber *hits;
}

@property (retain) NSNumber *port;
@property (retain) NSNumber *hits;

+ (SocketServer*) singleton;

@end
