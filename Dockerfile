FROM registry.fedoraproject.org/fedora-minimal:33

ADD patches /patches

RUN printf '%s\n' \
           '[main]' \
           'assumeyes=True' \
           'install_weak_deps=False' \
           'tsflags=nodocs' \
  | tee /etc/dnf/dnf.conf \
 && microdnf install audit-libs-devel autoconf automake coreutils diffutils expat-devel file gcc libselinux-devel libtool make meson patch pkgconfig systemd-devel xz

RUN curl -fsSL https://github.com/stevegrubb/libcap-ng/archive/v0.8.2.tar.gz | tar -xz \
 && cd libcap-ng-0.8.2 \
 && patch -p1 </patches/libcap-ng-0.8.2.diff \
 && ./autogen.sh \
 && ./configure --prefix=/usr --with-python=no --with-python3=no \
 && make \
 && make install

RUN curl -fsSL https://github.com/bus1/dbus-broker/releases/download/v28/dbus-broker-28.tar.xz | tar -xJ \
 && cd dbus-broker-28 \
 && patch -p1 </patches/dbus-broker-28.diff \
 && mkdir build \
 && cd build \
 && meson -Dprefix=/usr -Dselinux=true -Daudit=true -Dsystem-console-users=gdm -Dlinux-4-17=true \
 && ninja \
 && ninja install

FROM registry.fedoraproject.org/fedora-minimal:33

RUN printf '%s\n' \
           '[main]' \
           'assumeyes=True' \
           'install_weak_deps=False' \
           'tsflags=nodocs' \
  | tee /etc/dnf/dnf.conf \
 && microdnf update \
 && microdnf install systemd podman podman-plugins fuse-overlayfs crun runc catatonit slirp4netns \
 && microdnf clean all \
 && rm -rf /etc/dnf/dnf.conf /var/cache/yum \
 && ln -sf multi-user.target /lib/systemd/system/default.target \
 && ln -sf dbus-broker.service /lib/systemd/system/dbus.service \
 && ln -sf ../dbus.socket /lib/systemd/system/sockets.target.wants/dbus.socket \
 && rm -rf /etc/systemd/system/* \
 && mkdir -p /etc/systemd/system/console-getty.service.d \
 && printf '%s\n' \
           '[Service]' \
           'ExecStart=' \
           'ExecStart=-/usr/sbin/agetty --autologin root --noclear --keep-baud console 115200,38400,9600 $TERM' \
  | tee /etc/systemd/system/console-getty.service.d/autologin-root.conf \
 && printf '%s\n' \
           '[Unit]' \
           'DefaultDependencies=no' \
           'Conflicts=shutdown.target' \
           'After=local-fs.target' \
           'Before=sysinit.target shutdown.target' \
           'RefuseManualStop=yes' \
           '[Service]' \
           'Type=oneshot' \
           'RemainAfterExit=yes' \
           'ExecStart=/usr/bin/sed -i -e '\''s/^cgroup_manager[[:space:]]*=.*$/cgroup_manager = "systemd"/g'\'' -e '\''s/^events_logger[[:space:]]*=.*$/events_logger = "journald"/g'\'' /etc/containers/containers.conf' \
  | tee /lib/systemd/system/containers-engine-systemd.service \
 && ln -s ../containers-engine-systemd.service /lib/systemd/system/sysinit.target.wants/containers-engine-systemd.service \
 && printf '%s\n' \
           '[Unit]' \
           'DefaultDependencies=no' \
           'Conflicts=shutdown.target' \
           'After=local-fs.target containers-engine-systemd.service' \
           'Before=sysinit.target shutdown.target' \
           'RefuseManualStop=yes' \
           'ConditionPathExists=!/proc/self/setgroups' \
           '[Service]' \
           'Type=oneshot' \
           'RemainAfterExit=yes' \
           'ExecStart=/usr/bin/sed -i -e '\''s/^runtime[[:space:]]*=.*$/runtime = "runc"/g'\'' /etc/containers/containers.conf' \
  | tee /lib/systemd/system/containers-engine-runtime-runc.service \
 && ln -s ../containers-engine-runtime-runc.service /lib/systemd/system/sysinit.target.wants/containers-engine-runtime-runc.service \
 && printf '%s\n' \
           '[Unit]' \
           'DefaultDependencies=no' \
           'Conflicts=shutdown.target' \
           'After=local-fs.target' \
           'Before=sysinit.target shutdown.target' \
           'RefuseManualStop=yes' \
           'ConditionVirtualization=!private-users' \
           '[Service]' \
           'Type=oneshot' \
           'RemainAfterExit=yes' \
           'ExecStart=/usr/bin/sed -i -e '\''/^mount_program[[:space:]]*=/s/^/#/g'\'' -e '\''s/^mountopt[[:space:]]*=.*$/mountopt = "nodev"/g'\'' /etc/containers/storage.conf' \
  | tee /lib/systemd/system/containers-storage-overlayfs.service \
 && ln -s ../containers-storage-overlayfs.service /lib/systemd/system/sysinit.target.wants/containers-storage-overlayfs.service \
 && printf '%s\n' \
           '[Unit]' \
           'DefaultDependencies=no' \
           'Conflicts=shutdown.target' \
           'After=local-fs.target containers-storage-overlayfs.service' \
           'Before=sysinit.target shutdown.target' \
           'RefuseManualStop=yes' \
           'ConditionKernelVersion=>=4.19' \
           'ConditionVirtualization=!private-users' \
           '[Service]' \
           'Type=oneshot' \
           'RemainAfterExit=yes' \
           'ExecStart=/usr/bin/sed -i -e '\''s/^mountopt[[:space:]]*=.*$/mountopt = "nodev,metacopy=on"/g'\'' /etc/containers/storage.conf' \
  | tee /lib/systemd/system/containers-storage-overlayfs-metacopy.service \
 && ln -s ../containers-storage-overlayfs-metacopy.service /lib/systemd/system/sysinit.target.wants/containers-storage-overlayfs-metacopy.service \
 && printf '%s\n' \
           '[engine]' \
           'cgroup_manager = "cgroupfs"' \
           'events_logger = "file"' \
           'runtime = "crun"' \
  | tee /etc/containers/containers.conf \
 && sed -e '/^#mount_program[[:space:]]*=/s/^#//g' \
        -e 's/^mountopt[[:space:]]*=.*$/mountopt = "nodev,fsync=0"/g' \
        -e '/^additionalimagestores[[:space:]]*=/{' \
        -e 'a\ \ "/usr/share/containers/storage",' \
        -e 'a\ \ "/usr/local/share/containers/storage",' \
        -e '}' \
        -i /etc/containers/storage.conf \
 && mkdir -p /usr/share/containers/storage/overlay-images \
             /usr/share/containers/storage/overlay-layers \
             /usr/share/containers/storage/vfs-images \
             /usr/share/containers/storage/vfs-layers \
             /usr/local/share/containers/storage/overlay-images \
             /usr/local/share/containers/storage/overlay-layers \
             /usr/local/share/containers/storage/vfs-images \
             /usr/local/share/containers/storage/vfs-layers \
 && touch /usr/share/containers/storage/overlay-images/images.lock \
          /usr/share/containers/storage/overlay-layers/layers.lock \
          /usr/share/containers/storage/vfs-images/images.lock \
          /usr/share/containers/storage/vfs-layers/layers.lock \
          /usr/local/share/containers/storage/overlay-images/images.lock \
          /usr/local/share/containers/storage/overlay-layers/layers.lock \
          /usr/local/share/containers/storage/vfs-images/images.lock \
          /usr/local/share/containers/storage/vfs-layers/layers.lock

COPY --from=0 /usr/lib64/libcap-ng.so.0.0.0 /usr/lib64/libcap-ng.so.0.0.0
COPY --from=0 /usr/bin/dbus-broker /usr/bin/dbus-broker-launch /usr/bin/

VOLUME ["/var/lib/containers"]

CMD ["/sbin/init"]
