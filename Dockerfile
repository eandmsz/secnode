###Temp first image with toolchain to build
FROM phusion/baseimage:latest as builder

ENV BUILD_WORK_DIR /zen_build
WORKDIR $BUILD_WORK_DIR

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install build-essential pkg-config libc6-dev m4 g++-multilib autoconf libtool ncurses-dev unzip git python zlib1g-dev wget bsdmainutils automake ca-certificates curl

ENV GOSU_VERSION 1.10
RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O $BUILD_WORK_DIR/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  wget -O $BUILD_WORK_DIR/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc";

# verify the signature
RUN  export GNUPGHOME="$(mktemp -d)"; \
  gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
  gpg --batch --verify $BUILD_WORK_DIR/gosu.asc $BUILD_WORK_DIR/gosu; \
  chmod +x $BUILD_WORK_DIR/gosu; \
# verify that the binary works
  $BUILD_WORK_DIR/gosu nobody true;

#Checkout and build zen from the development branch
RUN git clone https://github.com/ZencashOfficial/zen \
  && cd zen \
  && git checkout development \
  && sed -i -e "s/const int MAX_OUTBOUND_CONNECTIONS = 8;/const int MAX_OUTBOUND_CONNECTIONS = 10;/g" ./src/net.cpp \
  && ./zcutil/build.sh -j$(nproc)

###Second/main image copies in build artefacts

FROM phusion/baseimage:latest

ENV BUILD_WORK_DIR /zen_build
ENV ZEN_HOME /mnt/zen
WORKDIR $ZEN_HOME

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install apt-utils \
  && DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install ca-certificates curl wget libgomp1 git

COPY --from=builder $BUILD_WORK_DIR/gosu /usr/local/bin
COPY --from=builder $BUILD_WORK_DIR/zen/src/zend /usr/local/bin
COPY --from=builder $BUILD_WORK_DIR/zen/src/zen-cli /usr/local/bin
COPY --from=builder $BUILD_WORK_DIR/zen/zcutil $ZEN_HOME/zcutil

RUN chmod a+x /usr/local/bin/gosu /usr/local/bin/zend /usr/local/bin/zen-cli

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get -y install npm \
  && npm install -g n \
  && n 8.9

RUN git clone https://github.com/ZencashOfficial/secnodetracker \
  && cd secnodetracker \
  && npm install \
  && npm install pm2 -g

#COPY ssl_ca_certs/* /usr/local/share/ca-certificates/
#RUN update-ca-certificates

# Default p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=9876")
# or via a "port=9876" line in zen.conf.
#Defaults are 9033/19033 (Testnet)
EXPOSE 9033

# Default rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=8765")
# or via a "rpcport=8765" line in zen.conf. This port should never be mapped to the outside world
# via the "docker run -p/-P" command.
#Defaults are 8231/18231 (Testnet)
#EXPOSE 8231

# Data volumes, if you prefer mounting a host directory use "-v /path:/mnt/zen_config" command line
# option (folder ownership will be changed to the same UID/GID as provided by the docker run command)
VOLUME ["/mnt/zen_config", "/mnt/zcash-params"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["start_secure_node"]


# Default p2p communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-port=9876")
# or via a "port=9876" line in zen.conf.
EXPOSE 9033

# Default rpc communication port, can be changed via $OPTS (e.g. docker run -e OPTS="-rpcport=8765")
# or via a "rpcport=8765" line in zen.conf. This port should never be mapped to the outside world
# via the "docker run -p/-P" command.
#EXPOSE 8231

# Data volumes, if you prefer mounting a host directory use "-v /path:/mnt/zen_config" command line
# option (folder ownership will be changed to the same UID/GID as provided by the docker run command)
VOLUME ["/mnt/zen_config", "/mnt/zcash-params"]

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["start_secure_node"]
