//
//  ipa.m
//  dumpexec
//
//  Created by A on 2018/7/18.
//  Copyright © 2018年 A. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "../lib/ZipZap/include/ZipZap.h"

void zip(NSString *respath, NSString *despath)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    if ([fileMgr fileExistsAtPath:despath]) {
        NSError *err = nil;
        [fileMgr removeItemAtPath:despath error:&err];
        if (err) {
            printf("[ERRO] zip rm file error: %s\n", err.description.UTF8String);
        }
    }
    
    ZZArchive* newArchive = [[ZZArchive alloc] initWithURL:[NSURL fileURLWithPath:despath]
                                                   options:@{ZZOpenOptionsCreateIfMissingKey : @YES}
                                                     error:nil];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *subPaths = [fileManager subpathsAtPath:respath];
    
    NSMutableArray<ZZArchiveEntry *> *entries = [NSMutableArray new];
    
    for(NSString *subPath in subPaths) {
        
        NSString *fullPath = [respath stringByAppendingPathComponent:subPath];
        
        BOOL isDir;
        if([fileManager fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir) // 只处理文件
        {
            ZZArchiveEntry *entry = [ZZArchiveEntry archiveEntryWithFileName:subPath
                                                                    compress:YES
                                                                   dataBlock:^(NSError** error)
                                     {
                                         return [NSData dataWithContentsOfFile:fullPath];
                                     }];
            
            [entries addObject:entry];
        }
    }
    
    NSError *err = nil;
    [newArchive updateEntries:entries error:&err];
    if (err) {
        printf("[ERRO] updateEntries err: %s\n", err.description.UTF8String);
    }
}

/*
#include <zlib.h>

#define kZlibErrorDomain @"ZlibErrorDomain"
#define kGZipInitialBufferSize (256 * 1024)

#if !defined(GWS_DCHECK) || !defined(GWS_DNOT_REACHED)

    #if DEBUG

    #define GWS_DCHECK(__CONDITION__)   \
        do {                            \
            if (!(__CONDITION__)) {     \
            abort();                    \
        }                               \
    } while (0)
    #define GWS_DNOT_REACHED() abort()

    #else

    #define GWS_DCHECK(__CONDITION__)
    #define GWS_DNOT_REACHED()

    #endif

#endif

z_stream _stream;
BOOL _finished;

BOOL zip_open(NSError ** error)
{
    int result = deflateInit2(&_stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);
    if (result != Z_OK) {
        if (error) {
            *error = [NSError errorWithDomain:kZlibErrorDomain code:result userInfo:nil];
        }
        deflateEnd(&_stream);
        return NO;
    }
    return YES;
}

NSData * readData(NSData *data, NSError ** error)
{
    NSMutableData* encodedData;
    if (_finished) {
        encodedData = [[NSMutableData alloc] init];
    } else {
        encodedData = [[NSMutableData alloc] initWithLength:kGZipInitialBufferSize];
        if (encodedData == nil) {
            GWS_DNOT_REACHED();
            return nil;
        }
        NSUInteger length = 0;
        do {
            if (data == nil) {
                return nil;
            }
            _stream.next_in = (Bytef*)data.bytes;
            _stream.avail_in = (uInt)data.length;
            while (1) {
                NSUInteger maxLength = encodedData.length - length;
                _stream.next_out = (Bytef*)((char*)encodedData.mutableBytes + length);
                _stream.avail_out = (uInt)maxLength;
                int result = deflate(&_stream, data.length ? Z_NO_FLUSH : Z_FINISH);
                if (result == Z_STREAM_END) {
                    _finished = YES;
                } else if (result != Z_OK) {
                    if (error) {
                        *error = [NSError errorWithDomain:kZlibErrorDomain code:result userInfo:nil];
                    }
                    return nil;
                }
                length += maxLength - _stream.avail_out;
                if (_stream.avail_out > 0) {
                    break;
                }
                encodedData.length = 2 * encodedData.length;  // zlib has used all the output buffer so resize it and try again in case more data is available
            }
            GWS_DCHECK(_stream.avail_in == 0);
        } while (length == 0);  // Make sure we don't return an empty NSData if not in finished state
        encodedData.length = length;
    }
    return encodedData;
}

void zip_close()
{
    deflateEnd(&_stream);
}

//压缩
NSData *gzipDeflate(NSData * data)
{
    if ([data length] == 0) return data;
    
    z_stream strm;
    
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)[data bytes];
    strm.avail_in = (uInt)[data length];
    
    // Compresssion Levels:
    //   Z_NO_COMPRESSION
    //   Z_BEST_SPEED
    //   Z_BEST_COMPRESSION
    //   Z_DEFAULT_COMPRESSION
    
    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) return nil;
    
    NSMutableData *compressed = [NSMutableData dataWithLength:16384];  // 16K chunks for expansion
    
    do {
        
        if (strm.total_out >= [compressed length])
            [compressed increaseLengthBy: 16384];
        
        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([compressed length] - strm.total_out);
        
        deflate(&strm, Z_FINISH);
        
    } while (strm.avail_out == 0);
    
    deflateEnd(&strm);
    
    [compressed setLength: strm.total_out];
    return [NSData dataWithData:compressed];
}

//解压缩
NSData *gzipInflate(NSData * data)
{
    if ([data length] == 0) return data;
    
    unsigned long full_length = [data length];
    unsigned long  half_length = [data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = (uInt)[data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit2(&strm, (15+32)) != Z_OK)
        return nil;
    
    while (!done)
    {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END)
            done = YES;
        else if (status != Z_OK)
            break;
    }
    if (inflateEnd (&strm) != Z_OK)
        return nil;
    
    // Set real length.
    if (done)
    {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}

void doZipAtPath(NSString * sourcePath, NSString *destZipFile)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
//    ZipArchive * zipArchive = [ZipArchive new];
//    [zipArchive CreateZipFile2:destZipFile];
    NSArray *subPaths = [fileManager subpathsAtPath:sourcePath];// 关键是subpathsAtPath方法
    for(NSString *subPath in subPaths){
        NSString *fullPath = [sourcePath stringByAppendingPathComponent:subPath];
        BOOL isDir;
        if([fileManager fileExistsAtPath:fullPath isDirectory:&isDir] && !isDir)// 只处理文件
        {
            //[zipArchive addFileToZip:fullPath newname:subPath];
        }
    }
    //[zipArchive CloseZipFile2];
}
*/
