# container-systemd-podman

``` sh
podman run -d \
  --privileged \
  --volume /mnt/data/etc/systemd/system:/etc/systemd/system \
  --volume /mnt/data/var/lib/containers:/var/lib/containers \
  ghcr.io/ntkme/systemd-podman
```
