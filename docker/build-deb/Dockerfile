FROM	eu.gcr.io/gardener-project/gardenlinux/gardenlinux-build

RUN	sudo apt-get update \
     && sudo apt-get install -y devscripts python3 python3-dev python3-pip reprepro \
     && pip3 install gardener-cicd-libs

