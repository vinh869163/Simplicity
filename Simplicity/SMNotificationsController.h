//
//  SMNotificationsController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 12/5/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMAddress;
@class SMUserAccount;
@class SMMessageEditorViewController;
@class SMMessageThreadCellViewController;

@interface SMNotificationsController : NSObject

+ (void)systemNotifyNewMessage:(NSString*)from;
+ (void)systemNotifyNewMessages:(NSUInteger)count;

+ (void)localNotifyFolderListUpdated:(SMUserAccount*)account;
+ (void)localNotifyMessageHeadersSyncFinished:(NSString*)localFolder hasUpdates:(BOOL)hasUpdates account:(SMUserAccount*)account;
+ (void)localNotifyMessageBodyFetched:(NSString*)localFolder uid:(uint32_t)uid threadId:(int64_t)threadId account:(SMUserAccount*)account;
+ (void)localNotifyMessageFlagsUpdates:(NSString*)localFolder account:(SMUserAccount*)account;
+ (void)localNotifyMessagesUpdated:(NSString*)localFolder updateResult:(NSUInteger)updateResult account:(SMUserAccount*)account;
+ (void)localNotifyMessageSent:(SMMessageEditorViewController*)messageEditorViewController account:(SMUserAccount*)account;
+ (void)localNotifyNewLabelCreated:(NSString*)labelName account:(SMUserAccount*)account;

+ (void)localNotifyMessageViewFrameLoaded:(uint32_t)uid;
+ (void)localNotifyDeleteEditedMessageDraft:(SMMessageEditorViewController*)messageEditorViewController;
+ (void)localNotifyChangeMessageFlaggedFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyChangeMessageUnreadFlag:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyDeleteMessage:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachments:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifySaveAttachmentsToDownloads:(SMMessageThreadCellViewController*)messageThreadCellViewController;
+ (void)localNotifyComposeMessageReply:(SMMessageThreadCellViewController*)messageThreadCellViewController replyKind:(NSString*)replyKind toAddress:(SMAddress*)toAddress;

+ (void)getMessageHeadersSyncFinishedParams:(NSNotification*)notification localFolder:(NSString**)localFolder hasUpdates:(BOOL*)hasUpdates account:(SMUserAccount**)account;
+ (void)getMessageBodyFetchedParams:(NSNotification*)notification localFolder:(NSString**)localFolder uid:(uint32_t*)uid threadId:(int64_t*)threadId account:(SMUserAccount**)account;
+ (void)getMessageFlagsUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(SMUserAccount**)account;
+ (void)getMessagesUpdatedParams:(NSNotification*)notification localFolder:(NSString**)localFolder account:(SMUserAccount**)account;
+ (void)getMessageViewFrameLoadedParams:(NSNotification*)notification uid:(uint32_t*)uid account:(SMUserAccount**)account;

@end
