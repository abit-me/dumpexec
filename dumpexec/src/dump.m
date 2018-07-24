//
//  dump.m
//  dumpexec
//
//  Created by A on 2018/7/18.
//  Copyright © 2018年 A. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <sys/wait.h>

int dump_crypted_app(const char * const app_path) {
    
    pid_t pid;
    
    pid = fork();
    if (pid == 0) // child process
    {
        char *const argv[] = {(char *)app_path, NULL};
        char *const envp[] = {"DYLD_INSERT_LIBRARIES=/usr/lib/dumpdecrypted.dylib", NULL};
        int ret = execve(app_path, argv, envp);
        if (ret == -1) {
            perror("[ERRO] execve");
        }
        printf("[INFO] Where is me?\n");
        kill(getpid(), SIGTSTP); // stop
    }
    else if (pid > 0) // father process
    {
        printf("[INFO] Wait for child process to end\n");
        int status;
        pid_t ret = waitpid(pid, &status, WUNTRACED | WCONTINUED);
        printf("[INFO] Child process end status %d\n", status);
        return ret;
    }
    else
    {
        fprintf(stderr, "[ERRO] fork() failed!\n");
    }
    return 0;
}
