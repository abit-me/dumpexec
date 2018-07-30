# dumpexec

- (Mac) ./build_deb.sh
- (Mac) scp dumpexec.deb root@192.168.x.x:/var/root
- (Mac) ssh root@192.168.x.x
- (iDev) dpkg -i dumpexec.deb
- (iDev) dumpexec
- (iDev) choose one app to decrypt
- (iDev) the result ipa is in the /var/root/Documents/Decrypt/YouAppBundleID/YouAppExeName.ipa
- (Mac) scp root@192.168.x.x:/var/root/Documents/Decrypt/YouAppBundleID/YouAppExeName.ipa .
