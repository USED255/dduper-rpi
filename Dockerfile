FROM debian:buster-slim AS build

# Install needed dependencies.
RUN    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update 

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git autoconf automake gcc make pkg-config  python-pip python3-setuptools patch linux-headers-4.19.0-16-all tzdata e2fslibs-dev libblkid-dev zlib1g-dev liblzo2-dev python3-dev libzstd-dev 

# Clone the repo
RUN git clone -b v5.12.1 --depth 1 https://hub.fastgit.org/kdave/btrfs-progs.git
COPY dduper /dduper
WORKDIR /dduper
RUN git checkout 3622c150903e0bee24b210a5bec70b6b73d8a195
# Apply csum patch
WORKDIR /btrfs-progs
RUN patch -p1 < /dduper/patch/btrfs-progs-v5.12.1/0001-Print-csum-for-a-given-file-on-stdout.patch

# Start the btrfs-progs build
RUN apt install -y wget 
RUN wget "http://ftp.cn.debian.org/debian/pool/main/l/linux/linux-libc-dev_5.10.46-4_armhf.deb"
RUN  dpkg -i linux-libc-dev_5.10.46-4_armhf.deb
RUN ./autogen.sh
RUN ./configure --disable-documentation
RUN make -j `nproc` install DESTDIR=/btrfs-progs-build

# Start the btrfs-progs static build
RUN make clean
RUN make -j `nproc` static
RUN make -j `nproc` btrfs.static
RUN cp btrfs.static /btrfs-progs-build

# Install dduper
FROM debian:buster-slim

COPY --from=build /lib/arm-linux-gnueabihf/liblzo2.so.2 /lib/arm-linux-gnueabihf/
COPY --from=build /btrfs-progs-build/usr/local/bin/* /usr/local/bin/
COPY --from=build /btrfs-progs-build/usr/local/include/* /usr/local/include/
COPY --from=build /btrfs-progs-build/usr/local/lib/* /usr/local/lib/
COPY --from=build /dduper/dduper /usr/sbin/dduper

RUN    btrfs inspect-internal dump-csum --help \
    && sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list \
    && apt-get update 
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y  python3-pip python3-setuptools
COPY   --from=build /dduper/requirements.txt requirements.txt 
RUN    pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
    && pip3 install --no-cache-dir -r requirements.txt \
    && dduper --version \
    && apt clean
