# transcoder image
FROM centos:latest

RUN adduser --uid 1000 --home /home/transcoder transcoder
WORKDIR /home/transcoder/

RUN yum -y update && yum install -y git

RUN git clone https://github.com/pkeroulas/st2110-toolkit.git
RUN source st2110-toolkit/install.sh && \
    install_common_tools && \
    install_yasm && \
    install_nasm && \
    install_x264 && \
    install_fdkaac && \
    install_mp3 && \
    install_ffmpeg
