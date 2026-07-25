# Netboot image + bundle helpers.
#
# `mkNetbootImage` produces a symlink tree for a single NixOS system built
# from the upstream `netboot-minimal.nix` module — kernel, initrd, and the
# per-image iPXE snippet that pins the right kernel cmdline.
#
# `mkNetbootBundle` combines a set of images with `pkgs.ipxe` binaries and
# `pkgs.memtest86plus` into a directory that the router serves over
# TFTP + HTTP. Layout:
#
#   $out/
#     tftp/
#       ipxe.efi           # UEFI iPXE  (DHCP option 67 for arch 0x0007)
#       undionly.kpxe      # BIOS iPXE  (DHCP option 67 for arch 0x0000)
#     images/<name>/
#       bzImage
#       initrd
#       netboot.ipxe       # per-image chainload script (kernel cmdline etc)
#       nix-store-*.squashfs   # http-store images only, see mkHttpStoreImage
#     memtest/
#       memtest.bin        # 32-bit BIOS
#       memtest.efi        # x86_64 UEFI
#     menu.ipxe            # top-level menu, chainloaded from PXE

{ inputs, system }:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  lib = inputs.nixpkgs.lib;

  # Netboot systems are built with `lib.nixosSystem` directly rather than
  # through the flake's `mkHost`, so they get none of `standardOverlays`.
  # Without this they have neither `allowUnfree` (Steam and the nvidia driver
  # refuse to evaluate) nor `pkgs.unstable`.
  #
  # Applied only to mkHttpStoreImage: adding it to the plain netboot images
  # would change their pkgs instance and rebuild rescue/installer wholesale
  # for no benefit they currently need.
  netbootNixpkgs =
    { extraOverlays ? [ ] }:
    {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        })
      ]
      ++ extraOverlays;
    };

  mkNetbootImage =
    { name, extraModules ? [ ] }:
    let
      sys = lib.nixosSystem {
        inherit system;
        modules = [
          "${inputs.nixpkgs}/nixos/modules/installer/netboot/netboot-minimal.nix"
          { networking.hostName = lib.mkForce "netboot-${name}"; }
        ]
        ++ extraModules;
      };
    in
    pkgs.runCommand "netboot-image-${name}" { } ''
      mkdir -p $out
      ln -s ${sys.config.system.build.kernel}/${sys.config.system.boot.loader.kernelFile} $out/bzImage
      ln -s ${sys.config.system.build.netbootRamdisk}/${sys.config.system.boot.loader.initrdFile} $out/initrd
      cp ${sys.config.system.build.netbootIpxeScript}/netboot.ipxe $out/netboot.ipxe
    '';

  # Like mkNetbootImage, but the Nix store ships as a separate squashfs served
  # over HTTP and cached on the client's disk, instead of being folded into a
  # multi-GB initrd. See ../netboot/http-store.nix for the mechanism.
  #
  # Note this does NOT build on netboot-minimal.nix / netboot-base.nix: those
  # pull in profiles/minimal.nix (which forces enableRedistributableFirmware
  # off — fatal for a GPU image) and profiles/installation-device.nix (root
  # autologin on tty1 plus installer tooling), neither of which belongs in a
  # desktop image.
  mkHttpStoreImage =
    { name, extraModules ? [ ], extraOverlays ? [ ] }:
    let
      sys = lib.nixosSystem {
        inherit system;
        modules = [
          ./http-store.nix
          "${inputs.nixpkgs}/nixos/modules/profiles/base.nix"
          (netbootNixpkgs { inherit extraOverlays; })
          # mkDefault, not mkForce: unlike the netboot-minimal images there is
          # no installation-device profile to out-prioritise here, so an image
          # module can just name itself.
          { networking.hostName = lib.mkDefault "netboot-${name}"; }
        ]
        ++ extraModules;
      };

      squashfs = sys.config.system.build.squashfsStore;
      # "<hash>-nix-store.img" -> "<hash>". Changes whenever the store content
      # changes, which is exactly the cache key we want on the client.
      storeHash = lib.head (lib.splitString "-" (baseNameOf "${squashfs}"));
      storeName = "nix-store-${storeHash}.squashfs";
    in
    pkgs.runCommand "netboot-image-${name}"
      {
        passthru = { inherit sys squashfs storeName; };
      }
      ''
        mkdir -p $out
        ln -s ${sys.config.system.build.kernel}/${sys.config.system.boot.loader.kernelFile} $out/bzImage
        ln -s ${sys.config.system.build.initialRamdisk}/${sys.config.system.boot.loader.initrdFile} $out/initrd
        ln -s ${squashfs} $out/${storeName}

        # Written here rather than taken from system.build.netbootIpxeScript
        # because it has to name the squashfs hash. Anything inside the system
        # closure that references the squashfs would be an eval-time cycle:
        # squashfs -> toplevel -> initrd.
        #
        # ''${next-server} and ''${cmdline} are iPXE variables expanded at boot,
        # so no server IP is baked in and extra params can be chained in.
        cat > $out/netboot.ipxe <<'EOF'
        #!ipxe
        kernel bzImage init=${sys.config.system.build.toplevel}/init initrd=initrd ${
          toString sys.config.boot.kernelParams
        } netboot.store.url=http://''${next-server}/images/${name}/${storeName} netboot.store.name=${storeName} ''${cmdline}
        initrd initrd
        boot
        EOF
      '';

  # Removable-media delivery of an image that would otherwise netboot. Lives
  # here rather than in its own tree so it shares `netbootNixpkgs` with
  # mkHttpStoreImage — the two must agree on allowUnfree and overlays or the
  # USB and netboot builds of the "same" image would diverge.
  #
  # Returns the ISO (hybrid, `dd`-able straight to a stick).
  mkIsoImage =
    { name, extraModules ? [ ], extraOverlays ? [ ] }:
    (lib.nixosSystem {
      inherit system;
      modules = [
        (netbootNixpkgs { inherit extraOverlays; })
        { networking.hostName = lib.mkDefault "usb-${name}"; }
      ]
      ++ extraModules;
    }).config.system.build.isoImage;

  mkNetbootBundle =
    {
      images,
      # Images that additionally get a "(diskless)" menu entry forcing the
      # store into RAM instead of the local cache partition.
      disklessImages ? [ ],
      # Explicit auto-boot target. Without this it is `lib.head names`, i.e.
      # alphabetical, so adding an image can silently change what every PXE
      # client on the network boots after the 60s timeout.
      default ? null,
    }:
    let
      names = lib.attrNames images;

      # iPXE menu items — one per NixOS image plus memtest entries.
      menuItems =
        lib.concatMapStrings (n: "item ${n} ${n}\n") names
        + lib.concatMapStrings (n: "item ${n}-diskless ${n} (diskless, store in RAM)\n") disklessImages
        + "item memtest-uefi Memtest86+ (UEFI)\n"
        + "item memtest-bios Memtest86+ (BIOS)\n"
        + "item exit Exit to local boot\n";

      # Corresponding jump targets.
      imageEntries =
        lib.concatMapStrings (n: ''
          :${n}
          chain http://''${next-server}/images/${n}/netboot.ipxe || goto start
        '') names
        + lib.concatMapStrings (n: ''
          :${n}-diskless
          set cmdline netboot.store.ram=1
          chain http://''${next-server}/images/${n}/netboot.ipxe || goto start
        '') disklessImages;

      memtestEntries = ''
        :memtest-uefi
        chain http://''${next-server}/memtest/memtest.efi || goto start

        :memtest-bios
        kernel http://''${next-server}/memtest/memtest.bin
        boot || goto start
      '';

      # Symlink the whole image directory rather than named files, so
      # per-image extras (the http-store squashfs) are served without the
      # bundle needing to know their names.
      imageLinks = lib.concatMapStrings (n: ''
        ln -s ${images.${n}} $out/images/${n}
      '') names;

      defaultTarget =
        if default != null then
          default
        else if names == [ ] then
          "memtest-uefi"
        else
          lib.head names;
    in
    pkgs.runCommand "netboot-bundle" { } ''
      mkdir -p $out/tftp $out/memtest $out/images
      ln -s ${pkgs.ipxe}/undionly.kpxe $out/tftp/undionly.kpxe
      ln -s ${pkgs.ipxe}/ipxe.efi      $out/tftp/ipxe.efi

      ln -s ${pkgs.memtest86plus}/memtest.bin $out/memtest/memtest.bin
      ln -s ${pkgs.memtest86plus}/memtest.efi $out/memtest/memtest.efi

      ${imageLinks}

      cat > $out/menu.ipxe <<'EOF'
      #!ipxe

      :start
      menu Netboot menu (router)
      ${menuItems}
      choose --default ${defaultTarget} --timeout 60000 target && goto ''${target}

      ${imageEntries}
      ${memtestEntries}

      :exit
      exit
      EOF
    '';

in
{
  inherit
    mkNetbootImage
    mkHttpStoreImage
    mkIsoImage
    mkNetbootBundle
    ;
}
