#
# RIOT Dockerfile
#
# the resulting image will contain everything needed to build RIOT for all
# supported platforms.
#
# Setup: (only needed once per Dockerfile change)
# 1. install docker, add yourself to docker group, enable docker, relogin
# 2. # docker build -t riot/riotbuild .
#
# Suggested usage:
# 3. cd to RIOT application
# 4. make BUILD_IN_DOCKER=1

FROM fedora:latest

MAINTAINER Joakim Nohlgård <joakim.nohlgard@eistec.se>

# The following package groups will be installed:
# - upgrade all system packages to latest available version
# - native platform development and build system functionality
# - LLVM/Clang toolchain
# - ARM bare metal toolchain
# - MSPGCC toolchain
# - AVR toolchain
# - MIPS bare metal toolchain
# - RISC-V bare metal toolchain
# - ESP8266 toolchain
# All RPM files and other package manager files will be deleted afterwards to
# reduce the size of the container image.
# This is all done in a single RUN command to reduce the number of layers and to
# allow the cleanup to actually save space.

RUN echo 'Updating all system packages' >&2 && \
    dnf upgrade -y && \
    echo 'Cleaning up installation files' >&2 && \
    dnf clean all && rm -rf /var/cache/yum /var/cache/dnf /tmp/* /var/tmp/*

RUN echo 'Installing native toolchain and build system functionality' >&2 && \
    dnf clean all && dnf update && \
    dnf install -y \
        automake \
        autoconf \
        bzip2 \
        ccache \
        cmake \
        coccinelle \
        cppcheck \
        curl \
        findutils \
        gcc \
        gcc-c++ \
        gdb \
        git \
        hostname \
        make \
        p7zip \
        parallel \
        pcre-tools \
        python3 \
        python3-pexpect \
        python3-crypto \
        python3-pyasn1 \
        python3-ecdsa \
        python3-flake8 \
        subversion \
        unzip \
        vim-common \
        wget \
        which \
    && \
    echo 'Installing Doxygen and graphviz' >&2 && \
    dnf install -y \
        doxygen \
        graphviz \
    && \
    echo 'Installing Cortex-M toolchain' >&2 && \
    dnf install -y \
        arm-none-eabi-binutils \
        arm-none-eabi-gcc-cs \
        arm-none-eabi-gcc-cs-c++ \
        arm-none-eabi-gdb \
        arm-none-eabi-newlib \
    && \
    echo 'Installing AVR toolchain' >&2 && \
    dnf install -y \
        avr-gcc \
        avr-gcc-c++ \
        avr-libc \
    && \
    echo 'Installing LLVM/Clang toolchain' >&2 && \
    dnf install -y \
        clang \
        llvm \
    && \
    echo 'Installing socketCAN' >&2 && \
    dnf install -y \
        can-utils \
    && \
    echo 'Cleaning up installation files' >&2 && \
    dnf clean all && rm -rf /var/cache/yum /var/cache/dnf /tmp/* /var/tmp/*

RUN echo 'Installing MSPGCC old toolchain' >&2 && \
    mkdir -p /opt && \
    curl -L 'https://github.com/pksec/msp430-gcc-4.7.3/raw/master/mspgcc-4.7.3.tar.bz2' -o - \
        | tar -C /opt -jx && \
    echo 'Removing documentation and translations' >&2 && \
    rm -rf /opt/mspgcc-*/share/{info,man,locale} && \
    echo 'Deduplicating binaries' && \
    pushd /opt/mspgcc-*/msp430/bin && \
    for f in *; do rm "$f" && ln "../../bin/msp430-$f" "$f"; done && popd

# Install MIPS binary toolchain
RUN echo 'Installing mips-mti-elf toolchain from mips.com' >&2 && \
    mkdir -p /opt && \
    curl -L 'https://codescape.mips.com/components/toolchain/2017.10-08/Codescape.GNU.Tools.Package.2017.10-08.for.MIPS.MTI.Bare.Metal.CentOS-5.x86_64.tar.gz' -o - \
        | tar -C /opt -zx && \
    echo 'Removing documentation and translations' >&2 && \
    rm -rf /opt/mips-mti-elf/*/share/{doc,info,man,locale} && \
    echo 'Deduplicating binaries' && \
    pushd /opt/mips-mti-elf/*/mips-mti-elf/bin && \
    for f in *; do rm "$f" && ln "../../bin/mips-mti-elf-$f" "$f"; done && popd

# Install RISC-V binary toolchain
RUN echo 'Installing riscv-none-elf toolchain from GNU MCU Eclipse' >&2 && \
    mkdir -p /opt && \
    curl -L 'https://github.com/gnu-mcu-eclipse/riscv-none-gcc/releases/download/v7.2.0-4-20180606/gnu-mcu-eclipse-riscv-none-gcc-7.2.0-4-20180606-1631-centos64.tgz' -o - \
        | tar -C /opt -zx && \
    echo 'Removing documentation' >&2 && \
    rm -rf /opt/gnu-mcu-eclipse/riscv-none-gcc/*/share/doc && \
    echo 'Deduplicating binaries' && \
    pushd /opt/gnu-mcu-eclipse/riscv-none-gcc/*/riscv-none-embed/bin && \
    for f in *; do rm "$f" && ln "../../bin/riscv-none-embed-$f" "$f"; done && popd

ENV MIPS_ELF_ROOT /opt/mips-mti-elf/2017.10-08
ENV PATH ${PATH}:/opt/mspgcc-4.7.3/bin:${MIPS_ELF_ROOT}/bin:/opt/gnu-mcu-eclipse/riscv-none-gcc/7.2.0-4-20180606-1631/bin

# Installs the complete ESP8266 toolchain in /opt/esp (146 MB after cleanup) from binaries
RUN echo 'Adding esp8266 toolchain' >&2 && \
    cd /opt && \
    git clone https://github.com/gschorcht/RIOT-Xtensa-ESP8266-toolchain.git esp && \
    cd esp && \
    git checkout -q df38b06f3fef6a439100e19e278405675cb66515 && \
    rm -rf .git

ENV PATH $PATH:/opt/esp/esp-open-sdk/xtensa-lx106-elf/bin

# compile suid create_user binary
COPY create_user.c /tmp/create_user.c
RUN gcc -DHOMEDIR=\"/data/riotbuild\" -DUSERNAME=\"riotbuild\" /tmp/create_user.c -o /usr/local/bin/create_user \
    && chown root:root /usr/local/bin/create_user \
    && chmod u=rws,g=x,o=- /usr/local/bin/create_user \
    && rm /tmp/create_user.c

# Create working directory for mounting the RIOT sources
RUN mkdir -m 777 -p /data/riotbuild

# Set a global system-wide git user and email address
RUN git config --system user.name "riot" && \
    git config --system user.email "riot@example.com"

# Copy our entry point script (signal wrapper)
COPY run.sh /run.sh
ENTRYPOINT ["/bin/bash", "/run.sh"]

# By default, run a shell when no command is specified on the docker command line
CMD ["/bin/bash"]

WORKDIR /data/riotbuild
