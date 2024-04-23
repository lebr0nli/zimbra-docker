#################################################################
# Dockerfile to build Zimbra Collaboration 10.0.8 container images
# Based on Ubuntu 20.04
# Original created by Jorge de la Cruz
#################################################################
FROM zimbra/zm-base-os:devcore-ubuntu-20.04 AS builder

RUN sudo apt-get update && sudo apt-get install rsync -y

RUN mkdir installer-build && \
    cd installer-build && \
    git clone --depth 1 --branch 10.0.6 https://github.com/Zimbra/zm-build.git && \
    cd zm-build && \
    ENV_CACHE_CLEAR_FLAG=true ./build.pl --ant-options -DskipTests=true --git-default-tag=10.0.8,10.0.7,10.0.6,10.0.5,10.0.4,10.0.3,10.0.2,10.0.1,10.0.0-GA --build-release-no=10.0.8 --build-type=FOSS --build-release=LIBERTY --build-release-candidate=GA --build-thirdparty-server=files.zimbra.com --no-interactive && \
    cd /home/build/installer-build/BUILDS && \
    mv UBUNTU*/zcs-* /home/build/zcs.tgz

FROM ubuntu:20.04

RUN echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install \
  wget \
  dialog \
  openssh-client \
  software-properties-common \
  dnsmasq \
  dnsutils \
  net-tools \
  iproute2 \
  sudo \
  vim \
  curl \
  rsyslog \
  unzip

COPY --from=builder /home/build/zcs.tgz /opt/zimbra-install/zcs.tgz

COPY opt/ /opt

CMD ["/bin/bash", "/opt/entrypoint.sh"]
