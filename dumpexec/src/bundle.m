//
//  bundle.m
//  dumpexec
//
//  Created by A on 2018/7/18.
//  Copyright © 2018年 A. All rights reserved.
//

#import <Foundation/Foundation.h>

// appinfo.m
NSArray *installedAppsInfos(void);

NSString *choosenAppBundlePath()
{
    NSArray *installedApp = installedAppsInfos();
    unsigned long count = (unsigned long)[installedApp count];
    printf("[INFO] Installed apps: %lu\n", count);
    for (int i = 0; i < count; ++i)
    {
        NSDictionary *app = installedApp[i];
        printf("%d:\t%s\t\n", i, [[app valueForKey:@"appName"] UTF8String]);
        // printf("bundleID:   %s\n", [[app valueForKey:@"bundleID"] UTF8String]);
        // printf("bundlePath: %s\n", [[[app valueForKey:@"bundlePath"] absoluteString] UTF8String]);
        // printf("dataPath:   %s\n", [[[app valueForKey:@"dataPath"] absoluteString] UTF8String]);
    }
    
    printf("\n");
    printf("Choose one: ");
    int choose = 0;
    scanf("%d", &choose);
    
    if (choose < 0 || choose > count) {
        printf("[ERRO] wrong choice number \n");
        return nil;
    } else {
        NSURL *bundlePath = [installedApp[choose] valueForKey:@"bundlePath"];
        NSString *bPath = [bundlePath resourceSpecifier];
        return bPath;
    }
    return nil;
}

NSString *infoPlistPathOfBundlePath(NSString *bundlePath)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSDirectoryEnumerator<NSString *> * allItems = [fileMgr enumeratorAtPath:bundlePath];
    for (NSString *item in allItems) {
        if ([item hasSuffix:@".app/Info.plist"]) {
            NSString * fullPath = [bundlePath stringByAppendingPathComponent:item];
            return fullPath;
        }
    }
    return nil;
}

NSString *appPathOfBundlePath(NSString *bundlePath)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSDirectoryEnumerator<NSString *> * allItems = [fileMgr enumeratorAtPath:bundlePath];
    for (NSString *item in allItems) {
        if ([item hasSuffix:@".app"]) {
            NSString * fullPath = [bundlePath stringByAppendingPathComponent:item];
            return fullPath;
        }
    }
    return nil;
}

NSDictionary *infoPlistDictOfBundlePath(NSString *bundlePath)
{
    NSString *infoPlistPath = infoPlistPathOfBundlePath(bundlePath);
    if (infoPlistPath == nil) {
        printf("[ERRO] Get Info.plist path failed\n");
        exit(2);
    }
    BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:bundlePath];
    if (exist == NO) {
        printf("[ERRO] Path %s is nil\n", bundlePath.UTF8String);
        exit(3);
    }
    NSDictionary *dic = [NSDictionary dictionaryWithContentsOfFile:infoPlistPath];
    return dic;
}

// from dumpdecrypted
NSString *getExecutableName() {
    
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"];
}

// from dumpdecrypted
NSString *getDecryptPath()
{
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *exeName = getExecutableName();
    if (exeName) {
        NSString *exePath = [[docPath stringByAppendingPathComponent:@"Decrypt"] stringByAppendingPathComponent:exeName];
        return exePath;
    } else {
        NSString *decryptPath = [docPath stringByAppendingPathComponent:@"Decrypt"];
        return decryptPath;
    }
}

NSString *getExeName(NSString *bundlePath) {

    NSDictionary *infoPlist = infoPlistDictOfBundlePath(bundlePath);
    NSString *exeName = [infoPlist valueForKey:@"CFBundleExecutable"];
    return exeName;
}

NSString *getNewAppBundleIDPath(NSString *bundlePath) {
    
    NSString *decryptPath = getDecryptPath();
    
    NSDictionary *infoPlist = infoPlistDictOfBundlePath(bundlePath);
    NSString *bundleID = [infoPlist valueForKey:@"CFBundleIdentifier"];
    NSString *bundleIDPath = [decryptPath stringByAppendingPathComponent:bundleID];
    return bundleIDPath;
}

NSString *getNewAppPath(NSString *bundlePath)
{
    NSString *decryptPath = getDecryptPath();
    
    NSDictionary *infoPlist = infoPlistDictOfBundlePath(bundlePath);
    NSString *bundleID = [infoPlist valueForKey:@"CFBundleIdentifier"];
    NSString *exeName = [infoPlist valueForKey:@"CFBundleExecutable"];
    
    NSString *bundleIDPath = [decryptPath stringByAppendingPathComponent:bundleID];
    NSString *payloadPath = [bundleIDPath stringByAppendingPathComponent:@"Payload"];
    NSString *appPath = [payloadPath stringByAppendingFormat:@"/%@.app", exeName];
    
    return appPath;
}

void copy_dir(NSString *srcpath, NSString *dstpath)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    if (![fileMgr fileExistsAtPath:srcpath]) { // src path is not exist
        printf("[ERRO] Copy_dir srcpath is not exist \n");
        return;
    }
    
    BOOL isDir = NO;
    if (![fileMgr fileExistsAtPath:dstpath isDirectory:&isDir]) { // dst path is not exist
        NSError *err = nil;
        [fileMgr createDirectoryAtPath:dstpath withIntermediateDirectories:YES attributes:nil error:&err];
        if (err) {
            printf("[ERRO] Copy_dir create dir err: %s \n", err.description.UTF8String);
            return;
        }
    }
    
    if ([fileMgr fileExistsAtPath:dstpath]) {
        NSError *err = nil;
        [fileMgr removeItemAtPath:dstpath error:&err];
        if (err) {
            printf("[ERRO] Copy_dir remove dir err: %s \n", err.description.UTF8String);
            return;
        }
    }
    
    NSError *err = nil;
    [fileMgr copyItemAtPath:srcpath toPath:dstpath error:&err];
    if (err) {
        printf("[ERRO] Copy_dir copy err: %s \n", err.description.UTF8String);
    }
    
    return;
}

int replace_encrypt(NSString *decryptPath, NSString *encryptPath)
{    
    NSString *exeName = [decryptPath componentsSeparatedByString:@"/"].lastObject;
    NSString *decryptExeName = [exeName stringByAppendingString:@".decrypted"];
    if (!decryptExeName) {
        printf("[ERRO] decryptExeName is nil\n");
        return 1;
    }
    
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    for (NSString *decrypt in [fileMgr enumeratorAtPath:decryptPath]) {
        
        if ([decrypt isEqualToString:decryptExeName]) { // copy main exe file
            
            NSString *replaceFrom = [decryptPath stringByAppendingPathComponent:decrypt];
            NSString *replaceTo = [encryptPath stringByAppendingPathComponent:exeName];
            
            NSError *err = nil;
            if ([fileMgr fileExistsAtPath:replaceTo]) {
                [fileMgr removeItemAtPath:replaceTo error:&err];
                if (err) {
                    printf("[ERRO] removeItemAtPath err: %s", err.description.UTF8String);
                    return 2;
                }
            }
            [fileMgr copyItemAtPath:replaceFrom toPath:replaceTo error:&err];
            if (err) {
                printf("[ERRO] copyItemAtPath err: %s", err.description.UTF8String);
                return 3;
            }
        } else { // copy frameworks dylib file
            NSString *replaceFrom = [decryptPath stringByAppendingPathComponent:decrypt];
            NSString *frameworkPath = [encryptPath stringByAppendingPathComponent:@"Frameworks"];
            NSString *decryptFramework = [frameworkPath stringByAppendingPathComponent:decrypt];
            // /var/root/Documents/Decrypt/com.mubu.iosapp/Payload/MubuApp.app/Frameworks/RSKImageCropper.decrypted
            NSUInteger decryptLen = [@".decrypted" length];
            NSUInteger usefulLen = [decryptFramework length] - decryptLen;
            NSRange range = NSMakeRange(0, usefulLen);
            
            // /var/root/Documents/Decrypt/com.mubu.iosapp/Payload/MubuApp.app/Frameworks/RSKImageCropper
            NSString *framework = [decryptFramework substringWithRange:range];
            // /var/root/Documents/Decrypt/com.mubu.iosapp/Payload/MubuApp.app/Frameworks/RSKImageCropper.framework
            framework = [[decryptFramework substringWithRange:range] stringByAppendingString:@".framework"];
            
            NSString *replaceTo = nil;
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:[framework stringByAppendingPathComponent:@"Info.plist"]];
            NSString *frameworkBinName = [dict valueForKey:@"CFBundleExecutable"];
            if (frameworkBinName) {
                replaceTo = [framework stringByAppendingPathComponent:frameworkBinName];
            } else {
                replaceTo = [framework stringByAppendingPathComponent:[framework componentsSeparatedByString:@"/"].lastObject];
            }
            
            NSError *err = nil;
            if ([fileMgr fileExistsAtPath:replaceTo]) {
                [fileMgr removeItemAtPath:replaceTo error:&err];
                if (err) {
                    printf("[ERRO] removeItemAtPath err: %s", err.description.UTF8String);
                    return 4;
                }
            }
            [fileMgr copyItemAtPath:replaceFrom toPath:replaceTo error:&err];
            if (err) {
                printf("[ERRO] copyItemAtPath err: %s", err.description.UTF8String);
                return 5;
            }
        }
    }
    return 0;
}
