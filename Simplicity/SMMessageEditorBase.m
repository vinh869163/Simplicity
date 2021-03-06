//
//  SMMessageEditorBase.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 7/12/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMPreferencesController.h"
#import "SMMessageEditorBase.h"

static NSArray *fontFamilies;
static NSArray *fontNames;
static NSDictionary *fontNameToIndexMap;

@implementation SMMessageEditorBase

- (id)init {
    self = [super init];
    
    // Static data
    
    if(fontNameToIndexMap == nil) {
        fontFamilies = [NSArray arrayWithObjects:
                        @"Sans Serif",
                        @"Serif",
                        @"Fixed Width",
                        @"Wide",
                        @"Narrow",
                        @"Comic Sans MS",
                        @"Garamond",
                        @"Georgia",
                        @"Tahoma",
                        @"Trebuchet MS",
                        @"Verdana",
                        nil];
        
        fontNames = [NSArray arrayWithObjects:
                     @"Arial",
                     @"Times New Roman",
                     @"Courier New",
                     @"Arial Black",
                     @"Arial Narrow",
                     @"Comic Sans MS",
                     @"Times",
                     @"Georgia",
                     @"Tahoma",
                     @"Trebuchet MS",
                     @"Verdana",
                     nil];
        
        NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
        
        for(NSUInteger i = 0; i < fontNames.count; i++) {
            NSNumber *indexNum = [NSNumber numberWithUnsignedInteger:i];
            
            [mapping setObject:indexNum forKey:fontNames[i]];
            [mapping setObject:indexNum forKey:[NSString stringWithFormat:@"'%@'", fontNames[i]]];
            [mapping setObject:indexNum forKey:[NSString stringWithFormat:@"\"%@\"", fontNames[i]]];
        }
        
        fontNameToIndexMap = mapping;
    }

    return self;
}

+ (NSArray*)fontFamilies {
    NSAssert(fontFamilies != nil, @"fontFamilies is nil");
    return fontFamilies;
}

+ (NSArray*)fontNames {
    NSAssert(fontNames != nil, @"fontNames is nil");
    return fontNames;
}

+ (NSDictionary*)fontNameToIndexMap {
    NSAssert(fontNameToIndexMap != nil, @"fontNameToIndexMap is nil");
    return fontNameToIndexMap;
}

+ (NSString*)newMessageHTMLBeginTemplate:(BOOL)folded {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMPreferencesController *preferencesController = [appDelegate preferencesController];
    NSFont *regularFont = preferencesController.regularMessageFont;
    NSString *fontFamily = regularFont.familyName;
    NSUInteger fontSize = (NSUInteger)regularFont.pointSize;
    NSFontDescriptor *fontDescriptor = regularFont.fontDescriptor;
    NSString *fontWeight = (fontDescriptor.symbolicTraits & NSFontBoldTrait) ? @"bold" : @"normal";
    NSString *fontStyle = (fontDescriptor.symbolicTraits & NSFontItalicTrait) ? @"italic" : @"normal";
    NSString *style = (folded? @"style='display: none;'" : @"");
    
    return [NSString stringWithFormat:@""
        "<html>"
        "<style>"
        "  body {"
        "    font-family: '%@';"
        "    font-size: %lupx;"
        "    font-weight: %@;"
        "    font-style: %@;"
        "  }"
        "  blockquote {"
        "    display: block;"
        "    margin-top: 0em;"
        "    margin-bottom: 0em;"
        "    margin-left: 0em;"
        "    padding-left: 15px;"
        "    border-left: 4px solid #ccf;"
        "  }"
        "</style>"
        "<body id='SimplicityEditor'>"
        "  <div id='SimplicityContentToFold' %@>", fontFamily, fontSize, fontWeight, fontStyle, style, nil ];
}

+ (NSString*)newFoldedMessageHTMLBeginTemplate {
    return [self newMessageHTMLBeginTemplate:YES];
}

+ (NSString*)newUnfoldedMessageHTMLBeginTemplate {
    return [self newMessageHTMLBeginTemplate:NO];
}

+ (NSString*)newMessageHTMLEndTemplate {
    return @""
        "  </div>"
        "</body>"
        "</html>";
}

- (NSColor*)colorFromString:(NSString*)colorString {
    NSScanner *colorScanner = [NSScanner scannerWithString:colorString];
    [colorScanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] intoString:nil];
    
    NSInteger r,g,b;
    if([colorScanner scanInteger:&r] && [colorScanner scanString:@", " intoString:nil] &&
       [colorScanner scanInteger:&g] && [colorScanner scanString:@", " intoString:nil] &&
       [colorScanner scanInteger:&b])
    {
        NSInteger a = 255;
        if([colorString characterAtIndex:3] == 'a') {
            if(![colorScanner scanString:@", " intoString:nil] || ![colorScanner scanInteger:&a]) {
                a = 255;
            }
        }
        
        return [NSColor colorWithRed:(CGFloat)r/255 green:(CGFloat)g/255 blue:(CGFloat)b/255 alpha:(CGFloat)a/255];
    }
    else
    {
        return nil;
    }
}

@end
