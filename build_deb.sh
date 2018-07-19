#!/bin/bash

cd dumpdecrypted
./build_dylib.sh
cd ..

cd dumpexec
./build_exec.sh
cd ..

cp dumpdecrypted/bin/universal/dumpdecrypted.dylib package/usr/lib
cp dumpexec/bin/universal/dumpexec package/usr/bin
ldid -S package/usr/lib/dumpdecrypted.dylib
ldid -S package/usr/bin/dumpexec
sudo find ./ -name ".DS_Store" -depth -exec rm {} \;
dpkg-deb -Zgzip -b package dumpexec.deb

scp dumpexec.deb root@192.168.1.254:/var/root