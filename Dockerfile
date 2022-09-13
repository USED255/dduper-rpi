# docker buildx build --platform linux/arm/v7 -t used255/dduper-rpi:20220913 .
FROM arm32v7/debian:bullseye AS build

# Install needed dependencies.
RUN    apt update \
    && DEBIAN_FRONTEND=noninteractive \
    && apt install -y \
       git autoconf automake gcc make pkg-config patch \
       e2fslibs-dev libblkid-dev zlib1g-dev liblzo2-dev \
       libzstd-dev linux-libc-dev linux-headers-armmp \
       python3-dev python3-pip

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

CMD ["/usr/sbin/dduper"]

# Install needed dependencies.
COPY   --from=build /dduper/requirements.txt requirements.txt 
RUN    apt update \
    && DEBIAN_FRONTEND=noninteractive \
    && apt install -y \
       python3-numpy python3-ptable \
       python3-pip \
    && pip3 install --no-cache-dir pysqlite3 \
    && apt purge -y python3-pip \
    && apt autoremove -y \
    && apt clean \
    && rm -rv /var/lib/apt/lists

# Install dduper
COPY --from=build /lib/arm-linux-gnueabihf/liblzo2.so.2 /lib/arm-linux-gnueabihf/
COPY --from=build /btrfs-progs-build/usr/local/bin/* /usr/local/bin/
COPY --from=build /btrfs-progs-build/usr/local/include/* /usr/local/include/
COPY --from=build /btrfs-progs-build/usr/local/lib/* /usr/local/lib/
COPY --from=build /dduper/dduper /usr/sbin/dduper

RUN    btrfs inspect-internal dump-csum --help \
    && dduper --version 
