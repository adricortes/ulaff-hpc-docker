#This Dockerfile is inspired by the Fenics Project Dockerfiles
#Put more info here

FROM phusion/baseimage:0.11
MAINTAINER adriano-cortes <adriano@nacad.ufrj.br>

# Get Ubuntu updates
USER root
RUN apt-get update && \
    apt-get upgrade -y -o Dpkg::Options::="--force-confold" && \
    apt-get -y install locales sudo && \
    echo "C.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set locale environment
ENV LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    LANGUAGE=C.UTF-8

COPY set-home-permissions.sh /etc/my_init.d/set-home-permissions.sh

# Set up user so that we do not run as root
# See https://github.com/phusion/baseimage-docker/issues/186
# Disable forward logging
# Add script to set up permissions of home directory on myinit
# Run ldconfig so that /usr/local/lib is in the default search
# path for the dynamic linker.
RUN useradd -m -s /bin/bash -G sudo,docker_env ulaff-hpc && \
    echo "ulaff-hpc:docker" | chpasswd && \
    echo "ulaff-hpc ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    rm /etc/my_init.d/10_syslog-ng.init && \
    echo "cat /home/ulaff-hpc/WELCOME" >> /home/ulaff-hpc/.bashrc && \
    chmod +x /etc/my_init.d/set-home-permissions.sh && \
    ldconfig

USER ulaff-hpc
RUN touch $HOME/.sudo_as_admin_successful && \
    mkdir $HOME/shared
VOLUME /home/ulaff-hpc/shared

# Print some instructions when the container starts
COPY WELCOME /home/ulaff-hpc/WELCOME

USER root
WORKDIR /tmp

# Install libs and utils
RUN apt-get -qq update && \
    apt-get -y --with-new-pkgs \
        -o Dpkg::Options::="--force-confold" upgrade && \
    apt-get -y install \
        gcc \
        g++ \
        gfortran \
        git \
        cmake \
        libmpich-dev \
        mpich \
        man \
        emacs \
        pkg-config \
        wget \
        bash-completion && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER ulaff-hpc
WORKDIR /home/ulaff-hpc

# Environment variables (needed by BLIS make)
ENV PYTHON=python3

RUN git clone https://github.com/flame/blis.git && \
    cd blis && \
    ./configure -t openmp --prefix=$HOME/blis auto && \
    make -j2 && \
    make check -j2 && \
    make install

USER root
ENTRYPOINT ["/sbin/my_init","--quiet","--","/sbin/setuser","ulaff-hpc","/bin/bash","-l","-c"]
CMD ["/bin/bash","-i"]
