//
//  SMFolderColorController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 2/8/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMFolder.h"
#import "SMFolderLabel.h"
#import "SMMessageThread.h"
#import "SMPreferencesController.h"
#import "SMFolderColorController.h"

@implementation SMFolderColorController

+ (NSColor*)randomLabelColor {
    CGFloat hue = ( arc4random() % 256 / 256.0 );  //  0.0 to 1.0
    CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from white
    CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;  //  0.5 to 1.0, away from black
    NSColor *color = [NSColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
    return color;
}

- (id)init {
    self = [super init];
    
    return self;
}

- (SMFolderLabel*)getOrUpdateLabel:(NSString*)folderName withColor:(NSColor*)color {
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];

    NSUInteger accountIdx = appDelegate.currentAccountIdx;
    NSDictionary *labels = [[appDelegate preferencesController] labels:accountIdx];
    SMFolderLabel *label = [labels objectForKey:folderName];
    
    if(label == nil) {
        label = [[SMFolderLabel alloc] initWithName:folderName color:(color != nil? color : [SMFolderColorController randomLabelColor]) favorite:NO visible:YES];
    }
    else if(color != nil) {
        label.color = color;
    }
    else {
        return label;
    }
    
    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:labels];
    [updatedLabels setObject:label forKey:folderName];
    
    [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
    
    return label;
}

- (void)deleteFolderColor:(NSString*)folderName {
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    
    NSUInteger accountIdx = appDelegate.currentAccountIdx;
    NSDictionary *labels = [[appDelegate preferencesController] labels:accountIdx];
    
    NSMutableDictionary *updatedLabels = [NSMutableDictionary dictionaryWithDictionary:labels];
    [updatedLabels removeObjectForKey:folderName];
    
    [[appDelegate preferencesController] setLabels:accountIdx labels:updatedLabels];
}

- (NSColor*)colorForFolder:(NSString*)folderName {
    return [self getOrUpdateLabel:folderName withColor:nil].color;
}

- (void)setFolderColor:(NSString*)folderName color:(NSColor*)color {
    [self getOrUpdateLabel:folderName withColor:color];
}

- (NSArray*)colorsForMessageThread:(SMMessageThread*)messageThread folder:(SMFolder*)folder labels:(NSMutableArray*)labels {
    NSMutableArray *bookmarkColors = [NSMutableArray array];
    
    SMAppDelegate *appDelegate =  [[ NSApplication sharedApplication ] delegate];
    SMAppController *appController = [appDelegate appController];
    NSColor *mainColor = (folder != nil && folder.kind == SMFolderKindRegular)? [[appController folderColorController] colorForFolder:folder.fullName] : nil;
    
    [labels removeAllObjects];

    if(mainColor != nil) {
        [bookmarkColors addObject:mainColor];
        
        if(mainColor != nil)
            [labels addObject:folder.fullName];
    }
    
    for(NSString *label in messageThread.labels) {
        SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
        SMAppController *appController = [appDelegate appController];
        
        if([label characterAtIndex:0] != '\\') {
            NSColor *color = [[appController folderColorController] colorForFolder:label];
            
            if(color != mainColor) {
                [bookmarkColors addObject:color];
                [labels addObject:label];
            }
        }
    }
    
    return bookmarkColors;
}

@end
