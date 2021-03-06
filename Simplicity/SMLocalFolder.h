//
//  SMLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/9/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <MailCore/MailCore.h>

#import "SMAbstractLocalFolder.h"
#import "SMUserAccountDataObject.h"
#import "SMMessageStorageUpdateResult.h"
#import "SMFolder.h"

// TODO: move to advanced settings
static const NSUInteger DEFAULT_MAX_MESSAGES_PER_FOLDER = 500000;
static const NSUInteger INCREASE_MESSAGES_PER_FOLDER = 50;
static const NSUInteger MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_SERVER = 200;
static const NSUInteger MESSAGE_HEADERS_TO_FETCH_AT_ONCE_FROM_DB = 2000;
static const NSUInteger OPERATION_UPDATE_TIMEOUT_SEC = 30;
static const NSUInteger MAX_NEW_MESSAGE_NOTIFICATIONS = 5;

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

@class SMMessageBodyFetchQueue;
@class SMMessageStorage;
@class SMMessage;

@interface SMLocalFolder : SMUserAccountDataObject<SMAbstractLocalFolder> {
    @protected SMFolderKind _kind;
    @protected NSString *_localName;
    @protected NSString *_remoteFolderName;
    @protected NSUInteger _unseenMessagesCount;
    @protected NSUInteger _totalMessagesCount;
    @protected NSUInteger _messageHeadersFetched;
    @protected NSUInteger _maxMessagesPerThisFolder;
    @protected BOOL _syncedWithRemoteFolder;
    @protected SMMessageStorage *_messageStorage;
    @protected MCOIMAPFolderInfoOperation *_folderInfoOp;
    @protected MCOIMAPFetchMessagesOperation *_fetchMessageHeadersOp;
    @protected NSMutableDictionary *_searchMessageThreadsOps;
    @protected NSMutableDictionary *_fetchedMessageHeaders;
    @protected BOOL _loadingFromDB;
    @protected BOOL _dbSyncInProgress;
    @protected NSUInteger _dbMessageThreadsLoadsCount;
    @protected SMMessageBodyFetchQueue *_messageBodyFetchQueue;
}

@property (readonly) SMMessageBodyFetchQueue *messageBodyFetchQueue;

- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind initialUnreadCount:(NSUInteger)initialUnreadCount syncWithRemoteFolder:(BOOL)syncWithRemoteFolder;
- (id)initWithUserAccount:(id<SMAbstractAccount>)account localFolderName:(NSString*)localFolderName remoteFolderName:(NSString*)remoteFolderName kind:(SMFolderKind)kind syncWithRemoteFolder:(BOOL)syncWithRemoteFolder;

- (SMMessageThread*)messageThreadByMessageId:(uint64_t)messageId;

#pragma mark Protected methods

- (void)updateMessageHeaders:(NSArray<MCOIMAPMessage*>*)messages plainTextBodies:(NSArray<NSString*>*)plainTextBodies hasAttachmentsFlags:(NSArray<NSNumber*>*)hasAttachmentsFlags updateDatabase:(BOOL)updateDatabase newMessages:(NSMutableArray<MCOIMAPMessage*>*)newMessages;

- (void)finalizeLocalFolderUpdate:(SMMessageStorageUpdateResult)updateResult;

@end
