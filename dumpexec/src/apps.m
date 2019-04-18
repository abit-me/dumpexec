//
//  appinfo.m
//  dumpdecrypted
//
//  Created by A on 2018/7/18.
//  Copyright © 2018年 A. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FBBundleInfo : NSObject
@property (nonatomic, copy) NSString *bundleIdentifier;
@property (nonatomic, copy) NSString *bundleType;
@property (nonatomic, retain) NSURL *bundleURL;
@property (nonatomic, copy) NSString *bundleVersion;
@property (nonatomic, retain) NSUUID *cacheGUID;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSDictionary *extendedInfo;
@property (nonatomic) unsigned int sequenceNumber;
@end

@interface FBApplicationInfo: FBBundleInfo

@property (nonatomic, readonly, retain) NSURL *bundleContainerURL;
@property (nonatomic, readonly, retain) NSArray *customMachServices;
@property (nonatomic, readonly, retain) NSURL *dataContainerURL;
@end

@interface LSResourceProxy : NSObject

@end

@interface LSBundleProxy : LSResourceProxy
@property (nonatomic, readonly) NSString *localizedShortName;
@end


@interface LSApplicationProxy : LSBundleProxy
@property (nonatomic, readonly) NSString *applicationType;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property(readonly) NSURL * dataContainerURL;
@property(readonly) NSURL * bundleContainerURL;
@property(readonly) NSString * localizedShortName;
@property(readonly) NSString * localizedName;
@end

@interface LSApplicationWorkspace : NSObject

+ (id)defaultWorkspace;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
- (id)allApplications;
- (id)allInstalledApplications;
- (BOOL)applicationIsInstalled:(id)arg1;
- (id)applicationsOfType:(unsigned int)arg1;
@end

NSArray *installedAppsProxy()
{
    LSApplicationWorkspace *workspace = [NSClassFromString(@"LSApplicationWorkspace") defaultWorkspace];
    NSArray *proxies = [workspace applicationsOfType:0]; // LSApplicationProxy
    return proxies;
}

NSArray *installedApps()
{
    NSMutableArray *arr = [NSMutableArray new];
    for (LSApplicationProxy *proxy in installedAppsProxy())
    {
        NSDictionary *dic = @{@"name" : [proxy localizedName], @"bundle_id" : [proxy applicationIdentifier]};
        [arr addObject:dic];
    }
    return arr;
}

NSArray *installedAppsInfos()
{
    NSMutableArray *arr = [NSMutableArray new];
    for (LSApplicationProxy *proxy in installedAppsProxy())
    {
        NSDictionary *dic = @{@"bundleID" : [proxy applicationIdentifier], @"appName" : [proxy localizedName],
                              @"bundlePath" : [[proxy bundleContainerURL] path], @"dataPath" : [[proxy dataContainerURL] path]};
        [arr addObject:dic];
    }
    [arr sortUsingComparator:^NSComparisonResult(NSDictionary * obj1, NSDictionary * obj2) {
        NSString *appName1 = [obj1 valueForKey:@"appName"];
        NSString *appName2 = [obj2 valueForKey:@"appName"];
        return [appName1 compare:appName2];
    }];
    return arr;
}
