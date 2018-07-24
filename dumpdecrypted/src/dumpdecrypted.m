// Refer to https://github.com/stefanesser/dumpdecrypted

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#if 1
#define logger(argv, format...) printf(argv, ##format)
#else
#define (argv, format...)
#endif

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <dlfcn.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <Foundation/Foundation.h>
#include <sys/stat.h>

#define swap32(value) (((value & 0xFF000000) >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24) )

NSString *getDecryptPath(void);
NSString *getExecutableName(void);
void create_dump_dir(void);
int dumptofile(const char *path, const struct mach_header *mh);
void image_added(const struct mach_header *mh, intptr_t slide);

//typedef enum : int {
//    dc_success = 0,
//    dc_file_open,
//} dump_code;

int dumptofile(const char *path, const struct mach_header *mh) {
    
    struct load_command *lc;
    struct encryption_info_command *eic;
    struct fat_header *fh;
    struct fat_arch *arch;
    char buffer[1024];
    char rpath[4096], npath[4096]; /* should be big enough for PATH_MAX */
    unsigned int fileoffs = 0;
    off_t off_cryptid = 0;
    off_t restsize = 0;
    int i, fd, outfd;
    size_t n = 0;
    size_t r = 0;
    size_t toread = 0;
    char *tmp;
    
    if (realpath(path, rpath) == NULL) {
        strlcpy(rpath, path, sizeof(rpath));
    }
    
    /* extract basename */
    tmp = strrchr(rpath, '/');
    
    if (tmp == NULL) {
        printf("[ERRO] Unexpected error with filename.\n");
        return 1;
    } else {
        printf("[INFO] Dumping %s\n", tmp+1);
    }
    
    /* detect if this is a arm64 binary */
    if (mh->magic == MH_MAGIC_64) { // 64bit ARM
        lc = (struct load_command *)((unsigned char *)mh + sizeof(struct mach_header_64));
    } else { /* we might want to check for other errors here, too */
        lc = (struct load_command *)((unsigned char *)mh + sizeof(struct mach_header));
    }
    
    /* searching all load commands for an LC_ENCRYPTION_INFO load command */
    for (i = 0; i < mh->ncmds; i++) {
        //printf("[INFO] Load Command (%d): %08x\n", i, lc->cmd);
        
        if (lc->cmd == LC_ENCRYPTION_INFO || lc->cmd == LC_ENCRYPTION_INFO_64) {
            eic = (struct encryption_info_command *)lc;
            
            /* If this load command is present, but data is not crypted then exit */
            if (eic->cryptid == 0) {
                break;
            }
            off_cryptid = (off_t)((void*)&eic->cryptid - (void*)mh);
            
            fd = open(rpath, O_RDONLY);
            if (fd == -1) {
                printf("[ERRO] Failed opening.\n");
                return 2;
            }
            
            // Reading header
            n = read(fd, (void *)buffer, sizeof(buffer));
            if (n != sizeof(buffer)) {
                printf("[WARN] Warning read only %ld bytes\n", n);
            }
            
            // Detecting header type
            fh = (struct fat_header *)buffer;
            
            /* Is this a FAT file - we assume the right endianess */
            if (fh->magic == FAT_CIGAM) {
                // Executable is a FAT image - searching for right architecture
                arch = (struct fat_arch *)&fh[1];
                for (i = 0; i < swap32(fh->nfat_arch); i++) {
                    if ((mh->cputype == swap32(arch->cputype)) && (mh->cpusubtype == swap32(arch->cpusubtype))) {
                        fileoffs = swap32(arch->offset);
                        break;
                    }
                    arch++;
                }
                if (fileoffs == 0) {
                    return 3;
                }
            } else if (fh->magic == MH_MAGIC || fh->magic == MH_MAGIC_64) {
                //printf("[INFO] Executable is a plain MACH-O image\n");
            } else {
                printf("[ERRO] Executable is of unknown type\n");
                return 4;
            }
            
            NSString *decryptPath = getDecryptPath();
            
            strlcpy(npath, decryptPath.UTF8String, sizeof(npath));
            strlcat(npath, tmp, sizeof(npath));
            strlcat(npath, ".decrypted", sizeof(npath));
            strlcpy(buffer, npath, sizeof(buffer));
            
            outfd = open(npath, O_RDWR|O_CREAT|O_TRUNC, 0644);
            if (outfd == -1) {
                if (strncmp("/private/var/mobile/Applications/", rpath, 33) == 0) {
                    printf("[ERRO] Failed opening. Most probably a sandbox issue. Trying something different.\n");
                    
                    /* create new name */
                    strlcpy(npath, "/private/var/mobile/Applications/", sizeof(npath));
                    tmp = strchr(rpath+33, '/');
                    if (tmp == NULL) {
                        printf("[ERRO] Unexpected error with filename.\n");
                        return 5;
                    }
                    tmp++;
                    *tmp++ = 0;
                    strlcat(npath, rpath+33, sizeof(npath));
                    strlcat(npath, "tmp/", sizeof(npath));
                    strlcat(npath, buffer, sizeof(npath));
                    outfd = open(npath, O_RDWR|O_CREAT|O_TRUNC, 0644);
                }
                if (outfd == -1) {
                    printf("[ERRO] Failed opening\n");
                    return 6;
                }
            }
            
            /* calculate address of beginning of crypted data */
            n = fileoffs + eic->cryptoff;
            
            restsize = lseek(fd, 0, SEEK_END) - n - eic->cryptsize;
            lseek(fd, 0, SEEK_SET);
            
            /* first copy all the data before the encrypted data */
            while (n > 0) {
                toread = (n > sizeof(buffer)) ? sizeof(buffer) : n;
                r = read(fd, buffer, toread);
                if (r != toread) {
                    printf("[ERRO] Error reading file\n");
                    return 7;
                }
                n -= r;
                
                r = write(outfd, buffer, toread);
                if (r != toread) {
                    printf("[ERRO] Error writing file\n");
                    return 8;
                }
            }
            
            /* now write the previously encrypted data */
            r = write(outfd, (unsigned char *)mh + eic->cryptoff, eic->cryptsize);
            if (r != eic->cryptsize) {
                printf("[ERRO] Error writing file\n");
                return 9;
            }
            
            /* and finish with the remainder of the file */
            n = (size_t)restsize;
            lseek(fd, eic->cryptsize, SEEK_CUR);
            while (n > 0) {
                toread = (n > sizeof(buffer)) ? sizeof(buffer) : n;
                r = read(fd, buffer, toread);
                if (r != toread) {
                    printf("[ERRO] Error reading file\n");
                    return 10;
                }
                n -= r;
                
                r = write(outfd, buffer, toread);
                if (r != toread) {
                    printf("[ERRO] Error writing file\n");
                    return 11;
                }
            }
            
            if (off_cryptid) {
                uint32_t zero = 0;
                off_cryptid+=fileoffs;
                if (lseek(outfd, off_cryptid, SEEK_SET) != off_cryptid || write(outfd, &zero, 4) != 4) {
                    printf("[ERRO] Error writing cryptid value\n");
                }
            }
            
            close(fd);
            close(outfd);
            
            return 0;
        } else {
            lc = (struct load_command *)((unsigned char *)lc+lc->cmdsize);
            continue;
        }
    }
    printf("[WARN] This mach-o file is not encrypted. Nothing was decrypted.\n");
    return 1024;
}

void image_added(const struct mach_header *mh, intptr_t slide) {
    
    Dl_info image_info;
    int result = dladdr(mh, &image_info);
    if (result == 0) {
        printf("[ERRO] image not found\n");
        return;
    }
    NSString *image = [NSString stringWithUTF8String:image_info.dli_fname];
    
    if ([image hasPrefix:@"/usr/lib/"]
        || [image hasPrefix:@"/System/Library/Frameworks/"]
        || [image hasPrefix:@"/System/Library/PrivateFrameworks/"]) {
        return;
    } else {
        dumptofile(image_info.dli_fname, mh);
    }
}

NSString *getExecutableName() {
    
    return [[NSBundle mainBundle] infoDictionary][@"CFBundleExecutable"];
}

NSString *getDecryptPath() {
    
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

void create_dump_dir() {
    
    NSString *dPath = getDecryptPath();
    NSError *err = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:dPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&err];
    if (err) {
        printf("[ERRO] create_dump_dir err: %s \n", err.description.UTF8String);
    }
}

__attribute__((constructor))
static void dumpexecutable() {
    create_dump_dir();
    _dyld_register_func_for_add_image(&image_added);
}
