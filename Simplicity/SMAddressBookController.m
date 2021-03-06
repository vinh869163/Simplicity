//
//  SMAddressBookController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 11/22/15.
//  Copyright © 2015 Evgeny Baskakov. All rights reserved.
//

#import <AddressBook/AddressBook.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMAddress.h"
#import "SMRemoteImageLoadController.h"
#import "SMPreferencesController.h"
#import "SMAddressBookController.h"

#define QUALITY_CONTACT_IMAGE_W 48
#define QUALITY_CONTACT_IMAGE_H 48

@implementation SMAddressBookController {
    NSMutableDictionary<NSString*,NSImage*> *_imageCache;
}

- (id)init {
    self = [super init];
    
    if(self) {
        _defaultUserImage = [NSImage imageNamed:NSImageNameUserGuest];
        _imageCache = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (NSArray<NSString*>*)suggestionsForPrefix:(NSString*)prefix {
    NSMutableArray *results = [NSMutableArray array];
    
    [results addObject:prefix];
    
    [self searchAddressBookProperty:kABFirstNameProperty value:prefix results:results];
    [self searchAddressBookProperty:kABLastNameProperty value:prefix results:results];
    [self searchAddressBookProperty:kABEmailProperty value:prefix results:results];
    
    return results;
}

- (void)searchAddressBookProperty:(NSString*)property value:(NSString*)value results:(NSMutableArray*)resultArrays {
    SMAddressMenuRepresentation addressRepresentationMode = SMAddressRepresentation_FirstNameFirst;
    if([property isEqualTo:kABFirstNameProperty]) {
        addressRepresentationMode = SMAddressRepresentation_FirstNameFirst;
    }
    else if([property isEqualTo:kABLastNameProperty]) {
        addressRepresentationMode = SMAddressRepresentation_LastNameFirst;
    }
    else {
        addressRepresentationMode = SMAddressRepresentation_EmailOnly;
    }
    
    NSMutableOrderedSet *results = [NSMutableOrderedSet orderedSet];
    
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [ABPerson searchElementForProperty:property label:nil key:nil value:value comparison:kABPrefixMatchCaseInsensitive];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];
    
    for(NSUInteger i = 0; i < foundRecords.count; i++) {
        ABRecord *record = foundRecords[i];
        NSString *firstName = [record valueForProperty:kABFirstNameProperty];
        NSString *lastName = [record valueForProperty:kABLastNameProperty];
        ABMultiValue *emails = [record valueForProperty:kABEmailProperty];
        
        for(NSUInteger j = 0; j < emails.count; j++) {
            NSString *email = [emails valueAtIndex:j];
            SMAddress *addressElement = [[SMAddress alloc] initWithFirstName:firstName lastName:lastName email:email representationMode:addressRepresentationMode];
            
            [results addObject:[addressElement stringRepresentationForMenu]];
        }
    }
    
    [resultArrays addObjectsFromArray:[results sortedArrayUsingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
        return [str1 compare:str2];
    }]];
}

- (ABSearchElement*)findAddress:(SMAddress*)address ab:(ABAddressBook*)ab {
    ABSearchElement *search = nil;
    if(address.firstName && address.lastName) {
        ABSearchElement *searchFirstName = [ABPerson searchElementForProperty:kABFirstNameProperty label:nil key:nil value:address.firstName comparison:kABEqualCaseInsensitive];
        ABSearchElement *searchLastName = [ABPerson searchElementForProperty:kABLastNameProperty label:nil key:nil value:address.lastName comparison:kABEqualCaseInsensitive];
        
        search = [ABSearchElement searchElementForConjunction:kABSearchAnd children:@[searchFirstName, searchLastName]];
    }

    NSAssert(address.email, @"no email address");
    ABSearchElement *searchEmail = [ABPerson searchElementForProperty:kABEmailProperty label:nil key:nil value:address.email comparison:kABEqualCaseInsensitive];

    if(search) {
        search = [ABSearchElement searchElementForConjunction:kABSearchOr children:@[search, searchEmail]];
    }
    else {
        search = searchEmail;
    }
    
    return search;
}

- (NSData*)loadContactImageDataFromAddressBook:(SMAddress*)address {
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [self findAddress:address ab:ab];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];
    
    for(NSUInteger i = 0; i < foundRecords.count; i++) {
        ABRecord *record = foundRecords[i];
        
        if([record isKindOfClass:[ABRecord class]]) {
            ABPerson *person = (ABPerson*)record;
            
            if(person.imageData != nil) {
                return person.imageData;
            }

            NSArray *linkedPeople = person.linkedPeople;
            for(ABPerson *linkedPerson in linkedPeople) {
                if(linkedPerson.imageData != nil) {
                    //SM_LOG_INFO(@"contact: %@, linkedPerson with image: %@", address.stringRepresentationShort, linkedPerson);
                    return linkedPerson.imageData;
                }
            }
        }
    }
    
    return nil;
}

- (NSImage*)loadPictureForAddress:(SMAddress*)address searchNetwork:(BOOL)searchNetwork allowWebSiteImage:(BOOL)allowWebSiteImage tag:(NSInteger)tag completionBlock:(void (^)(NSImage*, NSInteger))completionBlock {
    NSImage *cachedImage = [_imageCache objectForKey:address.detailedRepresentation];
    if(cachedImage) {
        if(cachedImage == (NSImage*)[NSNull null]) {
            return nil;
        }
        else {
            return cachedImage;
        }
    }
    
    NSData *imageData = [self loadContactImageDataFromAddressBook:address];
    
    if(imageData != nil) {
        NSImage *image = [[NSImage alloc] initWithData:imageData];
        
        [_imageCache setObject:image?image:(NSImage*)[NSNull null] forKey:address.detailedRepresentation];
        return image;
    }

    if(searchNetwork) {
        SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
        
        SMAddressBookController __weak *weakSelf = self;
        NSImage *image = [appDelegate.remoteImageLoadController loadAvatar:address.email allowWebSiteImage:allowWebSiteImage completionBlock:^(NSImage *image) {
            SMAddressBookController *_self = weakSelf;
            if(!_self) {
                SM_LOG_WARNING(@"object is gone");
                return;
            }

            if(completionBlock) {
                if(![_self allowImage:image])
                    image = nil;
                
                [_self->_imageCache setObject:(image? image : (NSImage*)[NSNull null]) forKey:address.detailedRepresentation];
                completionBlock(image, tag);
            }
        }];

        if(![self allowImage:image])
            image = nil;

        [_imageCache setObject:image?image:(NSImage*)[NSNull null] forKey:address.detailedRepresentation];
        return image;
    }
    else {
        [_imageCache setObject:(NSImage*)[NSNull null] forKey:address.detailedRepresentation];
        return nil;
    }
}

- (BOOL)allowImage:(NSImage*)image {
    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    if((image.size.width < QUALITY_CONTACT_IMAGE_W || image.size.height < QUALITY_CONTACT_IMAGE_H) && ![[appDelegate preferencesController] shouldAllowLowQualityContactImages]) {
        return NO;
    }
    else {
        return YES;
    }
}

- (BOOL)findAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId {
    NSAssert(address, @"address is nil");

    ABAddressBook *ab = [ABAddressBook sharedAddressBook];
    ABSearchElement *search = [self findAddress:address ab:ab];
    NSArray *foundRecords = [ab recordsMatchingSearchElement:search];

    if(foundRecords.count > 0) {
        ABRecord *record = foundRecords[0];
        *uniqueId = record.uniqueId;

        SM_LOG_INFO(@"Address '%@' found in address book (%lu records), first unique id '%@'", address.detailedRepresentation, foundRecords.count, *uniqueId);
        return YES;
    }
    else {
        SM_LOG_INFO(@"Address '%@' not found in address book", address.detailedRepresentation);
        return NO;
    }
}

- (BOOL)addAddress:(SMAddress*)address uniqueId:(NSString**)uniqueId {
    NSAssert(address, @"address is nil");

    ABPerson *person = [[ABPerson alloc] init];
    
    if(address.firstName) {
        [person setValue:address.firstName forProperty:kABFirstNameProperty];
    }

    if(address.lastName) {
        [person setValue:address.lastName forProperty:kABLastNameProperty];
    }
    
    if(address.email) {
        ABMutableMultiValue *emailValue = [[ABMutableMultiValue alloc] init];
        [emailValue addValue:address.email withLabel:kABEmailWorkLabel];
        
        [person setValue:emailValue forProperty:kABEmailProperty];
    }
    
    ABAddressBook *ab = [ABAddressBook sharedAddressBook];

    if(![ab addRecord:person] || ![ab save]) {
        SM_LOG_ERROR(@"Failed to add / save address '%@' in address book", address.detailedRepresentation);
        return NO;
    }

    SM_LOG_INFO(@"Address '%@' saved to address book", address.detailedRepresentation);

    if(![self findAddress:address uniqueId:uniqueId]) {
        SM_LOG_ERROR(@"Could not find newly added address '%@' in address book", address.detailedRepresentation);
        return NO;
    }
    
    return YES;
}

- (void)openAddressInAddressBook:(NSString*)addressUniqueId edit:(BOOL)edit {
    NSAssert(addressUniqueId, @"addressUniqueId is nil");
    
    NSString *urlString = [NSString stringWithFormat:@"addressbook://%@%@", addressUniqueId, edit? @"?edit" : @""];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

@end
