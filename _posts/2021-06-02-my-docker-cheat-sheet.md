---
layout: post
title: My Docker Cheat Sheet
date: 2023-06-03 16:08 -0400
categories: [Cheat Sheet]
tags: [docker, cheat sheet, containers]
---

This is my docker cheat sheet. There are many like it, but this one is mine.

I'm not about to teach anyone anything that they can't find on [Docker docs](https://docs.docker.com/), in fact that's probably where you should go if you don't know much about Docker. But this is a publicized version of what I have in my notes that I use as a go-to when I can't remember how I ran that one command I ran a few months ago on that host that...man I can't even remember the name of the host. Crap, did I dream this or something?

## The Basics

### List containers
```sh
docker ps
```

### List currently running AND stopped containers
```sh
docker ps -a
```

### Stop a running container
```sh
docker stop <container_id>
```
You only need to enter a few characters of the container ID as Docker will figure out which container you mean if there are no other containers that start with the same characters.

### Delete a Container
```sh
docker rm <container_id>
```
You can list multiple container IDs here, separated by spaces.


### Delete all non-running containers
```sh
docker container prune
```
Sometimes you just have to blow it all away and pick up the pieces afterwards.

### Nuke Everything (but currently-running containers)
```sh
docker system prune -a
```
Some people just like to watch the world burn. Note that this won't kill currently-running containers. This will however remove containers and images.

### List Images
```sh
docker image ls
```

### Get logs
```sh
docker logs <container_id>
``` 
You can also specify only some logs from the end:

```sh
docker logs -n 20 <container_id>
```

### To Run a shell inside an ubuntu container
```sh
docker run -it --rm ubuntu /bin/bash
```
The `-it` flags stand for "interactive" and "tty", so will allow you to interact with the `/bin/bash` command.
The `--rm` flag will delete the container when the process ends. Good for testing things out without messing up your system.

### To share a directory on your host machine with your ubuntu container
```sh
docker run -it --rm -v $PWD/my_work:/mnt/my_work ubuntu /bin/bash
```
The directory will be accessible from `/mnt/my_work` inside the container. Note the use of `$PWD`. This is because the `-v` flag needs a full path, not a relative one. The use of the `$PWD` environment variable is a useful compromise.

### To daemonize a docker container
```sh
docker run -d my_image
```
The `-d` flag will run this container detached and in the background. This assumes the container has a defined entrypoint or default command.

### To expose the host's port 1337 to the container's port 8000
```sh
docker run -it --rm -p 1337:8000 ubuntu /bin/bash
```
Note that this will still run this interactively. Remove the `-it` flag and add a `-d` flag, and probably change `/bin/bash` to the process you want to run.

### Build an image from a Dockerfile
```sh
docker build /path/to/Dockerfile -t my_tag_name
```
If the Dockerfile is in the current working directory, you can replace `/path/to/Dockerfile` with just a `.` without referencing the Dockerfile, as it is implied.

## Example Dockerfile
```Dockerfile
FROM ubuntu:focal
# Always start with a FROM line. Generally shouldn't use :latest
# because a newer version may not be compatible with your app

LABEL maintainer "Baba O'Reilly <my_email@example.com>"
# This is metadata for the image, doesn't alter execution

RUN apt-get update && apt-get -y install abc xyz
# Always apt-get update && apt-get -y install on the same line, never
# separate these into two separate run commands! And don't apt-get upgrade!

WORKDIR /app
# Not only creates the /app dir in the container, but also cd's into that
# directory and makes it the current working directory from this point on

COPY app/ .
# Copy the host's ./app/ dir into /app on the container, since WORKDIR was run

COPY bootstrap.sh /
# Copy a boot strapper file into the root partition of the container

RUN /bootstrap.sh
# Execute the bootstrap script, this usually should contain things like
# shell commands to set up the environment.

EXPOSE 8000
# Metadata for the image, informing the caller that something will
# listen on port 8000 in the container and to port-forward appropriately

ENTRYPOINT ["/app/myapp.sh", "-D", "8000"]
# How the container should run when started

# OR

CMD ["/app/myapp.sh", "-D", "8000"]
# The default command the container should run
```

## Docker-Compose
For situations that call for multiple docker containers to work together to create one particular app (or really even just a way to wrangle all your docker containers), `docker-compose` is a fantastic tool to handle this. With a single file, you can define how containers should run, and it even handles the network linking behind the scenes for you, and it does it in plain english. Hopefully you like YAML, because despite the fact that YAML is easy to read, it is one of the most finicky config file formats I've ever had the pleasure of dealing with. But hey, to each their own.

```yaml
version: '3.3'

services:
    db:
        image: mysql:5.7
        volumes:
            - "db_data:/var/lib/mysql"
        restart: "always"
        networks:
            - dbnet
        environment:
            MYSQL_ROOT_PASSWORD: "Password123"
            MYSQL_DATABASE: "my_awesome_database"
            MYSQL_USER: "agr0"
            MYSQL_PASSWORD: "letmein"

    mywebsite:
        container_name: "mywebsite"
        build: "./mywebsite"
        expose:
            - 80
            - 443
        restart: "unless-stopped"
        networks:
            - webnet
            - dbnet
        volumes:
            - "./mywebsite/apache2:/etc/apache2"
        depends_on:
            - db

    yourawesomewebsite:
        container_name: "yourawesomewebsite"
        build: "./yourawesomewebsite"
        expose:
            - 80
            - 443
        restart: "unless-stopped"
        networks:
            - webnet
        volumes:
            - "./yourawesomewebsite/www:/var/www/html"

    revproxy:
        image: nginx
        expose:
            - 80
            - 443
        restart: "always"
        networks:
            - webnet
        ports:
            - "80:80"
            - "443:443"
        volumes:
            - "./nginx/conf:/etc/nginx"
            - "./nginx/ssl:/etc/ssl/certs"
        depends_on:
            - mywebsite
            - yourawesomewebsite

volumes:
    db_data: {}

networks:
    dbnet: {}
    webnet: {}
```

This has a lot to unpack here, but I will try to explain what's going on in the above.

 - There are 4 separate docker containers running.
 - Two of them are web servers.
 - One of them (`mywebsite`) has an application that requires access to the database container.
 - One container is a reverse proxy, which listens on the host's port 80 and port 443.
 - The `db` container is only accessible to `mywebsite`. 
 - The `db` container has a named volume, which is only accessible to the `db` container and remains persistent.
 - The reverse proxy expects the two websites to be running before it starts, and the `mywebsite` expects the `db` container to be up before it starts.
 - `mywebsite` and `yourawesomewebsite` both have associated Dockerfiles and must be built locally. `revproxy` and `db` are both images which will be pulled from the Docker Hub.

### To build this entire Docker cluster
```sh
docker-compose build
```

### To specify a particular config file, use:
```sh
docker-compose -f /path/to/docker-compose.yml build
```

### To start this cluster
```sh
docker-compose up -d
```
To start this in foreground and see the output of every single container in your buffer, remove the `-d` flag.

### To stop this cluster
```sh
docker-compose down
```

### Get status of cluster
```sh
docker-compose ps
```

### Spawn shell on service
```sh
docker-compose exec mywebsite /bin/bash
```
No need to specify `-it`, this is implied.

### Get logs of service in cluster
```sh
docker-compose logs --tail=50 mywebsite
```

### To rebuild from scratch and start entire cluster
```sh
docker-compose up -d --build --force-recreate
```
`--force-recreate` will rebuild all the containers *even if there have been no changes to the image.* You can perform the same on just one particular service by naming it at the end:

```sh
docker-compose up -d --build --force-recreate mywebsite
```

### Restart cluster
```sh
docker-compose restart
```
BE WARNED! If you make a change to `docker-compose.yml`, they will not be reflected when restarting!