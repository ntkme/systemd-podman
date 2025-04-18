FROM registry.fedoraproject.org/fedora-minimal:42

RUN microdnf install --assumeyes --nodocs --setopt=install_weak_deps=False fuse-overlayfs systemd util-linux \
 && microdnf install --assumeyes --nodocs podman \
 && microdnf clean all \
 && rm -rf /var/cache/* \
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
           'After=local-fs.target' \
           'Before=sysinit.target shutdown.target' \
           'RefuseManualStop=yes' \
           'ConditionVirtualization=!private-users' \
           '[Service]' \
           'Type=oneshot' \
           'RemainAfterExit=yes' \
           'ExecStart=/usr/bin/sed -i -e '\''/^mount_program[[:space:]]*=/s/^/#/g'\'' -e '\''s/^mountopt[[:space:]]*=.*$/mountopt = "nodev,metacopy=on"/g'\'' /etc/containers/storage.conf' \
  | tee /lib/systemd/system/containers-storage-overlayfs.service \
 && ln -s ../containers-storage-overlayfs.service /lib/systemd/system/sysinit.target.wants/containers-storage-overlayfs.service \
 && sed -e 's/^#cgroup_manager[[:space:]]*=.*$/cgroup_manager = "cgroupfs"/g' \
        -e 's/^#events_logger[[:space:]]*=.*$/events_logger = "file"/g' \
        /usr/share/containers/containers.conf \
  | tee /etc/containers/containers.conf \
 && sed -e '/^#mount_program[[:space:]]*=/s/^#//g' \
        -e 's/^mountopt[[:space:]]*=.*$/mountopt = "nodev,fsync=0"/g' \
        -e '/^additionalimagestores[[:space:]]*=/{' \
        -e 'a\ \ "/usr/share/containers/storage",' \
        -e 'a\ \ "/usr/local/share/containers/storage",' \
        -e '}' \
        /usr/share/containers/storage.conf \
  | tee /etc/containers/storage.conf \
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

VOLUME ["/var/lib/containers"]

CMD ["/sbin/init"]
