#!/bin/bash

# cd dumpdecrypted
# ./build_dylib.sh
# cd ..

# cd dumpexec
# ./build_exec.sh
# cd ..

# cp dumpdecrypted/bin/universal/dumpdecrypted.dylib package/usr/lib
# cp dumpexec/bin/universal/dumpexec package/usr/bin
# jtool --sign -arch armv7 package/usr/lib/dumpdecrypted.dylib
# jtool --sign -arch arm64 --inplace package/usr/lib/dumpdecrypted.dylib
# jtool --sign -arch arm64 --inplace package/usr/bin/dumpexec
ldid -Sent.plist package/usr/lib/dumpdecrypted.dylib
ldid -Sent.plist package/usr/bin/dumpexec
sudo find ./ -name ".DS_Store" -depth -exec rm {} \;
dpkg-deb -Zgzip -b package dumpexec.deb

scp dumpexec.deb root@192.168.2.131:/var/root
