#!/usr/bin/env bash

./build_exec.sh
ldid -S bin/universal/dumpexec
scp bin/universal/dumpexec root@192.168.1.241:/usr/bin/

