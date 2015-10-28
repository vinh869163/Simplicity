//
//  SMAttachmentItem.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/22/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MCOAttachment;

@interface SMAttachmentItem : NSObject<NSCoding>

@property (nonatomic, readonly) NSString *localFilePath;
@property (nonatomic, readonly) NSString *fileName;
@property (nonatomic, readonly) NSData *fileData;

- (id)initWithMCOAttachment:(MCOAttachment*)mcoAttachment;
- (id)initWithLocalFilePath:(NSString*)localFilePath;

- (Boolean)writeAttachmentTo:(NSURL*)baseUrl;
- (Boolean)writeAttachmentTo:(NSURL*)baseUrl withFileName:(NSString*)fileName;

@end
