#!/bin/bash

IP=192.168.2.242

# cd dumpdecrypted
# ./build_dylib.sh
# cd ..
# cp dumpdecrypted/bin/universal/dumpdecrypted.dylib package/usr/lib

cd dumpexec
./build_exec.sh
cd ..
cp dumpexec/bin/universal/dumpexec package/usr/bin

# jtool --sign -arch armv7 package/usr/lib/dumpdecrypted.dylib
# jtool --sign -arch arm64 --inplace package/usr/lib/dumpdecrypted.dylib
# jtool --sign -arch arm64 --inplace package/usr/bin/dumpexec
ldid -Sent.plist package/usr/lib/dumpdecrypted.dylib
ldid -Sent.plist package/usr/bin/dumpexec
sudo find ./ -name ".DS_Store" -depth -exec rm {} \;
dpkg-deb -Zgzip -b package dumpexec.deb

scp dumpexec.deb root@$IP:/var/root
ssh root@$IP dpkg -i /var/root/dumpexec.deb
