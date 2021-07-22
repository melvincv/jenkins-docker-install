#!/bin/bash
###########
# Create a bridge network in Docker using the following docker network create command:
docker network create jenkins

# In order to execute Docker commands inside Jenkins nodes, download and run the docker:dind Docker image using the following docker run command
docker run --name jenkins-docker --detach \
  --privileged --network jenkins --network-alias docker \
  --env DOCKER_TLS_CERTDIR=/certs \
  --volume jenkins-docker-certs:/certs/client \
  --volume jenkins-data:/var/jenkins_home \
  --publish 2376:2376 docker:dind --storage-driver overlay2
  
# Create a Dockerfile and Build it
docker build -t jenkins-blueocean .

# Start and Run the Jenkins container
docker run --name jenkins-blueocean --detach \
  --network jenkins --env DOCKER_HOST=tcp://docker:2376 \
  --env DOCKER_CERT_PATH=/certs/client --env DOCKER_TLS_VERIFY=1 \
  --publish 8100:8080 \
  --volume jenkins-data:/var/jenkins_home \
  --volume jenkins-docker-certs:/certs/client:ro \
  jenkins-blueocean
