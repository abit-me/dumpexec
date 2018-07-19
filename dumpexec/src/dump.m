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
        //printf("this is child process, pid is %d\n", getpid()); // getpid返回的是当前进程的PID
        
        char *const _argv[] = {(char *)app_path, NULL};
        char *const _envp[] = {"DYLD_INSERT_LIBRARIES=/usr/lib/dumpdecrypted.dylib", NULL};
        int ret = execve(app_path, _argv, _envp);
        //printf("ret: %d\n", ret);
        if (ret == -1) {
            perror("execve");
        }
        //printf("where is me?\n");
        kill(getpid(), SIGTSTP);
    }
    else if (pid > 0) // father process
    {
        //printf("this is father process, pid is %d\n", getpid());
        
        //printf("child process starts %d\n", pid);
        //printf("wait for child process to end\n" );
        int status;
        pid_t ret = waitpid(pid, &status, WUNTRACED | WCONTINUED);
        //printf("child process end status %d\n", status);
        //printf("child process end pid %d\n", ret);
        return ret;
    }
    else
    {
        fprintf(stderr,"ERROR:fork() failed!\n");
    }
    return 0;
}
