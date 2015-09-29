//
//  SMDatabase.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 9/14/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <sqlite3.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMFolderDesc.h"
#import "SMCompression.h"
#import "SMDatabase.h"

@implementation SMDatabase {
    NSString *_dbFilePath;
    dispatch_queue_t _serialQueue;
    dispatch_queue_t _concurrentQueue;
    int32_t _serialQueueLength;
    NSMutableDictionary *_folderIds;
    NSMutableSet *_messagesWithBodies;
}

- (id)initWithFilePath:(NSString*)dbFilePath {
    self = [self init];

    if(self) {
        _serialQueue = dispatch_queue_create("com.simplicity.Simplicity.serialDatabaseQueue", DISPATCH_QUEUE_SERIAL);
        _concurrentQueue = dispatch_queue_create("com.simplicity.Simplicity.concurrentDatabaseQueue", DISPATCH_QUEUE_CONCURRENT);
        _dbFilePath = dbFilePath;
        
        [self initDatabase];
    }
    
    return self;
}

- (sqlite3*)openDatabase {
    sqlite3 *database = nil;
    
    const int openDatabaseResult = sqlite3_open([_dbFilePath UTF8String], &database);
    if(openDatabaseResult == SQLITE_OK) {
        SM_LOG_DEBUG(@"Database %@ open successfully", _dbFilePath);
        return database;
    }
    else {
        SM_LOG_FATAL(@"Database %@ cannot be open", _dbFilePath);
        return nil;
    }
}

- (void)closeDatabase:(sqlite3*)database {
    const int sqlCloseResult = sqlite3_close(database);
    
    if(sqlCloseResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not close database, error %d", sqlCloseResult);
    }
}

- (void)initDatabase {
    sqlite3 *database = [self openDatabase];
    
    if(database != nil) {
        [self createFoldersTable:database];
        [self createMessagesTable:database];
        [self createMessageBodiesTable:database];
        [self loadFolderIds:database];
        [self loadMessageBodiesInfo:database];
        [self closeDatabase:database];
    }
}

- (void)createFoldersTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS FOLDERS (ID INTEGER PRIMARY KEY AUTOINCREMENT, NAME TEXT UNIQUE, DELIMITER INTEGER, FLAGS INTEGER)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table FOLDERS: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createFolderMessagesTable:(sqlite3*)database folderName:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
    }
    
    NSString *createSql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS FOLDER%@ (UID INTEGER PRIMARY KEY UNIQUE)", folderId];
    const char *createStmt = [createSql UTF8String];
    
    char *errMsg = NULL;
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table for folder \"%@\" (id %@): %s, error %d", folderName, folderId, errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createMessagesTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGES (UID INTEGER PRIMARY KEY UNIQUE, MESSAGE BLOB)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table MESSAGES: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (void)createMessageBodiesTable:(sqlite3*)database {
    char *errMsg = NULL;
    const char *createStmt = "CREATE TABLE IF NOT EXISTS MESSAGEBODIES (UID INTEGER PRIMARY KEY UNIQUE, MESSAGEBODY BLOB)";
    
    const int sqlResult = sqlite3_exec(database, createStmt, NULL, NULL, &errMsg);
    if(sqlResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Failed to create table MESSAGEBODIES: %s, error %d", errMsg, sqlResult);
        // TODO: mark the DB as invalid?
    }
}

- (NSDictionary*)loadDataFromDB:(sqlite3*)database query:(const char *)sqlQuery {
    NSAssert(database != nil, @"no database open");
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, sqlQuery, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
    }
    
    NSMutableArray *arrRows = [[NSMutableArray alloc] init];
    NSMutableArray *arrColumnNames = [[NSMutableArray alloc] init];
    const int totalColumns = sqlite3_column_count(statement);
    
    while(sqlite3_step(statement) == SQLITE_ROW) {
        NSMutableArray *arrDataRow = [[NSMutableArray alloc] init];
        
        for(int i = 0; i < totalColumns; i++){
            char *dbDataAsChars = (char *)sqlite3_column_text(statement, i);
            
            if(dbDataAsChars != NULL) {
                [arrDataRow addObject:[NSString  stringWithUTF8String:dbDataAsChars]];
            }
            
            if(arrColumnNames.count != totalColumns) {
                dbDataAsChars = (char *)sqlite3_column_name(statement, i);
                [arrColumnNames addObject:[NSString stringWithUTF8String:dbDataAsChars]];
            }
        }
        
        if(arrDataRow.count > 0) {
            [arrRows addObject:arrDataRow];
        }
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
    
    NSDictionary *results = [[NSMutableDictionary alloc] init];
    
    [results setValue:arrColumnNames forKey:@"Columns"];
    [results setValue:arrRows forKey:@"Rows"];

    return results;
}

- (void)loadFolderIds:(sqlite3*)database {
    _folderIds = [[NSMutableDictionary alloc] init];

    const char *sqlQuery = "SELECT * FROM FOLDERS";
    NSDictionary *foldersTable = [self loadDataFromDB:database query:sqlQuery];
    NSArray *columns = [foldersTable objectForKey:@"Columns"];
    NSArray *rows = [foldersTable objectForKey:@"Rows"];
    
    const NSInteger idColumn = [columns indexOfObject:@"ID"];
    const NSInteger nameColumn = [columns indexOfObject:@"NAME"];
    
    if(idColumn != NSNotFound && nameColumn != NSNotFound) {
        for(NSUInteger i = 0; i < rows.count; i++) {
            NSArray *row = rows[i];
            NSString *idStr = row[idColumn];
            NSString *nameStr = row[nameColumn];
            NSUInteger folderId = [idStr integerValue];

            [_folderIds setObject:[NSNumber numberWithUnsignedInteger:folderId] forKey:nameStr];
            
            SM_LOG_DEBUG(@"Folder \"%@\" id %lu", nameStr, folderId);
        }
    }
}

- (void)loadMessageBodiesInfo:(sqlite3*)database {
    _messagesWithBodies = [NSMutableSet set];
    
    NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT UID FROM MESSAGEBODIES"];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
    
    if(sqlPrepareResult == SQLITE_OK) {
        while(sqlite3_step(statement) == SQLITE_ROW) {
            uint32_t uid = sqlite3_column_int(statement, 0);
            
            SM_LOG_DEBUG(@"message with UID %u has its body in the database", uid);

            [_messagesWithBodies addObject:[NSNumber numberWithUnsignedInt:uid]];
        }
    }
    else {
        SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
        // TODO
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
}

- (void)loadFolderId:(sqlite3*)database folderName:(NSString*)folderName {
    NSString *selectSql = [NSString stringWithFormat: @"SELECT ID FROM FOLDERS WHERE NAME = \"%@\"", folderName];
    NSDictionary *foldersTable = [self loadDataFromDB:database query:[selectSql UTF8String]];
    NSArray *columns = [foldersTable objectForKey:@"Columns"];
    NSArray *rows = [foldersTable objectForKey:@"Rows"];
    
    const NSInteger idColumn = [columns indexOfObject:@"ID"];
    
    if(idColumn != 0) {
        SM_LOG_ERROR(@"database corrupted: folder ID column not found (column value %ld)", idColumn);
        // TODO: trigger database erase
    }
    else if(rows.count != 1) {
        SM_LOG_ERROR(@"database corrupted: folder could not be added");
        // TODO: trigger database erase
    }
    else {
        NSArray *row = rows[0];
        NSString *idStr = row[0];
        NSUInteger folderId = [idStr integerValue];
        
        [_folderIds setObject:[NSNumber numberWithUnsignedInteger:folderId] forKey:folderName];
        
        SM_LOG_DEBUG(@"Folder \"%@\" id %lu", folderName, folderId);
    }
}

- (void)addDBFolder:(NSString*)folderName delimiter:(char)delimiter flags:(MCOIMAPFolderFlag)flags {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            //
            // Step 1: Add the folder into the DB.
            //
            NSString *insertSql = [NSString stringWithFormat: @"INSERT INTO FOLDERS (NAME, DELIMITER, FLAGS) VALUES (\"%@\", %ld, %ld)", folderName, (NSInteger)delimiter, (NSInteger)flags];
            const char *insertStmt = [insertSql UTF8String];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders insert statement, error %d", sqlPrepareResult);
            }
            
            BOOL newFolderAdded = NO;
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Folder %@ successfully inserted", folderName);

                newFolderAdded = YES;
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Folder %@ already exists", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to insert folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);

            if(newFolderAdded) {
                //
                // Step 2: For new folders, find out what's the ID of the newly added folder.
                //
                [self loadFolderId:database folderName:folderName];
                
                //
                // Step 3: Create a unique folder table containing message UIDs.
                //
                [self createFolderMessagesTable:database folderName:folderName];
            }
            
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)renameDBFolder:(NSString*)folderName newName:(NSString*)newName {
    NSAssert(nil, @"TODO");
}

- (void)deleteDBFolder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *deleteSql = [NSString stringWithFormat: @"DELETE FROM FOLDERS WHERE NAME = \"%@\"", folderName];
            const char *deleteStmt = [deleteSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare folders delete statement, error %d", sqlPrepareResult);
            }
            
            int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_INFO(@"Folder %@ successfully deleted", folderName);
            } else {
                SM_LOG_ERROR(@"Failed to delete folder %@, error %d", folderName, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders delete statement result %d", sqlFinalizeResult);
         
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadDBFolders:(void (^)(NSArray*))loadFoldersBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSMutableArray *folders = nil;
            
            const char *sqlQuery = "SELECT * FROM FOLDERS";
            NSDictionary *foldersTable = [self loadDataFromDB:database query:sqlQuery];
            NSArray *columns = [foldersTable objectForKey:@"Columns"];
            NSArray *rows = [foldersTable objectForKey:@"Rows"];
            
            const NSInteger nameColumn = [columns indexOfObject:@"NAME"];
            const NSInteger delimiterColumn = [columns indexOfObject:@"DELIMITER"];
            const NSInteger flagsColumn = [columns indexOfObject:@"FLAGS"];

            if(nameColumn == NSNotFound || delimiterColumn == NSNotFound || flagsColumn == NSNotFound) {
                if(columns.count > 0 && rows.count > 0) {
                    SM_LOG_ERROR(@"database corrupted: folder name/delimiter/flags columns not found: %ld/%ld/%ld", nameColumn, delimiterColumn, flagsColumn);
                }
                
                // TODO: trigger database erase
            }
            else {
                folders = [NSMutableArray arrayWithCapacity:rows.count];
                
                for(NSUInteger i = 0; i < rows.count; i++) {
                    NSArray *row = rows[i];
                    NSString *name = row[nameColumn];
                    char delimiter = [((NSString*)row[delimiterColumn]) integerValue];
                    MCOIMAPFolderFlag flags = [((NSString*)row[flagsColumn]) integerValue];
                    
                    folders[i] = [[SMFolderDesc alloc] initWithFolderName:name delimiter:delimiter flags:flags];
                }
            }

            [self closeDatabase:database];

            dispatch_async(dispatch_get_main_queue(), ^{
                loadFoldersBlock(folders);
            });
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)getMessagesCountInDBFolder:(NSString*)folderName block:(void (^)(NSUInteger))getMessagesCountBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSUInteger messagesCount = 0;

            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId != nil) {
                NSString *getCountSql = [NSString stringWithFormat:@"SELECT COUNT(*) FROM FOLDER%@", folderId];
                const char *getCountStmt = [getCountSql UTF8String];
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, getCountStmt, -1, &statement, NULL);
                if(sqlPrepareResult == SQLITE_OK) {
                    int sqlResult = sqlite3_step(statement);
                    if(sqlResult == SQLITE_ROW) {
                        SM_LOG_DEBUG(@"Step for folder %@ is successful", folderName);
                        
                        messagesCount = sqlite3_column_int(statement, 0);

                        SM_LOG_DEBUG(@"Messages count in folder %@ is %lu", folderName, messagesCount);
                    } else {
                        SM_LOG_ERROR(@"Failed to get messages count from folder %@, error %d", folderName, sqlResult);
                    }
                }
                else {
                    SM_LOG_ERROR(@"could not prepare messages count statement, error %d", sqlPrepareResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            }
            
            [self closeDatabase:database];

            dispatch_async(dispatch_get_main_queue(), ^{
                getMessagesCountBlock(messagesCount);
            });
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)loadMessageHeadersFromDBFolder:(NSString*)folderName offset:(NSUInteger)offset count:(NSUInteger)count block:(void (^)(NSArray*))getMessagesBlock {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSMutableArray *messages = [NSMutableArray arrayWithCapacity:count];

            NSString *getMessagesSql = [NSString stringWithFormat:@"SELECT MESSAGE FROM MESSAGES ORDER BY UID DESC LIMIT %lu OFFSET %lu", count, offset];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessagesSql UTF8String], -1, &statement, NULL);

            if(sqlPrepareResult == SQLITE_OK) {
                while(sqlite3_step(statement) == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];
                    
                    MCOIMAPMessage *message = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
                    NSAssert(message != nil, @"could not decode IMAP message");
                    
                    [messages addObject:message];
                }
            }
            else {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                // TODO
            }

            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);

            [self closeDatabase:database];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                getMessagesBlock(messages);
            });
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (BOOL)loadMessageBodyForUIDFromDB:(uint32_t)uid block:(void (^)(NSData*, MCOMessageParser*, NSArray*))getMessageBodyBlock {
    if(![_messagesWithBodies containsObject:[NSNumber numberWithUnsignedInt:uid]]) {
        SM_LOG_NOISE(@"no message body for message UID %u in the database", uid);
        return FALSE;
    }
    
    SM_LOG_NOISE(@"message UID %u has its body in the database", uid);

    dispatch_async(_concurrentQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            NSString *getMessageBodySql = [NSString stringWithFormat:@"SELECT MESSAGEBODY FROM MESSAGEBODIES WHERE UID = \"%u\"", uid];
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, [getMessageBodySql UTF8String], -1, &statement, NULL);
            
            NSData *messageBody = nil;
            
            if(sqlPrepareResult == SQLITE_OK) {
                if(sqlite3_step(statement) == SQLITE_ROW) {
                    int dataSize = sqlite3_column_bytes(statement, 0);
                    NSData *data = [NSData dataWithBytesNoCopy:(void *)sqlite3_column_blob(statement, 0) length:dataSize freeWhenDone:NO];
                    NSData *uncompressedData = [SMCompression gzipInflate:data];

                    messageBody = uncompressedData;
                }
            }
            else {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                // TODO
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize message count statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
            
            MCOMessageParser *parser = [MCOMessageParser messageParserWithData:messageBody];
            NSArray *attachments = parser.attachments; // note that this is potentially long operation, so do it in the current thread

            dispatch_async(dispatch_get_main_queue(), ^{
                getMessageBodyBlock(messageBody, parser, attachments);
            });
        }
    });

    return TRUE;
}

- (void)putMessageToDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            //
            // Step 1: Add the message UID to the given folder table.
            //
            NSNumber *folderId = [_folderIds objectForKey:folderName];
            if(folderId == nil) {
                SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
                // TODO: mark the DB as invalid?
            }
            
            NSString *folderInsertSql = [NSString stringWithFormat:@"INSERT INTO FOLDER%@ (\"UID\") VALUES (?)", folderId];
            const char *folderInsertStmt = [folderInsertSql UTF8String];

            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, folderInsertStmt, -1, &statement, NULL);
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
            }
            
            BOOL messageUidInserted = NO;
            
            const int sqlResult = sqlite3_step(statement);
            if(sqlResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message UID %u successfully inserted to folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
                
                messageUidInserted = YES;
            } else if(sqlResult == SQLITE_CONSTRAINT) {
                SM_LOG_DEBUG(@"Message UID %u already in folder \"%@\" (id %@)", imapMessage.uid, folderName, folderId);
            } else {
                SM_LOG_ERROR(@"Failed to insert message UID %u in folder \"%@\" (id %@), error %d", imapMessage.uid, folderName, folderId, sqlResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize folders insert statement result %d", sqlFinalizeResult);
            
            if(messageUidInserted) {
                //
                // Step 2: If the message UID has been inserted, add its body to the DB as well unless it is there yet.
                //
                NSData *encodedMessage = [NSKeyedArchiver archivedDataWithRootObject:imapMessage];
                NSAssert(encodedMessage != nil, @"could not encode IMAP message");

                const char *insertStmt = "INSERT INTO MESSAGES (\"UID\", \"MESSAGE\") VALUES (?, ?)";
                
                sqlite3_stmt *statement = NULL;
                const int sqlPrepareResult = sqlite3_prepare_v2(database, insertStmt, -1, &statement, NULL);
                
                if(sqlPrepareResult != SQLITE_OK) {
                    SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
                }

                int bindResult;
                if((bindResult = sqlite3_bind_int(statement, 1, imapMessage.uid)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", imapMessage.uid, bindResult);
                }

                NSData *compressedMessage = [SMCompression gzipDeflate:encodedMessage];
                
                SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", imapMessage.uid, encodedMessage.length, compressedMessage.length, compressedMessage.length/(encodedMessage.length/100));

                if((bindResult = sqlite3_bind_blob(statement, 2, compressedMessage.bytes, (int)compressedMessage.length, SQLITE_STATIC)) != SQLITE_OK) {
                    SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGE), error %d", imapMessage.uid, bindResult);
                }
                
                const int sqlInsertResult = sqlite3_step(statement);
                if(sqlInsertResult == SQLITE_DONE) {
                    SM_LOG_DEBUG(@"Message with UID %u successfully inserted", imapMessage.uid);
                } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                    // TODO: restore WARNING; don't rewrite messages on first launch
                    SM_LOG_DEBUG(@"Message with UID %u already exists", imapMessage.uid);
                } else {
                    SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", imapMessage.uid, sqlInsertResult);
                }
                
                const int sqlFinalizeResult = sqlite3_finalize(statement);
                SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            }
            
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)deleteUIDFromFolderTable:(sqlite3*)database uid:(uint32_t)uid folder:(NSString*)folderName {
    NSNumber *folderId = [_folderIds objectForKey:folderName];
    if(folderId == nil) {
        SM_LOG_ERROR(@"No id for folder \"%@\" found in DB", folderName);
        // TODO: mark the DB as invalid?
        return;
    }
    
    NSString *deleteSql = [NSString stringWithFormat:@"DELETE FROM FOLDER%@ WHERE UID = \"%u\"", folderId, uid];
    const char *deleteStmt = [deleteSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Could not prepare delete statement for message UID %u, folder %@ (%@), error %d", uid, folderName, folderId, sqlPrepareResult);
    }
    
    int sqlResult = sqlite3_step(statement);
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_INFO(@"Message UID %u successfully deleted from folder %@ (%@)", uid, folderName, folderId);
    } else {
        SM_LOG_INFO(@"Failed to delete message UID %u from folder %@ (%@)", uid, folderName, folderId);
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders delete statement result %d", sqlFinalizeResult);
}

- (void)deleteMessageFromMessagesTable:(sqlite3*)database uid:(uint32_t)uid {
    NSString *deleteSql = [NSString stringWithFormat: @"DELETE FROM MESSAGES WHERE UID = \"%u\"", uid];
    const char *deleteStmt = [deleteSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Could not prepare message (UID %u) delete statement, error %d", uid, sqlPrepareResult);
    }
    
    int sqlResult = sqlite3_step(statement);
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_INFO(@"Message with UID %u successfully deleted from messages table", uid);
    } else {
        SM_LOG_ERROR(@"Failed to delete message with UID %u, error %d", uid, sqlResult);
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders delete statement result %d", sqlFinalizeResult);
}

- (void)deleteMessageBodyFromMessageBodiesTable:(sqlite3*)database uid:(uint32_t)uid {
    NSString *deleteSql = [NSString stringWithFormat: @"DELETE FROM MESSAGEBODIES WHERE UID = \"%u\"", uid];
    const char *deleteStmt = [deleteSql UTF8String];
    
    sqlite3_stmt *statement = NULL;
    const int sqlPrepareResult = sqlite3_prepare_v2(database, deleteStmt, -1, &statement, NULL);
    if(sqlPrepareResult != SQLITE_OK) {
        SM_LOG_ERROR(@"Could not prepare message body (UID %u) delete statement, error %d", uid, sqlPrepareResult);
    }
    
    int sqlResult = sqlite3_step(statement);
    if(sqlResult == SQLITE_DONE) {
        SM_LOG_INFO(@"Message body with UID %u successfully deleted from message bodies table", uid);
    } else {
        SM_LOG_ERROR(@"Failed to delete message body with UID %u, error %d", uid, sqlResult);
    }
    
    const int sqlFinalizeResult = sqlite3_finalize(statement);
    SM_LOG_NOISE(@"finalize folders delete statement result %d", sqlFinalizeResult);
}

- (void)removeMessageFromDBFolder:(uint32_t)uid folder:(NSString*)folderName {
    [_messagesWithBodies removeObject:[NSNumber numberWithUnsignedInt:uid]];

    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            [self deleteUIDFromFolderTable:database uid:uid folder:folderName];
            [self deleteMessageFromMessagesTable:database uid:uid];
            [self deleteMessageBodyFromMessageBodiesTable:database uid:uid];
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

- (void)updateMessageInDBFolder:(MCOIMAPMessage*)imapMessage folder:(NSString*)folderName {
    SM_LOG_DEBUG(@"TODO");
}

- (void)deleteMessageFromDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}

- (void)updateMessageFlagsInDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}

- (void)updateMessageLabelsInDB:(MCOIMAPMessage*)imapMessage {
    NSAssert(nil, @"TODO");
}

- (void)putMessageBodyToDB:(uint32_t)uid data:(NSData*)data {
    [_messagesWithBodies addObject:[NSNumber numberWithUnsignedInt:uid]];

    const int32_t serialQueueLen = OSAtomicAdd32(1, &_serialQueueLength);
    SM_LOG_INFO(@"serial queue length: %d", serialQueueLen);
    
    dispatch_async(_serialQueue, ^{
        sqlite3 *database = [self openDatabase];
        
        if(database != nil) {
            //
            // Step 2: If the message UID has been inserted, add its body to the DB as well unless it is there yet.
            //
            const char *insertStmt = "INSERT INTO MESSAGEBODIES (\"UID\", \"MESSAGEBODY\") VALUES (?, ?)";
            
            sqlite3_stmt *statement = NULL;
            const int sqlPrepareResult = sqlite3_prepare_v2(database, insertStmt, -1, &statement, NULL);
            
            if(sqlPrepareResult != SQLITE_OK) {
                SM_LOG_ERROR(@"could not prepare load statement, error %d", sqlPrepareResult);
            }
            
            int bindResult;
            if((bindResult = sqlite3_bind_int(statement, 1, uid)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 1 (UID), error %d", uid, bindResult);
            }
            
            NSData *compressedData = [SMCompression gzipDeflate:data];
            
            SM_LOG_DEBUG(@"message UID %u, data len %lu, compressed len %lu (%lu%% from original)", uid, data.length, compressedData.length, compressedData.length/(data.length/100));
            
            if((bindResult = sqlite3_bind_blob(statement, 2, compressedData.bytes, (int)compressedData.length, SQLITE_STATIC)) != SQLITE_OK) {
                SM_LOG_ERROR(@"message UID %u, could not bind argument 2 (MESSAGEBODY), error %d", uid, bindResult);
            }
            
            const int sqlInsertResult = sqlite3_step(statement);
            if(sqlInsertResult == SQLITE_DONE) {
                SM_LOG_DEBUG(@"Message with UID %u successfully inserted", uid);
            } else if(sqlInsertResult == SQLITE_CONSTRAINT) {
                // TODO: restore WARNING; don't rewrite messages on first launch
                SM_LOG_DEBUG(@"Message with UID %u already exists", uid);
            } else {
                SM_LOG_ERROR(@"Failed to insert message with UID %u, error %d", uid, sqlInsertResult);
            }
            
            const int sqlFinalizeResult = sqlite3_finalize(statement);
            SM_LOG_NOISE(@"finalize messages insert statement result %d", sqlFinalizeResult);
            
            [self closeDatabase:database];
        }

        OSAtomicAdd32(-1, &_serialQueueLength);
    });
}

@end
