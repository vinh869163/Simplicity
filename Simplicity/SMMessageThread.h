//
//  SMMessageThread.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/14/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOIMAPMessage;
@class MCOIMAPSession;
@class SMMessage;

@interface SMMessageThread : NSObject

@property (readonly) uint64_t threadId;
@property (readonly) NSInteger messagesCount;
@property (readonly) Boolean unseen;
@property (readonly) Boolean flagged;
@property (readonly) Boolean hasAttachments;

- (id)initWithThreadId:(uint64_t)threadId;

- (SMMessage*)latestMessage;

- (NSArray*)messagesSortedByDate;
- (SMMessage*)getMessage:(uint32_t)uid;

- (void)updateIMAPMessage:(MCOIMAPMessage*)imapMessage remoteFolder:(NSString*)remoteFolder session:(MCOIMAPSession*)session;

// returns whether or not the update operation affected
- (Boolean)endUpdate:(Boolean)removeVanishedMessages;

- (void)cancelUpdate;

- (void)setMessageData:(NSData*)data uid:(uint32_t)uid;
- (BOOL)messageHasData:(uint32_t)uid;
- (void)updateThreadAttributesFromMessageUID:(uint32_t)uid;

@end
