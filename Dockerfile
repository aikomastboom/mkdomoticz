FROM phusion/baseimage:bionic-1.0.0 as base

ENV http_proxy=http://192.168.22.19:3128/

# install packages
RUN true \
&& echo "Acquire::http::Proxy \"http://192.168.22.19:3128\";" >> /etc/apt/apt.conf \
&& apt-get update \
&& apt-get autoremove -y \
&& apt-get upgrade -y \
#true
#RUN true \
&& apt-get install -y \
	liblua5.3 \
	libmosquitto1 \
	libssl1.1 \
	libsqlite3-0 \
	libusb-0.1-4 \
	zlib1g \
	libudev1 \
	python3-pip \
    fail2ban \
    && \
apt-get remove -y python2.7 && \
apt-get autoremove -y && \
apt-get clean && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*



FROM base as packages


# install packages
RUN true \
&& apt-get update \
# true
# RUN true && \
&& apt-get install -y \
	git \
	liblua5.3-dev \
	libmosquitto-dev \
	libssl1.1 libssl-dev \
	build-essential \
	libsqlite3-0 libsqlite3-dev \
	curl libcurl4-gnutls-dev \
    libusb-dev \
    uthash-dev \
	zlib1g-dev \
	libudev-dev \
    libcereal-dev \
	python3-dev python3-pip \
    fail2ban \
    linux-headers-generic && \
apt-get remove -y python2.7 && \
apt-get autoremove -y && \
true

FROM packages as zwave

ARG ZWAVE_VERSION="master"

RUN true && \
## OpenZwave installation
# grep git version of openzwave
git clone -b "${ZWAVE_VERSION}" --depth 2 https://github.com/OpenZWave/open-zwave.git /src/open-zwave && \
cd /src/open-zwave && \
# compile
make && \
make install && \

# "install" in order to be found by domoticz
ln -s /src/open-zwave /src/open-zwave-read-only && \

true

FROM zwave as cmake

ARG CMAKE_VERSION="3.16.5"

RUN true && \
cd /src && \
curl -LO https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz  && \
tar -zxf cmake-${CMAKE_VERSION}.tar.gz  && \
cd cmake-${CMAKE_VERSION}  && \
./bootstrap  && \
make  && \
make install  && \

true
FROM cmake as boost
RUN true && \

#-- Installing: /usr/local/doc/cmake-3.16/cmlibuv/LICENSE
#-- Installing: /usr/local/bin/cmake
#-- Installing: /usr/local/bin/ctest
#-- Installing: /usr/local/bin/cpack
#-- Installing: /usr/local/share/cmake-3.16/include/cmCPluginAPI.h
#-- Installing: /usr/local/doc/cmake-3.16/Copyright.txt
#-- Installing: /usr/local/share/cmake-3.16/Help


cd /src && \
#apt-get remove -y python2.7 && \
#apt-get autoremove -y && \
curl -LO https://dl.bintray.com/boostorg/release/1.66.0/source/boost_1_66_0.tar.gz && \
tar xzf boost_1_66_0.tar.gz && \
cd boost_1_66_0 && \
./bootstrap.sh --with-python-version=3.6m && \
./b2 install && \
true
FROM boost as builder

ARG DOMOTICZ_VERSION="2020.2"

RUN true && \

#apt-get remove -y \
#	libusb-1.0-0 libusb-1.0-0-dev && \
#apt-get autoremove -y && \

#apt-get install -y \
#  libcereal-dev \
#  uthash-dev \
#libusb-0.1-4 \
#libusb-dev && \
#cd /src/open-zwave && \
#make install && \
cd /src && \

## Domoticz installation
# clone git source in src
git clone -b "${DOMOTICZ_VERSION}" --depth 2 https://github.com/domoticz/domoticz.git /src/domoticz && \
# Domoticz needs the full history to be able to calculate the version string
cd /src/domoticz && \
git fetch --unshallow && \
# prepare makefile
cmake -DCMAKE_BUILD_TYPE=Release . && \
# compile
make && \
# Install
# install -m 0555 domoticz /usr/local/bin/domoticz && \

true
#RUN true && \

#cd /tmp && \
# Cleanup
# rm -Rf /src/domoticz && \

# ouimeaux
#pip3 install -U ouimeaux && \

# remove git and tmp dirs
#apt-get remove -y \
#  git cmake linux-headers-amd64 build-essential libssl-dev libboost-dev libboost-thread-dev \
#  libboost-system-dev libsqlite3-dev libcurl4-openssl-dev libusb-dev zlib1g-dev libudev-dev && \
#apt-get autoremove -y && \
#apt-get clean && \
#rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM base as domoticz

ENV MKDOMOTICZ_UPDATED=20200922

# ouimeaux
RUN pip3 install -U ouimeaux

COPY --from=builder /src/domoticz/domoticz /src/domoticz/domoticz
COPY --from=builder /src/domoticz/www /src/domoticz/www
COPY --from=builder /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4.5.0 /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4.5.0


VOLUME /config

EXPOSE 8080

RUN mkdir -p /etc/my_init.d && \
 cd /usr/lib/x86_64-linux-gnu/ && \
 ln -s /usr/lib/x86_64-linux-gnu/libcurl-gnutls.so.4.5.0 libcurl-gnutls.so.4
COPY start.sh /etc/my_init.d/domoticz.sh
RUN chmod +x /etc/my_init.d/domoticz.sh
# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
