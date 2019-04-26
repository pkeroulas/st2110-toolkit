# Virtual NMOS node/registry image
#
# docker build command should be executed from top directory:
# $ docker build -t centos/nmos:v0 -f ./nmos/Dockerfile .

FROM centos:latest

RUN adduser --uid 1000 --home /home/transcoder transcoder
WORKDIR /home/transcoder/

RUN yum -y update && yum install -y git

ADD . /home/transcoder/st2110_toolkit/
RUN source /home/transcoder/st2110_toolkit/install.sh && \
    install_common_tools && \
    install_cmake && \
    install_boost && \
    install_mdns && \
    install_cpprest && \
    install_cppnode
