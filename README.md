# systemd-podman

``` sh
podman run -d \
  --privileged \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --volume /mnt/data/etc/systemd/system:/etc/systemd/system:rw \
  --volume /mnt/data/var/lib/containers:/var/lib/containers:Z \
  ghcr.io/ntkme/systemd-podman:edge
```
