FROM arm32v7/debian:bullseye AS build

# Install needed dependencies.
RUN    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update
RUN    DEBIAN_FRONTEND=noninteractive apt-get install -y \
       git autoconf automake gcc make \
       pkg-config  python3-pip python3-setuptools patch linux-headers-armmp \
       tzdata e2fslibs-dev libblkid-dev zlib1g-dev liblzo2-dev \
       python3-dev libzstd-dev wget linux-libc-dev

# btrfs-progs build
RUN    git clone --depth 1 https://github.com/Lakshmipathi/dduper.git \
    && git clone -b v5.12.1 --depth 1 https://github.com/kdave/btrfs-progs.git
WORKDIR /btrfs-progs
RUN    patch -p1 < /dduper/patch/btrfs-progs-v5.12.1/0001-Print-csum-for-a-given-file-on-stdout.patch \
    && ./autogen.sh \
    && ./configure --disable-documentation \
    && make -j `nproc` install DESTDIR=/btrfs-progs-build \
    && make clean \
    && make -j `nproc` static \
    && make -j `nproc` btrfs.static \
    && cp btrfs.static /btrfs-progs-build


FROM arm32v7/debian:bullseye

# Install needed dependencies.
RUN    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
       python3-pip python3-setuptools \
    && apt clean \
    && rm -rv /var/lib/apt/lists
COPY   --from=build /dduper/requirements.txt requirements.txt 
RUN    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
    && pip3 install --no-cache-dir -r requirements.txt

CMD ["/usr/sbin/dduper"]

# Install dduper
COPY --from=build /lib/arm-linux-gnueabihf/liblzo2.so.2 /lib/arm-linux-gnueabihf/
COPY --from=build /btrfs-progs-build/usr/local/bin/* /usr/local/bin/
COPY --from=build /btrfs-progs-build/usr/local/include/* /usr/local/include/
COPY --from=build /btrfs-progs-build/usr/local/lib/* /usr/local/lib/
COPY --from=build /dduper/dduper /usr/sbin/dduper

RUN    btrfs inspect-internal dump-csum --help \
    && dduper --version 
