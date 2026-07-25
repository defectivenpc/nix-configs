# Netboot root delivery with an HTTP-fetched, disk-cached Nix store.
#
# Upstream `netboot.nix` folds the whole store squashfs into the initrd, so
# every boot re-downloads the entire OS into RAM and keeps it there. That is
# fine for a 700 MB rescue image and hopeless for a multi-GB desktop image.
#
# This module keeps upstream's root layout (tmpfs / + overlay on a loop-mounted
# squashfs) but ships the squashfs *separately*:
#
#   * the initrd is plain `system.build.initialRamdisk` — small, no store
#   * `system.build.squashfsStore` is served over HTTP by the netboot server
#   * a stage-1 unit fetches it and caches it on a local ext4 partition
#     labelled GAMECACHE, so repeat boots of an unchanged image are offline
#   * with no usable cache partition it lands in a tmpfs instead — slower and
#     RAM-hungry, but a fully supported way to run a machine diskless
#
# The squashfs URL and filename arrive on the *kernel command line*, not baked
# into the initrd. That is load-bearing: `squashfsStore` contains
# `system.build.toplevel`, which contains the initrd, so an initrd that
# mentions the squashfs hash is an infinite recursion at eval time. The ipxe
# script in ./lib.nix is generated outside the system closure and is where the
# hash actually lives.

{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

let
  cfg = config.netbootHttpStore;
in
{
  options.netbootHttpStore = {
    squashfsCompression = lib.mkOption {
      type = lib.types.str;
      default = "zstd -Xcompression-level 15";
      description = ''
        Compression for the store squashfs. Level 15 is a deliberate step down
        from upstream's 19: it costs ~3% size for a large fraction of the
        build time, and this image is rebuilt often.
      '';
    };

    storeContents = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      description = "Derivations to include in the store squashfs.";
    };

    cacheLabel = lib.mkOption {
      type = lib.types.str;
      default = "GAMECACHE";
      description = ''
        ext4 filesystem label of the partition used to cache the squashfs.
        Adopted by label only — an unlabelled disk is never touched.
      '';
    };
  };

  config = {
    # We never own an ESP; these machines only ever netboot.
    boot.loader.grub.enable = false;
    boot.loader.systemd-boot.enable = false;

    # ---------------- root + store layout ----------------
    # Same shape as upstream netboot.nix. mkImageMediaOverride (prio 60) so an
    # image module can still override if it really needs to.

    fileSystems."/" = lib.mkImageMediaOverride {
      fsType = "tmpfs";
      options = [
        "mode=0755"
        "size=50%"
      ];
    };

    # Absolute path *in the initrd namespace*. The fetch unit below creates
    # this symlink pointing at whichever copy it settled on. This is verbatim
    # in the initrd fstab (see tasks/filesystems.nix `initrdFstab`), which only
    # holds because we use systemd stage 1 — scripted stage 1 rewrites any
    # absolute non-/dev device to /mnt-root$device, which is why upstream has
    # to use the relative `../nix-store.squashfs`.
    fileSystems."/nix/.ro-store" = lib.mkImageMediaOverride {
      fsType = "squashfs";
      device = "/nix-store.squashfs";
      options = [
        "loop"
        "ro"
      ]
      ++ lib.optional (config.boot.kernelPackages.kernel.kernelAtLeast "6.2") "threads=multi";
      neededForBoot = true;
    };

    fileSystems."/nix/.rw-store" = lib.mkImageMediaOverride {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };

    fileSystems."/nix/store" = lib.mkImageMediaOverride {
      overlay = {
        lowerdir = [ "/nix/.ro-store" ];
        upperdir = "/nix/.rw-store/store";
        workdir = "/nix/.rw-store/work";
      };
      neededForBoot = true;
    };

    netbootHttpStore.storeContents = [ config.system.build.toplevel ];

    system.build.squashfsStore = pkgs.callPackage "${toString modulesPath}/../lib/make-squashfs.nix" {
      fileName = "nix-store";
      storeContents = cfg.storeContents;
      comp = cfg.squashfsCompression;
    };

    # Deliberately no `system.build.netbootRamdisk` override: we ship
    # `system.build.initialRamdisk`, which is what keeps the initrd small.

    # ---------------- stage 1 ----------------

    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = ''
          netbootHttpStore requires systemd stage 1. Scripted stage 1 rewrites
          absolute fileSystems devices to /mnt-root/... and filters x-* mount
          options, so neither the /nix-store.squashfs device path nor the
          ordering against the fetch unit would survive.
        '';
      }
    ];

    boot.initrd.systemd.enable = lib.mkDefault true;
    # A failed fetch should drop to a shell with curl and ip available, not panic.
    boot.initrd.systemd.emergencyAccess = lib.mkDefault true;

    boot.initrd.network.enable = true;
    boot.initrd.systemd.network.networks."10-netboot-dhcp" = {
      matchConfig.Type = "ether";
      networkConfig.DHCP = "ipv4";
      linkConfig.RequiredForOnline = "routable";
    };

    # Broad storage coverage (SATA/PATA/NVMe/USB) for the cache partition.
    hardware.enableAllHardware = true;

    boot.initrd.availableKernelModules = [
      "squashfs"
      "overlay"
      "loop"
      "ext4"

      # NIC drivers. Unlike a stock netboot image — whose initrd already
      # contains the whole store and never touches the network — this initrd
      # cannot do anything until it has an IP. Neither the default module set
      # nor hardware.enableAllHardware includes network drivers, so a machine
      # whose NIC is missing here drops straight to the emergency shell.
      # udev autoloads by modalias, so listing a driver costs initrd size and
      # nothing else. Add to this list when adopting new hardware.
      "virtio_net" # the qemu test harness
      "virtio_pci"
      "virtio_blk"
      "r8169" # Realtek, most consumer boards
      "r8152" # Realtek USB
      "e1000"
      "e1000e" # Intel
      "igb"
      "igc"
      "ixgbe"
      "atlantic" # Aquantia/Marvell 10G
      "alx" # Atheros/Qualcomm
      "tg3" # Broadcom
      "sky2" # Marvell Yukon
      "forcedeth" # nForce
      "asix" # common USB ethernet
      "ax88179_178a"
      "cdc_ether"
      "usbnet"
    ];
    boot.initrd.kernelModules = [
      "loop"
      "overlay"
      "squashfs"
    ];

    # A systemd initrd ships mount/umount and little else — no coreutils, no
    # grep. Both `path` (for the unit's PATH) and `storePaths` (to actually
    # get the bytes into the initrd) are required.
    boot.initrd.systemd.storePaths = [
      pkgs.curlMinimal
      pkgs.coreutils
      pkgs.gnugrep
      "${pkgs.util-linux}/bin/blkid"
      "${pkgs.util-linux}/bin/mountpoint"
    ];

    # Also drop these in /bin so the emergency shell is usable when a fetch
    # fails and you are staring at an initrd prompt.
    boot.initrd.systemd.extraBin = {
      curl = "${pkgs.curlMinimal}/bin/curl";
      blkid = "${pkgs.util-linux}/bin/blkid";
      mountpoint = "${pkgs.util-linux}/bin/mountpoint";
    };

    boot.initrd.systemd.services.netboot-store-fetch = {
      description = "Fetch and cache the Nix store squashfs";
      path = [
        pkgs.curlMinimal
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.util-linux
      ];
      # initrd-fs.target pulls in every neededForBoot mount, including
      # /sysroot/nix/.ro-store. Ordering before it is what guarantees the
      # squashfs exists by the time the loop mount is attempted.
      requiredBy = [ "initrd-fs.target" ];
      before = [ "initrd-fs.target" ];
      after = [
        "initrd-root-device.target"
        "systemd-networkd.service"
      ];
      # networkd is only WantedBy=initrd.target, which is *after* the target
      # we run before. Pull it in explicitly so the After= above has something
      # to order against in the same transaction.
      wants = [ "systemd-networkd.service" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -u

        waitOnline=${config.boot.initrd.systemd.package}/lib/systemd/systemd-networkd-wait-online

        url= name=
        for o in $(< /proc/cmdline); do
          case "$o" in
            netboot.store.url=*)  url=''${o#netboot.store.url=} ;;
            netboot.store.name=*) name=''${o#netboot.store.name=} ;;
            netboot.store.ram=1)  forceRam=1 ;;
          esac
        done
        forceRam=''${forceRam:-}

        if [ -z "$url" ] || [ -z "$name" ]; then
          echo "netboot-store: no netboot.store.url=/netboot.store.name= on the kernel cmdline"
          exit 1
        fi

        target=
        mode=

        useRam() {
          # Default tmpfs size is 50% of RAM, which a 4 GB squashfs plus the
          # overlay can bump into on a smaller box. Take 85% explicitly.
          mkdir -p /ramstore
          mountpoint -q /ramstore || mount -t tmpfs -o size=85%,mode=0755 tmpfs /ramstore
          target=/ramstore/$name
          mode=ram
          echo ""
          echo "  >>> netboot-store: running DISKLESS — store lives in RAM, <<<"
          echo "  >>> re-downloaded on every boot. Label a partition        <<<"
          echo "  >>> ${cfg.cacheLabel} to cache it on disk.                       <<<"
          echo ""
        }

        useDisk() {
          if [ -n "$forceRam" ]; then
            echo "netboot-store: netboot.store.ram=1 requested, skipping the disk cache"
            return 1
          fi
          dev=/dev/disk/by-label/${cfg.cacheLabel}
          # udev may still be settling right after initrd-root-device.target.
          for _ in $(seq 1 20); do [ -e "$dev" ] && break; sleep 0.25; done
          [ -e "$dev" ] || { echo "netboot-store: no ${cfg.cacheLabel} partition"; return 1; }
          mkdir -p /gamecache
          mount -t ext4 -o rw,noatime "$dev" /gamecache || {
            echo "netboot-store: ${cfg.cacheLabel} found but would not mount"
            return 1
          }
          target=/gamecache/$name
          mode=disk
          return 0
        }

        fetch() {
          echo "netboot-store: fetching $url -> $target"
          $waitOnline --any --timeout=60 || echo "netboot-store: wait-online timed out, trying anyway"
          curl --fail --location --retry 5 --retry-connrefused --retry-delay 2 \
               --output "$target.part" "$url" || return 1
          mv "$target.part" "$target"
          sync
        }

        # A truncated or corrupt download only shows up at mount time, so prove
        # it mounts here rather than failing the boot in initrd-fs.target.
        verify() {
          mkdir -p /verify
          if mount -t squashfs -o ro,loop "$target" /verify 2>/dev/null; then
            umount /verify
            return 0
          fi
          echo "netboot-store: $target does not mount as squashfs"
          return 1
        }

        useDisk || useRam

        if [ "$mode" = disk ]; then
          # Prune other generations *before* downloading — the usual reason a
          # fetch fails on disk is that a stale squashfs filled the partition.
          for old in /gamecache/nix-store-*.squashfs /gamecache/*.part; do
            [ -e "$old" ] || continue
            [ "$old" = "$target" ] && continue
            echo "netboot-store: removing stale $old"
            rm -f "$old"
          done
        fi

        ok=
        if [ -s "$target" ] && verify; then
          echo "netboot-store: cache hit, $target"
          ok=1
        else
          rm -f "$target" "$target.part"
          if fetch && verify; then ok=1; fi
        fi

        # A bad or full cache partition must never make a machine unbootable.
        if [ -z "$ok" ] && [ "$mode" = disk ]; then
          echo "netboot-store: disk cache unusable, falling back to RAM"
          rm -f "$target" "$target.part"
          umount /gamecache || true
          useRam
          if fetch && verify; then ok=1; fi
        fi

        if [ -z "$ok" ]; then
          echo "netboot-store: could not obtain the store squashfs"
          exit 1
        fi

        ln -sfn "$target" /nix-store.squashfs
        echo "netboot-store: ready ($mode) $target"
      '';
    };

    # Register the store contents in the Nix DB once the real root is up.
    # make-squashfs.nix puts nix-path-registration at the squashfs root.
    boot.postBootCommands = ''
      ${config.nix.package}/bin/nix-store --load-db < /nix/store/nix-path-registration
      touch /etc/NIXOS
      ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system
    '';
  };
}
