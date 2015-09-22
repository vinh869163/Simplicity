//
//  SMDatabase.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

//
// DB logic:
//
// * every operation is asynchronous;
// * app load (no communication with the server yet):
//   - consistency verified (checksum):
//     + if fails, the whole DB is erased;
//   - get folders;
//   - go through each folder;
//   - load message headers for uids 0...N(large), put to message storage, init message list;
//   - load message previews and detail for uids 0...N;
//   - actually load bodies for messages 0...M(not too large);
// * after everything is loaded from db:
//   - load messages 0...N from server;
//   - new uids: fetch bodies;
//   - old uids, vanished uids - use the standard way, with DB as backend:
//     + reflect flags change in DB;
//     + remove vanished messages from DB;
// * older messages loading on demand:
//   - load message headers for uids N+1...N+K, put to message storage, update message list;
//   - load message previews and detail for uids N+1...N+K;
//   - actually load bodies for messages N+1...N+K;
//   - after messages are loaded from DB, use the generic scheme to sync them with the server;
// * modifying stored data:
//   - folder structure is saved immediately (empty folders);
//   - folders erased immediately (with unique contents);
//   - db mimics mailcore2 message and folder ops;
//   - TODO? deleting old vanished messages from DB?
//     + use all uids in the current folder (including threads);
//     + vanished uids will be propagated to DB automatically;
// * message threads construction:
//   - when the DB is built for the first time, search is used to collect threads;
//   - to update threads, uids from them are used;
//   - for each thread, a completeness marker is stored:
//     + if not set, search is used; when search is over for the thread, the completeness marker is set in DB;
//     + if set, thread is not constructed further, only updated by uids;
//     + this will dramatically reduce the amount of search ops and improve folder load/update time;
// * message search:
//   - DB is used when the server is not available;
//   - limited search expression; combinations of:
//     + body;
//     + subject;
//     + from;
//     + to/cc;
// * DB size control:
//   - all message headers are always stored:
//     + headers must be fast-way compressed;
//   - oldest bodies erased if DB size > T + D mb (at least 1 Gb);
//   - size reduced to T mb (D is delta, e.g. 100 mb);
//   - sweep is asynchronous and finely chunked (e.g. 4 mb).
//

#import <Foundation/Foundation.h>

@class MCOIMAPMessage;

@interface SMDatabase : NSObject

- (id)initWithFilePath:(NSString*)dbFilePath;
- (void)loadDBFolders;
- (void)addDBFolder:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags;
- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName;
- (void)deleteDBFolder:(NSString*)folderName;
- (NSArray*)getMessageHeadersFromDBFolder:(NSString*)nameName;
- (NSArray*)getMessageBodyForUIDFromDB:(uint32_t*)uid;
- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)nameName;
- (void)deleteMessageFromDB:(MCOIMAPMessage*)imapMessage;
- (void)updateMessageFlagsInDB:(MCOIMAPMessage*)imapMessage;
- (void)updateMessageLabelsInDB:(MCOIMAPMessage*)imapMessage;

@end