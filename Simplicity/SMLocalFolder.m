//
//  SMLocalFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageStorage.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOpMoveMessages.h"
#import "SMOpSetMessageFlags.h"
#import "SMMessageListController.h"
#import "SMMessageThread.h"
#import "SMMessage.h"
#import "SMMailbox.h"
#import "SMDatabase.h"
#import "SMFolder.h"
#import "SMLocalFolderRegistry.h"
#import "SMLocalFolder.h"

static const NSUInteger DEFAULT_MAX_MESSAGES_PER_FOLDER = 100;
static const NSUInteger INCREASE_MESSAGES_PER_FOLDER = 50;
static const NSUInteger MESSAGE_HEADERS_TO_FETCH_AT_ONCE = 20;
static const NSUInteger OPERATION_UPDATE_TIMEOUT_SEC = 30;

static const MCOIMAPMessagesRequestKind messageHeadersRequestKind = (MCOIMAPMessagesRequestKind)(
	MCOIMAPMessagesRequestKindUid |
	MCOIMAPMessagesRequestKindFlags |
	MCOIMAPMessagesRequestKindHeaders |
	MCOIMAPMessagesRequestKindStructure |
	MCOIMAPMessagesRequestKindInternalDate |
	MCOIMAPMessagesRequestKindFullHeaders |
	MCOIMAPMessagesRequestKindHeaderSubject |
	MCOIMAPMessagesRequestKindGmailLabels |
	MCOIMAPMessagesRequestKindGmailMessageID |
	MCOIMAPMessagesRequestKindGmailThreadID |
	MCOIMAPMessagesRequestKindExtraHeaders |
	MCOIMAPMessagesRequestKindSize
);

@implementation SMLocalFolder {
	MCOIMAPFolderInfoOperation *_folderInfoOp;
	MCOIMAPFetchMessagesOperation *_fetchMessageHeadersOp;
	NSMutableDictionary *_fetchMessageBodyOps;
	NSMutableDictionary *_searchMessageThreadsOps;
	NSMutableDictionary *_fetchMessageThreadsHeadersOps;
	NSMutableDictionary *_fetchedMessageHeaders;
	NSMutableArray *_fetchedMessageHeadersFromAllMail;
	MCOIndexSet *_selectedMessageUIDsToLoad;
	uint64_t _totalMemory;
}

- (id)initWithLocalFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName syncWithRemoteFolder:(Boolean)syncWithRemoteFolder {
	self = [ super init ];
	
	if(self) {
		_localName = localFolderName;
		_remoteFolderName = remoteFolderName;
		_maxMessagesPerThisFolder = DEFAULT_MAX_MESSAGES_PER_FOLDER;
		_totalMessagesCount = 0;
		_messageHeadersFetched = 0;
		_fetchedMessageHeaders = [NSMutableDictionary new];
		_fetchedMessageHeadersFromAllMail = [NSMutableArray new];
		_fetchMessageBodyOps = [NSMutableDictionary new];
		_fetchMessageThreadsHeadersOps = [NSMutableDictionary new];
		_searchMessageThreadsOps = [NSMutableDictionary new];
		_syncedWithRemoteFolder = syncWithRemoteFolder;
		_selectedMessageUIDsToLoad = nil;
		_totalMemory = 0;
	}
	
	return self;
}

- (void)rescheduleMessageListUpdate {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageListController] scheduleMessageListUpdate:NO];
}

- (void)cancelScheduledMessageListUpdate {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageListController] cancelScheduledMessageListUpdate];
}

- (void)cancelScheduledUpdateTimeout {
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateTimeout) object:nil];
}

- (void)rescheduleUpdateTimeout {
	[self cancelScheduledUpdateTimeout];

	[self performSelector:@selector(updateTimeout) withObject:nil afterDelay:OPERATION_UPDATE_TIMEOUT_SEC];
}

- (void)updateTimeout {
	SM_LOG_WARNING(@"operation timeout");
    
	[self stopMessagesLoading:NO];
	[self startLocalFolderSync];
	[self rescheduleUpdateTimeout];
}

- (void)startLocalFolderSync {
	[self rescheduleMessageListUpdate];

	if(_folderInfoOp != nil || _fetchMessageHeadersOp != nil || _searchMessageThreadsOps.count > 0 || _fetchMessageThreadsHeadersOps.count > 0) {
		SM_LOG_WARNING(@"previous op is still in progress for folder %@", _localName);
		return;
	}

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] localFolderRegistry] keepFoldersMemoryLimit];

	if(!_syncedWithRemoteFolder) {
		[self loadSelectedMessagesInternal];
		return;
	}
	
	_messageHeadersFetched = 0;
	
	[[[appDelegate model] messageStorage] startUpdate:_localName];
	
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	
	NSAssert(session, @"session lost");

	// TODO: handle session reopening/uids validation	
	
	_folderInfoOp = [session folderInfoOperation:_localName];
	_folderInfoOp.urgent = YES;

	[_folderInfoOp start:^(NSError *error, MCOIMAPFolderInfo *info) {
		_folderInfoOp = nil;

		if(error == nil) {
			SM_LOG_DEBUG(@"UIDNEXT: %u, UIDVALIDITY: %u, Messages count %u", info.uidNext, info.uidValidity, info.messageCount);
			
			_totalMessagesCount = [info messageCount];
			
			[self syncFetchMessageHeaders];
		} else {
			SM_LOG_ERROR(@"Error fetching folder info: %@", error);
		}
	}];
}

- (void)increaseLocalFolderCapacity {
	if(![self folderUpdateIsInProgress]) {
		if(_messageHeadersFetched + INCREASE_MESSAGES_PER_FOLDER < _totalMessagesCount)
			_maxMessagesPerThisFolder += INCREASE_MESSAGES_PER_FOLDER;
	}
}

- (Boolean)folderUpdateIsInProgress {
	return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)fetchMessageBodies {
	SM_LOG_DEBUG(@"fetching message bodies for folder '%@' (%lu messages in this folder, %lu messages in all mail)", _remoteFolderName, _fetchedMessageHeaders.count, _fetchedMessageHeadersFromAllMail.count);

	[self recalculateTotalMemorySize];
	
	NSUInteger fetchCount = 0;
	
	for(NSNumber *gmailMessageId in _fetchedMessageHeaders) {
		SM_LOG_DEBUG(@"fetched message id %@", gmailMessageId);

		MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];

		if([self fetchMessageBody:message.uid remoteFolder:_remoteFolderName threadId:message.gmailThreadID urgent:NO])
			fetchCount++;
	}

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];

	for(MCOIMAPMessage *message in _fetchedMessageHeadersFromAllMail) {
		SM_LOG_DEBUG(@"[all mail] fetched message id %llu", message.gmailMessageID);

		if([self fetchMessageBody:message.uid remoteFolder:allMailFolder threadId:message.gmailThreadID urgent:NO])
			fetchCount++;
	}

	SM_LOG_DEBUG(@"fetching %lu message bodies", fetchCount);

	[_fetchedMessageHeaders removeAllObjects];
	[_fetchedMessageHeadersFromAllMail removeAllObjects];
}

- (BOOL)fetchMessageBody:(uint32_t)uid remoteFolder:(NSString*)remoteFolderName threadId:(uint64_t)threadId urgent:(BOOL)urgent {
	SM_LOG_DEBUG(@"uid %u, remote folder %@, threadId %llu, urgent %s", uid, remoteFolderName, threadId, urgent? "YES" : "NO");

	SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];

	if([[[appDelegate model] messageStorage] messageHasData:uid localFolder:_localName threadId:threadId])
		return NO;
	
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	
	NSAssert(session, @"session is nil");
	
	MCOIMAPFetchContentOperation *op = [session fetchMessageOperationWithFolder:remoteFolderName uid:uid urgent:urgent];
	
	[_fetchMessageBodyOps setObject:op forKey:[NSNumber numberWithUnsignedInt:uid]];
	
	void (^opBlock)(NSError *error, NSData * data) = nil;

	opBlock = ^(NSError * error, NSData * data) {
		SM_LOG_DEBUG(@"msg uid %u", uid);
		
		if (error != nil && [error code] != MCOErrorNone) {
			SM_LOG_ERROR(@"Error downloading message body for uid %u, remote folder %@", uid, remoteFolderName);

			MCOIMAPFetchContentOperation *op = [_fetchMessageBodyOps objectForKey:[NSNumber numberWithUnsignedInt:uid]];

			// restart this message body fetch to prevent data loss
			// on connectivity/server problems
			[op start:opBlock];

			return;
		}
		
		[_fetchMessageBodyOps removeObjectForKey:[NSNumber numberWithUnsignedInt:uid]];
		
		NSAssert(data != nil, @"data != nil");
		
		[[[appDelegate model] messageStorage] setMessageData:data uid:uid localFolder:_localName threadId:threadId];
		
        // TODO: Filter out cases of search, and anything similar?
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        [[[appDelegate model] database] putMessageBodyToDB:uid data:data];
        
		_totalMemory += [data length];
		
		NSDictionary *messageInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithUnsignedInteger:uid], [NSNumber numberWithUnsignedLongLong:threadId], nil] forKeys:[NSArray arrayWithObjects:@"UID", @"ThreadId", nil]];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageBodyFetched" object:nil userInfo:messageInfo];
	};
	
	// TODO: don't fetch if body is already being fetched (non-urgently!)
	// TODO: if urgent fetch is requested, cancel the non-urgent fetch
	[op start:opBlock];
	
	return YES;
}

- (void)syncFetchMessageThreadsHeaders {
	SM_LOG_DEBUG(@"fetching %lu threads", _fetchedMessageHeaders.count);

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];
	
	NSAssert(_searchMessageThreadsOps.count == 0, @"_searchMessageThreadsOps not empty");

	if(allMailFolder == nil) {
		SM_LOG_ERROR(@"no all mail folder!");

		[self finishHeadersSync];
		return;
	}
		
	if(_fetchedMessageHeaders.count == 0) {
		[self finishHeadersSync];
		return;
	}

	NSMutableSet *threadIds = [[NSMutableSet alloc] init];

	for(NSNumber *gmailMessageId in _fetchedMessageHeaders) {
		MCOIMAPMessage *message = [_fetchedMessageHeaders objectForKey:gmailMessageId];
		NSNumber *threadId = [NSNumber numberWithUnsignedLongLong:message.gmailThreadID];
		
		if([threadIds containsObject:threadId])
			continue;
		
		MCOIMAPSearchExpression *expression = [MCOIMAPSearchExpression searchGmailThreadID:message.gmailThreadID];
		MCOIMAPSearchOperation *op = [session searchExpressionOperationWithFolder:allMailFolder expression:expression];
		
		op.urgent = YES;
		
		[op start:^(NSError *error, MCOIndexSet *searchResults) {
			if([_searchMessageThreadsOps objectForKey:threadId] != op)
				return;

			[self rescheduleUpdateTimeout];
			
			[_searchMessageThreadsOps removeObjectForKey:threadId];
			
			if(error == nil) {
				SM_LOG_DEBUG(@"Search for message '%@' thread %llu finished (%lu searches left)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);

				if(searchResults.count > 0) {
                    SM_LOG_DEBUG(@"%u messages found in '%@', threadId %@", [searchResults count], allMailFolder, threadId);
					
					[self fetchMessageThreadsHeaders:threadId uids:searchResults];
				}
			} else {
				SM_LOG_ERROR(@"search in '%@' for thread %@ failed, error %@", allMailFolder, threadId, error);

				[self markMessageThreadAsUpdated:threadId];
			}
		}];
		
		[_searchMessageThreadsOps setObject:op forKey:threadId];

		SM_LOG_DEBUG(@"Search for message '%@' thread %llu started (%lu searches active)", message.header.subject, message.gmailThreadID, _searchMessageThreadsOps.count);
	}
}

- (void)markMessageThreadAsUpdated:(NSNumber*)threadId {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];

	[storage markMessageThreadAsUpdated:[threadId unsignedLongLongValue] localFolder:_localName];
}

- (void)updateMessages:(NSArray*)imapMessages remoteFolder:(NSString*)remoteFolderName {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];
	
	SMMessageStorageUpdateResult updateResult = [storage updateIMAPMessages:imapMessages localFolder:_localName remoteFolder:remoteFolderName session:session];
	
    (void)updateResult;

	// TODO: send result
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MessagesUpdated" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_localName, @"LocalFolderName", nil]];
}

- (void)fetchMessageThreadsHeaders:(NSNumber*)threadId uids:(MCOIndexSet*)messageUIDs {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	SMMailbox *mailbox = [[appDelegate model] mailbox];
	NSString *allMailFolder = [mailbox.allMailFolder fullName];

	MCOIMAPFetchMessagesOperation *op = [session fetchMessagesOperationWithFolder:allMailFolder requestKind:messageHeadersRequestKind uids:messageUIDs];
	
	[op start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		if([_fetchMessageThreadsHeadersOps objectForKey:threadId] != op)
			return;
		
		[self rescheduleUpdateTimeout];

		[_fetchMessageThreadsHeadersOps removeObjectForKey:threadId];
		
		if(error == nil) {
			NSMutableArray *filteredMessages = [NSMutableArray array];
			for(MCOIMAPMessage *m in messages) {
				if([_fetchedMessageHeaders objectForKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]] == nil) {
					[_fetchedMessageHeadersFromAllMail addObject:m];
					[filteredMessages addObject:m];
				}
			}

			[self updateMessages:filteredMessages remoteFolder:allMailFolder];
		} else {
			SM_LOG_ERROR(@"Error fetching message headers for thread %@: %@", threadId, error);
			
			[self markMessageThreadAsUpdated:threadId];
		}
		
		if(_searchMessageThreadsOps.count == 0 && _fetchMessageThreadsHeadersOps.count == 0)
			[self finishHeadersSync];
	}];

	[_fetchMessageThreadsHeadersOps setObject:op forKey:threadId];

	SM_LOG_DEBUG(@"Fetching headers for thread %@ started (%lu fetches active)", threadId, _fetchMessageThreadsHeadersOps.count);
}

- (void)finishHeadersSync {
	[self cancelScheduledUpdateTimeout];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorageUpdateResult updateResult = [[[appDelegate model] messageStorage] endUpdate:_localName removeFolder:_remoteFolderName removeVanishedMessages:YES];
	Boolean hasUpdates = (updateResult != SMMesssageStorageUpdateResultNone);
	
	[self fetchMessageBodies];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_localName, @"LocalFolderName", [NSNumber numberWithBool:hasUpdates], @"HasUpdates", nil]];
}

- (void)syncFetchMessageHeaders {
	NSAssert(_messageHeadersFetched <= _totalMessagesCount, @"invalid messageHeadersFetched");
	
	BOOL finishFetch = YES;
	
	if(_totalMessagesCount == _messageHeadersFetched) {
		SM_LOG_DEBUG(@"all %llu message headers fetched, stopping", _totalMessagesCount);
	} else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
		SM_LOG_DEBUG(@"fetched %llu message headers, stopping", _messageHeadersFetched);
	} else {
		finishFetch = NO;
	}
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];

	if(finishFetch) {
		[_fetchMessageHeadersOp cancel];
		_fetchMessageHeadersOp = nil;
		
		[self syncFetchMessageThreadsHeaders];
		
		return;
	}
	
	const uint64_t restOfMessages = _totalMessagesCount - _messageHeadersFetched;
	const uint64_t numberOfMessagesToFetch = MIN(restOfMessages, MESSAGE_HEADERS_TO_FETCH_AT_ONCE) - 1;
	const uint64_t fetchMessagesFromIndex = restOfMessages - numberOfMessagesToFetch;
	
	MCOIndexSet *regionToFetch = [MCOIndexSet indexSetWithRange:MCORangeMake(fetchMessagesFromIndex, numberOfMessagesToFetch)];
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	
	// TODO: handle session reopening/uids validation
	
	NSAssert(session, @"session lost");

	NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
	
	_fetchMessageHeadersOp = [session fetchMessagesByNumberOperationWithFolder:_localName requestKind:messageHeadersRequestKind numbers:regionToFetch];
	
	_fetchMessageHeadersOp.urgent = YES;
	
	[_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		[self rescheduleUpdateTimeout];

		_fetchMessageHeadersOp = nil;
		
		if(error == nil) {
            for(MCOIMAPMessage *m in messages) {
				[_fetchedMessageHeaders setObject:m forKey:[NSNumber numberWithUnsignedLongLong:m.gmailMessageID]];
            }
            
			_messageHeadersFetched += [messages count];

			[self updateMessages:messages remoteFolder:_remoteFolderName];
			
			[self syncFetchMessageHeaders];
		} else {
			SM_LOG_ERROR(@"Error downloading messages list: %@", error);
		}
	}];	
}

- (void)loadSelectedMessages:(MCOIndexSet*)messageUIDs {
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] localFolderRegistry] keepFoldersMemoryLimit];

	_messageHeadersFetched = 0;

	[[[appDelegate model] messageStorage] startUpdate:_localName];
	
	_selectedMessageUIDsToLoad = messageUIDs;

	_totalMessagesCount = _selectedMessageUIDsToLoad.count;
	
	[self loadSelectedMessagesInternal];
}

- (void)loadSelectedMessagesInternal {
	if(_remoteFolderName == nil) {
		SM_LOG_WARNING(@"remote folder is not set");
		return;
	}
	
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	MCOIMAPSession *session = [[appDelegate model] imapSession];
	
	NSAssert(session, @"session lost");

	NSAssert(_selectedMessageUIDsToLoad != nil, @"bad message uids to load array");
	
	BOOL finishFetch = YES;
	
	if(_totalMessagesCount == _messageHeadersFetched) {
		SM_LOG_DEBUG(@"all %llu message headers fetched, stopping", _totalMessagesCount);
	} else if(_messageHeadersFetched >= _maxMessagesPerThisFolder) {
		SM_LOG_DEBUG(@"fetched %llu message headers, stopping", _messageHeadersFetched);
	} else if(_selectedMessageUIDsToLoad.count > 0) {
		finishFetch = NO;
	}
	
	if(finishFetch) {
		[[[appDelegate model] messageStorage] endUpdate:_localName removeFolder:nil removeVanishedMessages:NO];
		
		[self fetchMessageBodies];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:@"MessageHeadersSyncFinished" object:nil userInfo:[NSDictionary dictionaryWithObject:_localName forKey:@"LocalFolderName"]];

		return;
	}
	
	MCOIndexSet *const messageUIDsToLoadNow = [MCOIndexSet indexSet];
	MCORange *const ranges = [_selectedMessageUIDsToLoad allRanges];
	
	for(unsigned int i = [_selectedMessageUIDsToLoad rangesCount]; i > 0; i--) {
		const MCORange currentRange = ranges[i-1];
		const uint64_t len = MCORangeRightBound(currentRange) - MCORangeLeftBound(currentRange) + 1;
		const uint64_t maxCountToLoad = MESSAGE_HEADERS_TO_FETCH_AT_ONCE - messageUIDsToLoadNow.count;
		
		if(len < maxCountToLoad) {
			[messageUIDsToLoadNow addRange:currentRange];
		} else {
			// note: "- 1" is because zero length means one element range
			const MCORange range = MCORangeMake(MCORangeRightBound(currentRange) - maxCountToLoad + 1, maxCountToLoad - 1);
			
			[messageUIDsToLoadNow addRange:range];
			
			break;
		}
	}
	
	SM_LOG_DEBUG(@"loading %u of %u search results...", messageUIDsToLoadNow.count, _selectedMessageUIDsToLoad.count);
	
	NSAssert(_fetchMessageHeadersOp == nil, @"previous search op not cleared");
	
	_fetchMessageHeadersOp = [session fetchMessagesOperationWithFolder:_remoteFolderName requestKind:messageHeadersRequestKind uids:messageUIDsToLoadNow];
	
	_fetchMessageHeadersOp.urgent = YES;

	[_fetchMessageHeadersOp start:^(NSError *error, NSArray *messages, MCOIndexSet *vanishedMessages) {
		_fetchMessageHeadersOp = nil;
		
		if(error == nil) {
			SM_LOG_DEBUG(@"loaded %lu message headers...", messages.count);

			[_selectedMessageUIDsToLoad removeIndexSet:messageUIDsToLoadNow];
			
			_messageHeadersFetched += [messages count];
			
			[self updateMessages:messages remoteFolder:_remoteFolderName];
			
			[self loadSelectedMessagesInternal];
		} else {
			SM_LOG_ERROR(@"Error downloading search results: %@", error);
		}
	}];
}

- (Boolean)messageHeadersAreBeingLoaded {
	return _folderInfoOp != nil || _fetchMessageHeadersOp != nil;
}

- (void)stopMessageHeadersLoading {
	[self cancelScheduledUpdateTimeout];

	[_fetchedMessageHeaders removeAllObjects];
	[_fetchedMessageHeadersFromAllMail removeAllObjects];
	
	[_folderInfoOp cancel];
	_folderInfoOp = nil;
	
	[_fetchMessageHeadersOp cancel];
	_fetchMessageHeadersOp = nil;
	
	for(NSNumber *threadId in _searchMessageThreadsOps) {
		MCOIMAPBaseOperation *op = [_searchMessageThreadsOps objectForKey:threadId];
		[op cancel];
	}
	[_searchMessageThreadsOps removeAllObjects];
	
	for(NSNumber *threadId in _fetchMessageThreadsHeadersOps) {
		MCOIMAPBaseOperation *op = [_fetchMessageThreadsHeadersOps objectForKey:threadId];
		[op cancel];
	}
	[_fetchMessageThreadsHeadersOps removeAllObjects];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];
	
	[storage cancelUpdate:_localName];
}

- (void)stopMessagesLoading:(Boolean)stopBodiesLoading {
	[self stopMessageHeadersLoading];

	if(stopBodiesLoading) {
		for(NSNumber *uid in _fetchMessageBodyOps)
			[[_fetchMessageBodyOps objectForKey:uid] cancel];
		
		[_fetchMessageBodyOps removeAllObjects];
	}
}

- (void)clear {
	[self stopMessagesLoading:YES];

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageStorage] removeLocalFolder:_localName];
}

#pragma mark Messages manipulation

- (void)setMessageUnseen:(SMMessage*)message unseen:(Boolean)unseen {
    if(message.unseen == unseen)
        return;
    
    // set the local message flags
    message.unseen = unseen;

    // enqueue the remote folder operation
    SMOpSetMessageFlags *op = [[SMOpSetMessageFlags alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName kind:(unseen? MCOIMAPStoreFlagsRequestKindRemove : MCOIMAPStoreFlagsRequestKindAdd) flags:MCOMessageFlagSeen];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
}

- (void)setMessageFlagged:(SMMessage*)message flagged:(Boolean)flagged {
    if(message.flagged == flagged)
        return;
    
    // set the local message flags
    message.flagged = flagged;
    
    // enqueue the remote folder operation
    SMOpSetMessageFlags *op = [[SMOpSetMessageFlags alloc] initWithUids:[MCOIndexSet indexSetWithIndex:message.uid] remoteFolderName:_remoteFolderName kind:(flagged? MCOIMAPStoreFlagsRequestKindAdd : MCOIMAPStoreFlagsRequestKindRemove) flags:MCOMessageFlagFlagged];
    
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
}

#pragma mark Messages movement to other remote folders

- (void)moveMessageThreads:(NSArray*)messageThreads toRemoteFolder:(NSString*)destRemoteFolderName {
    // Stop current message loading process, except bodies (because bodies can belong to
    // messages from other folders - TODO: is that logical?).
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
	[self stopMessagesLoading:NO];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
	[self cancelScheduledMessageListUpdate];

    // Remove the deleted message threads from the message storage.
	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	[[[appDelegate model] messageStorage] deleteMessageThreads:messageThreads fromLocalFolder:_localName];
	
    // Now, we have to cancel message bodies loading for the deleted messages.
	MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSet];
	for(SMMessageThread *thread in messageThreads) {
		NSArray *messages = [thread messagesSortedByDate];
		
        // Iterate messages for each deleted message thread.
		for(SMMessage *message in messages) {
            // Note that we choose only messages that belong to the current folder.
            // If a message doesn't belong to the folder, it's already in another folder
            // and hence has been shown in this message thread because of its thread id.
            // So leave it alone (skip it).
			if([message.remoteFolder isEqualToString:_remoteFolderName]) {
                // Keep the message for later; we'll have to actually move it remotely.
				[messagesToMoveUids addIndex:message.uid];

                // Cancel message body fetching.
				NSNumber *uidNum = [NSNumber numberWithUnsignedInt:message.uid];
				MCOIMAPFetchContentOperation *bodyFetchOp = [_fetchMessageBodyOps objectForKey:uidNum];
                
                if(bodyFetchOp) {
                    [bodyFetchOp cancel];
                    [_fetchMessageBodyOps removeObjectForKey:uidNum];
                }
			}
		}
	}
	
    NSAssert(messagesToMoveUids.count != 0, @"no messages to move");

    // Now, delete these messages from the local database as well.
    MCORange *const ranges = [messagesToMoveUids allRanges];
    
    for(unsigned int i = 0; i < messagesToMoveUids.rangesCount; i++) {
        const MCORange range = ranges[i];

        if(MCORangeLeftBound(range) >= UINT32_MAX || MCORangeRightBound(range) >= UINT32_MAX) {
            SM_LOG_FATAL(@"UID range is out of bounds: left %llu, right %llu", MCORangeLeftBound(range), MCORangeRightBound(range));
            abort();
        }
        
        const uint32_t firstUid = (uint32_t)MCORangeLeftBound(range);
        const uint32_t lastUid = (uint32_t)MCORangeRightBound(range);
        
        for(uint32_t uid = firstUid; uid <= lastUid; uid++) {
            SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
            [[[appDelegate model] database] removeMessageFromDBFolder:uid folder:_remoteFolderName];
        }
    }
    
    // After the local storage is cleared and there is no bodies loading,
    // actually move the messages on the server.
    SMOpMoveMessages *op = [[SMOpMoveMessages alloc] initWithUids:messagesToMoveUids srcRemoteFolderName:_remoteFolderName dstRemoteFolderName:destRemoteFolderName];

    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
}

- (Boolean)moveMessage:(uint32_t)uid toRemoteFolder:(NSString*)destRemoteFolderName {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    NSNumber *threadIdNum = [[[appDelegate model] messageStorage] messageThreadByMessageUID:uid];

    const uint64_t threadId = (threadIdNum != nil? [threadIdNum unsignedLongLongValue] : 0);
    const Boolean useThreadId = (threadIdNum != nil);

    return [self moveMessage:uid threadId:threadId useThreadId:useThreadId toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId toRemoteFolder:(NSString*)destRemoteFolderName {
    return [self moveMessage:uid threadId:threadId useThreadId:YES toRemoteFolder:destRemoteFolderName];
}

- (Boolean)moveMessage:(uint32_t)uid threadId:(uint64_t)threadId useThreadId:(Boolean)useThreadId toRemoteFolder:(NSString*)destRemoteFolderName {
    NSAssert(![_remoteFolderName isEqualToString:destRemoteFolderName], @"src and dest remove folders are the same %@", _remoteFolderName);

    // Stop current message loading process, except bodies (because bodies can belong to
    // messages from other folders - TODO: is that logical?).
    // TODO: maybe there's a nicer way (mark moved messages, skip them after headers are loaded...)
    [self stopMessagesLoading:NO];
    
    // Cancel scheduled update. It will be restored after message movement is finished.
    [self cancelScheduledMessageListUpdate];

    // Remove the deleted message from the current folder in the message storage.
    // This is necessary to immediately reflect the visual change.
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    Boolean needUpdateMessageList = NO;
    
    if(useThreadId) {
        needUpdateMessageList = [[[appDelegate model] messageStorage] deleteMessageFromStorage:uid threadId:threadId localFolder:_localName];
    }
    
    // Now, we have to cancel message bodies loading for the deleted messages.
    MCOIndexSet *messagesToMoveUids = [MCOIndexSet indexSetWithIndex:uid];
    
    // Cancel message body fetching.
    NSNumber *uidNum = [NSNumber numberWithUnsignedInt:uid];
    MCOIMAPFetchContentOperation *bodyFetchOp = [_fetchMessageBodyOps objectForKey:uidNum];
    if(bodyFetchOp) {
        [bodyFetchOp cancel];
        [_fetchMessageBodyOps removeObjectForKey:uidNum];
    }

    // Delete the message from the local database.
    [[[appDelegate model] database] removeMessageFromDBFolder:uid folder:_remoteFolderName];

    // After the local storage is cleared and there is no bodies loading,
    // actually move the messages on the server.
    SMOpMoveMessages *op = [[SMOpMoveMessages alloc] initWithUids:messagesToMoveUids srcRemoteFolderName:_remoteFolderName dstRemoteFolderName:destRemoteFolderName];
    
    [[[appDelegate appController] operationExecutor] enqueueOperation:op];
    
    return needUpdateMessageList;
}

#pragma mark Memory management

- (void)reclaimMemory:(uint64_t)memoryToReclaimKb {
	if(memoryToReclaimKb == 0)
		return;

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];
	
	uint64_t reclaimedMemory = 0;
	NSUInteger reclaimedMessagesCount = 0;
	Boolean stop = NO;

	NSUInteger threadsCount = [storage messageThreadsCountInLocalFolder:_localName];
	for(NSUInteger i = threadsCount; !stop && i > 0; i--) {
		SMMessageThread *thread = [storage messageThreadAtIndexByDate:(i-1) localFolder:_localName];
		NSArray *messages = [thread messagesSortedByDate];
		
		for(NSUInteger j = messages.count; j > 0; j--) {
			SMMessage *message = messages[j-1];
			NSData *data = message.data;
			
			if(data != nil) {
				reclaimedMessagesCount++;
				reclaimedMemory += data.length;

                [message reclaimData];
				
				if(reclaimedMemory / 1024 >= memoryToReclaimKb) {
					stop = YES;
					break;
				}
			}
		}
	}
	
	NSAssert(_totalMemory >= reclaimedMemory, @"_totalMemory %llu < reclaimedMemory %llu", _totalMemory, reclaimedMemory);
	
	_totalMemory -= reclaimedMemory;

	SM_LOG_DEBUG(@"total reclaimed %llu Kb in %lu messages, %llu Kb left in folder %@", reclaimedMemory / 1024 ,reclaimedMessagesCount, _totalMemory / 1024, _localName);
}

- (void)recalculateTotalMemorySize {
	_totalMemory = 0;

	SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
	SMMessageStorage *storage = [[appDelegate model] messageStorage];

	NSUInteger threadsCount = [storage messageThreadsCountInLocalFolder:_localName];
	for(NSUInteger i = 0; i < threadsCount; i++) {
		SMMessageThread *thread = [storage messageThreadAtIndexByDate:i localFolder:_localName];

		for(SMMessage *message in [thread messagesSortedByDate]) {
			NSData *data = message.data;
			
			if(data != nil)
				_totalMemory += data.length;
		}
	}

	SM_LOG_DEBUG(@"total memory %llu Kb in folder %@", _totalMemory / 1024, _localName);
}

- (uint64_t)getTotalMemoryKb {
	return _totalMemory / 1024;
}

@end
