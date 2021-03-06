//
//  BNRItemStore.m
//  Homepwner
//
//  Created by Ed McPadden on 8/25/14.
//  Copyright (c) 2014 Big Nerd Ranch. All rights reserved.
//

#import "BNRItemStore.h"
#import "BNRItem.h"
#import "BNRImageStore.h"

@import CoreData;

@interface BNRItemStore()

@property (nonatomic) NSMutableArray *privateItems;
@property (nonatomic, strong) NSMutableArray *allAssetTypes;
@property (nonatomic, strong) NSManagedObjectContext *context;
@property (nonatomic, strong) NSManagedObjectModel *model;

@end

@implementation BNRItemStore

+ (instancetype)sharedStore
{
    static BNRItemStore *sharedStore;
    
    if(!sharedStore) {
        sharedStore = [[self alloc] initPrivate];
    }
    
    return sharedStore;
}

- (instancetype)init
{
    [NSException raise:@"Singleton" format:@"Use +[BNRItemStore sharedStore]"];
    return nil;
}

- (instancetype)initPrivate
{
    self = [super init];
    if(self) {
        
        _model = [NSManagedObjectModel mergedModelFromBundles:nil];
        
        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];
        
        NSString *path = self.itemArchivePath;
        NSURL *storeURL = [NSURL fileURLWithPath:path];
        NSError *error;
        if(![psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
            [NSException raise:@"Open Failure" format:[error localizedDescription]];
        }
        
        _context = [[NSManagedObjectContext alloc] init];
        _context.persistentStoreCoordinator = psc;
        
        [self loadAllItems];
    }
    return self;
}

- (void)removeItem:(BNRItem *)item
{
    NSString *key = item.itemKey;
    [[BNRImageStore sharedStore] deleteImageForKey:key];
    [self.context deleteObject:item];
    [self.privateItems removeObjectIdenticalTo:item];
}

- (void)moveItemAtIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex
{
    if(fromIndex == toIndex) {
        return;
    }
    BNRItem *item = self.privateItems[fromIndex];
    [self.privateItems removeObjectAtIndex:fromIndex];
    [self.privateItems insertObject:item atIndex:toIndex];
    
    double lowerBounds = 0.0;
    if(toIndex > 0) {
        lowerBounds = [self.privateItems[(toIndex - 1)] orderingValue];
    }
    else {
        lowerBounds = [self.privateItems[1] orderingValue] - 2.0;
    }
    double upperBounds = 0.0;
    if(toIndex < [self.privateItems count] - 1) {
        upperBounds = [self.privateItems[(toIndex + 1)] orderingValue];
    }
    else {
        upperBounds = [self.privateItems[(toIndex - 1)] orderingValue] + 2.0;
    }
    
    double newOrderValue = (lowerBounds + upperBounds)/2.0;
    
    NSLog(@"moving to order %f", newOrderValue);
    item.orderingValue = newOrderValue;

}

- (BOOL)saveChanges
{
    NSError *error;
    BOOL successful = [self.context save:&error];
    if(!successful) {
        NSLog(@"Error saving: %@", [error localizedDescription]);
    }
    return successful;
}

- (NSArray *)allItems
{
    return [self.privateItems copy];
}

- (NSArray *)allAssetTypes
{
    if(!_allAssetTypes) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *e = [NSEntityDescription entityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        request.entity = e;
        NSError *error;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        if(!result){
            [NSException raise:@"Fetch Failed" format:@"Reason: %@", [error localizedDescription]];
        }
        _allAssetTypes = [result mutableCopy];
    }
    
    if([_allAssetTypes count] == 0) {
        NSManagedObject *type;

        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Furniture" forKey:@"label"];
        [_allAssetTypes addObject:type];
        
        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Jewerly" forKey:@"label"];
        [_allAssetTypes addObject:type];
        
        type = [NSEntityDescription insertNewObjectForEntityForName:@"BNRAssetType" inManagedObjectContext:self.context];
        [type setValue:@"Electronics" forKey:@"label"];
        [_allAssetTypes addObject:type];
    }
    return _allAssetTypes;
}

- (BNRItem *)createItem
{
    double order;
    if([self.allItems count] == 0) {
        order = 1.0;
    }
    else {
        order = [[self.privateItems lastObject] orderingValue] + 1.0;
    }
    NSLog(@"Adding after %lu items, order = %.2f", (unsigned long)[self.privateItems count], order);
    
    BNRItem *item = [NSEntityDescription insertNewObjectForEntityForName:@"BNRItem" inManagedObjectContext:self.context];
    
    item.orderingValue = order;
    
    [self.privateItems addObject:item];
    return item;
}


- (NSString *)itemArchivePath
{
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    NSString *documentDirectory = [documentDirectories firstObject];
    
    return [documentDirectory stringByAppendingPathComponent:@"store.data"];
}

- (void) loadAllItems
{
    if(!self.privateItems) {
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *e = [NSEntityDescription entityForName:@"BNRItem" inManagedObjectContext:self.context];
        request.entity = e;
        NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"orderingValue" ascending:YES];
        
        request.sortDescriptors = @[sd];
        
        NSError *error;
        NSArray *result = [self.context executeFetchRequest:request error:&error];
        if(!result) {
            [NSException raise:@"Fetch Failed" format:@"Reason %@", [error localizedDescription]];
        }
        self.privateItems = [[NSMutableArray alloc] initWithArray:result];
    }
}


@end
