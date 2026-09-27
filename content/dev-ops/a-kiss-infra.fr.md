---
title: "Monter une infra dockerisée KISS avec CI/CD en 3 heures"
date: 2020-03-08T00:45:19Z
draft: false
toc: false
images:
tags:
  - untagged
---

Hello friend! Bienvenue sur ce nouveau blog infra.

Si vous êtes là, vous vous demandez probablement comment j'ai construit un
site aussi génial, et sinon, vous vous demandez sûrement comment je peux
prétendre l'avoir fait en quelques jours, backend d'infra compris.

En fait c'est simple : je suis *flemmard* et un peu *radin*... donc j'utilise
des outils pour flemmards et je ne paie que le strict nécessaire. Aussi, je
me fiche un peu de la sécurité. Et avant que vous ne commenciez à râler :
ceci n'est pas un tuto, c'est surtout moi qui frime avec ce que j'ai fait
pendant un week-end, parce que je m'ennuyais, avec des memes.

Comme vous êtes probablement aussi flemmard et occupé que moi, laissez-moi
vous montrer comment j'ai construit ce super site **intégré, dockerisé,
auto-déployé** de la manière la plus concise possible.

Dans ce non-tuto, je pars du principe que vous connaissez déjà un peu :

* linux
* ssh
* git
* un peu docker, mais vraiment un peu
* OVH, Scaleway, ou n'importe quel fournisseur de nom de domaine et de cloud

## Étape 1 : acheter un serveur et un nom de domaine
{{< img style="float: right" src="https://i.imgflip.com/1x1twg.jpg" >}}
Je ne vais pas vous mentir... il vous faudra un serveur de toute façon si
vous voulez être connecté au grand réseau interconnecté du monde entier.

Mon fournisseur cloud actuel est **[Scaleway](https://scaleway.com)** et je
les aime bien parce que je peux sortir une VM Ubuntu pour 3€/mois.

Mais tant que vous avez une connexion SSH et docker installé, c'est bon,
vous pouvez utiliser AWS, OVH, ou même Google Cloud... ça, c'est votre
problème.

En plus de ce serveur, il vous faudra un nom de domaine. [OVH](https://ovh.com)
est probablement le plus simple pour commencer. Il faudra pointer le domaine
vers votre serveur tout neuf ci-dessus.

## Étape 2 : Go HuGo !
Hugo est clairement l'outil le plus rapide que j'aie jamais utilisé pour
construire un site, et pourtant j'en ai construit pas mal... genre presque
3. Mais pour être honnête, ça m'a pris 10 minutes pour démarrer et avoir
quelque chose.

Donc maintenant, en local sur votre machine de dev, vous pouvez suivre le
[guide de démarrage rapide](https://gohugo.io/getting-started/quick-start/)

N'oubliez pas que vous pouvez choisir parmi plusieurs thèmes disponibles
[ici](https://themes.gohugo.io/)

{{< img style="float: left" src="https://lh3.googleusercontent.com/proxy/EyanFzS97WcvY_RrfyARcZ8Jm9h4SETBbyL2cFNAp8uedb6fSArdRbbfsG7udelwHdB8KuYqJQYgEnziWNOLIGDTukS_cmBo8Erg4s-PMacdSnsli-Bb1SBwwxKNaZPaEeKmJU41vSQTMqkwN1VJNWHmoZNDlkqwnhI" >}}
## Étape 3 : Intégration !

Maintenant vous devriez avoir un dépôt git local avec un site qui fonctionne
en local. L'idée serait d'**intégrer** tout ça sur un serveur git distant
qui propose un pipeline CD/CI gratuit. Bon, euh, ah, on dirait bien qu'on va
parler de [Gitlab](gitlab.com) ici, donc allez créer votre compte tout de
suite si ce n'est pas déjà fait !

Ensuite vous pourrez créer un nouveau projet et faire un `git remote add`
vers ce nouveau projet.

Maintenant parlons CI !
Il vous faudra créer un fichier .gitlab-ci.yml que Gitlab lira pour
construire votre projet.
Utilisez simplement le template suivant :
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
    IMAGE_NAME: <nom-d-image-de-votre-choix>
    SERVER_URL: <url-du-serveur.com>
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

Ce yaml va faire 3 choses :

1. Construire une image docker avec votre code
2. La pousser sur docker hub
3. La récupérer sur votre serveur distant et la démarrer

Pour construire l'image, `docker build` aura besoin d'un petit dockerfile
avec hugo installé. Heureusement, internet en est plein :
```
FROM jguyomard/hugo-builder

# Adding config
ADD . /src
```
il suffit d'ajouter un fichier `Dockerfile` à la racine de votre projet avec
ça dedans.

# Étape 4 : assembler les pièces

Maintenant, avant d'aller plus loin avec gitlab, il vous faudra créer un
compte [dockerhub](https://hub.docker.com/). C'est gratuit si vous n'avez
pas besoin que vos images soient privées.

Ensuite il vous faudra définir quelques variables dans Gitlab sous :
**Settings -> CI/CD -> Variables**

* CI_REGISTRY_USER : votre utilisateur docker hub
* CI_REGISTRY_PASSWORD : votre mot de passe docker hub (n'oubliez pas de
  masquer et protéger la valeur)
* SERVER_IP : l'ip du serveur distant
* SSH_PRIVATE_KEY : la clé privée utilisée pour se connecter en ssh au
  serveur distant


**Post-scriptum** : vous pourriez éviter de passer par dockerhub en faisant
juste un `docker save`, un `scp`, et un `docker load` de l'image sur le
serveur distant.

# Étape 5 : on recommence tout !

Bon maintenant qu'on a tout ça, il nous faut un serveur nginx et on va
utiliser exactement les mêmes mécanismes, le même serveur et le même
système de CI.

Alors allons-y !!

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
    - $SSH_EXEC certbot --nginx -d <url-de-votre-site> -m <votre-email> --agree-tos -n
```
Il vous suffit de définir les mêmes variables qu'avant et de remplacer les
valeurs ci-dessus sur la dernière ligne.

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
    server_name  <url-du-site>;
    client_max_body_size 100M;

    location ~ ^/\.well-known {
        root /var/www/ghost;
        allow all;
    }

    location / {
        proxy_pass http://<url-du-site>:8001;
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

# Étape 6 : profitez
En poussant ces gitlab-ci.yml et dockerfiles, vous devriez voir toutes les
pièces fonctionner ensemble (la CI qui passe au vert sur gitlab) et le site
disponible à l'url que vous avez indiquée.

J'espère que ça vous a plu. N'hésitez pas à me contacter si vous avez un
souci, je serai ravi d'améliorer ce non-tuto.
