---
title: "How to build a KISS, dockerized infra with CI/CD in 3 hours"
date: 2020-03-08T00:45:19Z
draft: false
toc: false
images:
tags:
  - untagged
---

Hello friend! Welcome to this new infra blog.

If you're here you're probably wondering how I built such an awesome website
and it you are not you're probably asking yourself how I can pretend to have
built it in days with a the backend infra.

Well it's simple: I'm *lazy* and a bit *cheap*... so I use tools for lazy people
and pay only for the necessary. Also I don't care for security.
Also before you start complaning: this is not a tutorial, it's mostly a
show-off of what I did in the week-end, because I'm bored, with memes.

As you are probably as lazy and busy as myself let me walk you through how I
built this awesome **integrated, dockerized, auto-deployed** website in the most
concise way.

On this non-tutorial I assume that you already know about:

* linux
* ssh
* git
* a bit about docker, but just about
* OVH, scaleway or any domain name and cloud provider

## Step 1: Buy a server and a domain name
{{< img style="float: right" src="https://i.imgflip.com/1x1twg.jpg" >}}
I won't lie to you... you'll need a server anyway if you want to be connected
to the interconnected web of the wide world.

My current cloud provider is **[Scaleway](https://scaleway.com)** and I like
them because I can pop an ubuntu VM for 3€/months.

But as long as you have an SSH connection and docker installed your good to go,
then you can use AWS, OVH, or even Google Cloud... That's you're problem

Along with this server you'll want a domain name. [OVH](https://ovh.com) is
probably the simplest one to start with. You'll need to point the domain to
your newly created server above.

## Step 2: Go HuGo!
Hugo is definitely the fastest thing I ever used to build a website, and god I
built a lot... Like almost 3. But to be fair it took me 10 minutes to get
started and have something.

So now locally on your dev machine you can follow the [quickstart guide](https://gohugo.io/getting-started/quick-start/)

Don't forget that you can choose from various themes available [here](https://themes.gohugo.io/)

{{< img style="float: left" src="https://lh3.googleusercontent.com/proxy/EyanFzS97WcvY_RrfyARcZ8Jm9h4SETBbyL2cFNAp8uedb6fSArdRbbfsG7udelwHdB8KuYqJQYgEnziWNOLIGDTukS_cmBo8Erg4s-PMacdSnsli-Bb1SBwwxKNaZPaEeKmJU41vSQTMqkwN1VJNWHmoZNDlkqwnhI" >}}
## Step 3: Integration!

Now you should have a local git repository with a website working locally.
The idea would be to **integrate** all this in some remote git server which
offers a CD/CI pipeline for free. Well, hum, ah, it just seems like we are
talking about [Gitlab](gitlab.com) here so go and create your account right
away if you already haven't!

Then you'll be able to create a new project and `git remote add` the new
project remote

Now let's talk about CI!
You'll need to create a .gitlab-ci.yml file that will be read by Gitlab to
build you project.
Just use the following template:
```yml
build:
  image: docker:19.03.1
  stage: build
  services:
    - docker:19.03.1-dind
  variables:
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: "/certs"
    GIT_SUBMODULE_STRATEGY: recursive
    IMAGE_NAME: <Image-name-you-want>
    SERVER_URL: <server-url.com>
    SSH:      ssh -o StrictHostKeyChecking=no root@$SERVER_IP
  script:
    - apk add openssh
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
    - docker build -t $DOCKER_USERNAME/$IMAGE_NAME:latest .
    - docker push     $DOCKER_USERNAME/$IMAGE_NAME:latest
    - eval $(ssh-agent)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - $SSH docker pull $DOCKER_USERNAME/$IMAGE_NAME
    - $SSH "docker rm -f $IMAGE_NAME || true"
    - $SSH docker run -i -d --restart=always --name $IMAGE_NAME -p 8001:443
      $DOCKER_USERNAME/$IMAGE_NAME hugo server -w --bind=0.0.0.0 --port 443
      --baseURL https://$SERVER_URL/
```

This yaml will do 3 things:

1. Build a docker image with your code
2. Push it to docker hub
3. Pull it from your remote server and start it

In order to build the image `docker build` will need a small dockerfile with
hugo installed. Thanksfully the internet if full of theses:
```
FROM jguyomard/hugo-builder

# Adding config
ADD . /src
```
just add a `Dockerfile` file at the root of you're project with this inside.

# Step 4: Putting up pieces together

Now before going further with gitlab you'll need to create [dockerhub](https://hub.docker.com/)
account. Theses are free if you don't need you're images to be private.

Now you'll need to define a few variables in Gitlab under:
**Settings -> CI/CD -> Variables**

* CI_REGISTRY_USER: your docker hub user
* CI_REGISTRY_PASSWORD: your docker hub password (don't forget to mask and
  protect the value)
* SERVER_IP: the ip of the remote server
* SSH_PRIVATE_KEY: the private key used to ssh to the remote server


**Post Scriptum note**: You could avoid running through dockerhub by just `docker
save`ing, `scp`ing and `docker load`ing the image on the remote server.

# Step 5: do it all over again!

Well now we have all of this setup we need an nginx server and we are going to
use the exact same mechanisms, server and CI system.

So let's do it!!

### Dockerfile

```
FROM nginx

# Adding config
ADD nginx.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/conf.d
ADD conf.d /etc/nginx/conf.d
```

### .gitlab-ci.yml

```
build:
  image: docker:19.03.1
  stage: build
  services:
    - docker:19.03.1-dind
  variables:
    # Use TLS https://docs.gitlab.com/ee/ci/docker/using_docker_build.html#tls-enabled
    DOCKER_HOST: tcp://docker:2376
    DOCKER_TLS_CERTDIR: "/certs"
    C_NAME: infra-nginx
    SSH:      ssh -o StrictHostKeyChecking=no root@$GATE_IP
    SSH_EXEC: ssh -o StrictHostKeyChecking=no root@$GATE_IP docker exec -i $C_NAME
    D_PORTS: --publish 80:80/tcp --publish 80:80/udp --publish 443:443/tcp --publish 443:443/udp
  script:
    - apk add openssh
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD
    - docker build -t $CI_REGISTRY_NAME/$C_NAME:latest .
    - docker push     $CI_REGISTRY_NAME/$C_NAME:latest
    - eval $(ssh-agent)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - $SSH docker pull $CI_REGISTRY_NAME/$C_NAME
    - $SSH "docker rm -f $C_NAME || true"
    - $SSH docker run -v /var/www/html:/static --restart=always --name $C_NAME -d $D_PORTS $CI_REGISTRY_USER/$C_NAME
    - $SSH_EXEC apt update
    - $SSH_EXEC apt install -y certbot python-certbot-nginx
    - $SSH_EXEC certbot --nginx -d <your-website-url> -m <your-email> --agree-tos -n
```
You'll just need to define the same variables as before and replace the values
above on the last line.

### nginx.conf

```
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    include /etc/nginx/conf.d/*.conf;
}
```

### conf.d/website.conf

```
server {
    listen      80;
    listen	[::]:80;
    server_name  <website-url>;
    client_max_body_size 100M;

    location ~ ^/\.well-known {
        root /var/www/ghost;
        allow all;
    }

    location / {
        proxy_pass http://<website-url>:8001;
        proxy_buffering off;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Referer "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forward-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
    }
}
```

# Step 6: Enjoy
As you push theses gitlab-ci.yml and dockerfiles you should see all the pieces
working together (the CI in gitlab passing) and the website being available at
the url you specified.

Hoped you liked it. Please don't hesitate to contact me if you have trouble
with anything, I'd be glad to improve this non-tutorial.
