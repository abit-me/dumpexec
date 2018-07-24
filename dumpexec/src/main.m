//
//  main.m
//  dumpdecrypted
//
//  Created by A on 2018/7/18.
//  Copyright © 2018年 A. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <unistd.h>

// applaunch.m
void launch(const char *bunldeID);

// bundle.m
NSString *choosenAppBundlePath(void);
NSString *infoPlistPathOfBundlePath(NSString *bundlePath);
NSString *appPathOfBundlePath(NSString *bundlePath);
NSString *getDecryptPath(void);
NSString *getNewAppPath(NSString *bundlePath);
NSString *getNewAppBundleIDPath(NSString *bundlePath);
NSDictionary *infoPlistDictOfBundlePath(NSString *bundlePath);
void copy_dir(NSString *srcpath, NSString *dstpath);
void copyFileFromPath(NSString *sourcePath, NSString *toPath);
int replace_encrypt(NSString *decryptPath, NSString *encryptPath);

// ipa.m
void zip(NSString *respath, NSString *despath);

// dump.m
int dump_crypted_app(const char * const app_path);

int main(int argc, char * argv[], char ** envp)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];

    if ([fileMgr fileExistsAtPath:@"/usr/lib/dumpdecrypted.dylib"] == NO) {
        printf("[ERRO] /usr/lib/dumpdecrypted.dylib not exist\n");
        return 2;
    }
    NSString *path = choosenAppBundlePath();
    if (path == nil) {
        printf("[ERRO] Path is nil\n");
        return 3;
    }
    
    NSDictionary *infoPlist = infoPlistDictOfBundlePath(path);
    NSString *exeName = [infoPlist valueForKey:@"CFBundleExecutable"];
    NSString *appPath = appPathOfBundlePath(path);
    NSString *fullExePath = [appPath stringByAppendingPathComponent:exeName];

    NSString *newAppPath = getNewAppPath(path);
    printf("\n");
    printf("[INFO] Copying ...\n");
    copy_dir(appPath, newAppPath);
    
    const char *const fp = (const char *const)fullExePath.UTF8String;
    int dump_ret = dump_crypted_app(fp);
    if (dump_ret == -1) {
        printf("[ERRO] Child process end failed\n");
    } else {
        NSString *appDecryptPath = [getDecryptPath() stringByAppendingPathComponent:exeName];
        int replace_ret = replace_encrypt(appDecryptPath, newAppPath);
        if (replace_ret == 0) {
            NSString *bundleIDPath = getNewAppBundleIDPath(path);
            NSString *ipaPath = [bundleIDPath stringByAppendingFormat:@"/%@.ipa", exeName];
            printf("\n");
            printf("[INFO] Zipping ...\n");
            zip(bundleIDPath, ipaPath);
            printf("\n");
            printf("[INFO] Create ipa at: %s\n", ipaPath.UTF8String);
        }
    }
    
    return 0;
}
