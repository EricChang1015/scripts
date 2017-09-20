# add AWS volume
## create volume and attach to instance
## edit in server
###View available disk devices and the file system on 2nd disk.
~~~
$ lsblk
$ sudo file -s /dev/xvdf
~~~
### Format 2nd disk if the ¡§sudo file -s /dev/xvdb¡¨ return ¡§data¡¨
~~~
$ sudo mkfs -t ext4 /dev/xvdf
~~~
### Mount/unmount disk
~~~
$ sudo mkdir /data
$ sudo mount /dev/xvdf /data
~~~
### Mount this EBS volume on every system reboot
~~~
$ sudo vi /etc/fstab
~~~
### Add a new line to the end of the file
~~~
/dev/xvdf               /data    ext4   defaults,nofail         0 2
~~~
### Reboot
~~~
$ sudo reboot
~~~
