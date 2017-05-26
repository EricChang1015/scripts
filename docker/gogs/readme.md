

1. How to start at first time
~~~
docker-compose up -d 
~~~
- plz notice that in the install mode port should use inner port.



2. How to upgrade gogs
~~~
docker-compose down
sed "s/gogs:0.11.4/gogs:x.xx.x/g" docker-compose.yml -i
docker-compose volume ls -q | xargs docker volume rm
docker-compose up -d
~~~

