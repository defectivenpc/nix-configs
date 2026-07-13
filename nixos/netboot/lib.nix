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
#     memtest/
#       memtest.bin        # 32-bit BIOS
#       memtest.efi        # x86_64 UEFI
#     menu.ipxe            # top-level menu, chainloaded from PXE

{ inputs, system }:

let
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  lib = inputs.nixpkgs.lib;

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

  mkNetbootBundle =
    { images }:
    let
      names = lib.attrNames images;

      # iPXE menu items — one per NixOS image plus memtest entries.
      menuItems =
        lib.concatMapStrings (n: "item ${n} ${n}\n") names
        + "item memtest-uefi Memtest86+ (UEFI)\n"
        + "item memtest-bios Memtest86+ (BIOS)\n"
        + "item exit Exit to local boot\n";

      # Corresponding jump targets.
      imageEntries = lib.concatMapStrings (n: ''
        :${n}
        chain http://''${next-server}/images/${n}/netboot.ipxe || goto start
      '') names;

      memtestEntries = ''
        :memtest-uefi
        chain http://''${next-server}/memtest/memtest.efi || goto start

        :memtest-bios
        kernel http://''${next-server}/memtest/memtest.bin
        boot || goto start
      '';

      # Symlink shard for each image.
      imageLinks = lib.concatMapStrings (n: ''
        mkdir -p $out/images/${n}
        ln -s ${images.${n}}/bzImage      $out/images/${n}/bzImage
        ln -s ${images.${n}}/initrd       $out/images/${n}/initrd
        ln -s ${images.${n}}/netboot.ipxe $out/images/${n}/netboot.ipxe
      '') names;

      # Default menu selection — first image if any, else memtest-uefi.
      defaultTarget = if names == [ ] then "memtest-uefi" else lib.head names;
    in
    pkgs.runCommand "netboot-bundle" { } ''
      mkdir -p $out/tftp $out/memtest
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
  inherit mkNetbootImage mkNetbootBundle;
}
