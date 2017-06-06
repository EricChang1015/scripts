1. create a dedicated user for Wekan:
~~~
sudo useradd -d /home/wekan -m -s /bin/bash wekan
~~~

2. Add this user to the docker group
~~~
sudo usermod -aG docker wekan
~~~