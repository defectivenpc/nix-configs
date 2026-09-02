{
  description = "My NixOS flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-netbird.url = "github:NixOS/nixpkgs/ce4782aae889ce0f1ab3cfcfe6193ec294580d84";
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      nixpkgs-netbird,
      nixos-generators,
      nixos-facter-modules,
      disko,
      sops-nix,
      home-manager,
      deploy-rs,
      ...
    }@inputs:

    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = nixpkgs.legacyPackages.${system};

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };

      standardOverlays =
        {
          extraOverlays ? [ ],
        }:
        {
          nixpkgs.overlays = [
            (final: prev: {
              unstable = import nixpkgs-unstable {
                inherit system;
                config.allowUnfree = true;
              };
            })
          ]
          ++ extraOverlays;
          nix.settings = {
            substituters = [ "https://cosmic.cachix.org/" ];
            trusted-public-keys = [ "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE=" ];
          };
        };

      hmModuleFor =
        {
          isHeadless ? false,
        }:
        {
          home-manager.users.whitehead = import ../home-manager;
          # Move unmanaged files aside instead of failing activation.
          home-manager.backupFileExtension = "hm-bak";
          home-manager.extraSpecialArgs = {
            inherit pkgs-unstable isHeadless;
            isDarwin = false;
            username = "whitehead";
          };
        };

      mkHost =
        {
          hostname,
          extraModules ? [ ],
          extraOverlays ? [ ],
          includeHM ? true,
          includeFacter ? true,
          includeDisko ? true,
          includeSops ? true,
          isHeadless ? false,
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self inputs; };
          modules = [
            (standardOverlays { inherit extraOverlays; })
            ./machines/${hostname}/${hostname}.nix
          ]
          ++ lib.optionals includeSops [
            sops-nix.nixosModules.sops
            ./lib/users.nix
          ]
          ++ lib.optionals includeFacter [
            nixos-facter-modules.nixosModules.facter
            { config.facter.reportPath = ./hardware/facter/${hostname}.json; }
          ]
          ++ lib.optionals includeDisko [
            disko.nixosModules.disko
            ./machines/${hostname}/disko.nix
          ]
          ++ lib.optionals includeHM [
            home-manager.nixosModules.home-manager
            (hmModuleFor { inherit isHeadless; })
          ]
          ++ extraModules;
        };

      # Legacy bare-metal hosts: no overlays/sops/facter/disko/HM.
      mkBareHost =
        {
          hostname,
          extraModules ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./machines/${hostname}/${hostname}.nix ] ++ extraModules;
        };

    in
    {

      nixosConfigurations = {
        mises = mkHost {
          hostname = "mises";
          extraOverlays = [
            (final: prev: {
              netbird-pinned =
                (import nixpkgs-netbird {
                  inherit system;
                  config.allowUnfree = true;
                }).netbird;
            })
          ];
        };
        beara = mkHost { hostname = "beara"; };
        buster = mkHost { hostname = "buster"; };
        authority = mkHost {
          hostname = "authority";
          isHeadless = true;
        };
        nas1 = mkHost {
          hostname = "nas1";
          isHeadless = true;
        };
        nas2 = mkHost {
          hostname = "nas2";
          isHeadless = true;
        };
        sowell = mkHost { hostname = "sowell"; };
        router = mkHost {
          hostname = "router";
          isHeadless = true;
        };

        # Legacy hosts (bare — no facter/disko/sops/HM yet).
        bob = mkBareHost { hostname = "bob"; };
        tom = mkBareHost { hostname = "tom"; };
        bigtux = mkBareHost { hostname = "bigtux"; };
      };

      deploy = {
        # Global defaults — override per-node as needed.
        sshUser = "root";
        user = "root";
        # Keep an activation timeout that's generous for slow hosts, and
        # let deploy-rs auto-rollback if the new profile fails to come up.
        autoRollback = true;
        magicRollback = true;
        # Confirmation timeout (seconds) after activation; if the operator
        # loses connectivity before confirming, deploy-rs reverts.
        confirmTimeout = 180;

        nodes = {
          router = {
            hostname = "router.onepunch";
            profiles.system.path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.router;
          };

          nas1 = {
            hostname = "nas1.onepunchtech.io";
            profiles.system.path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.nas1;
          };
        };
      };

      # Validate every deploy node at `nix flake check` time.
      checks = builtins.mapAttrs (_: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

      packages.x86_64-linux =
        let
          netboot = import ./netboot/lib.nix { inherit inputs system; };

          netbootImages = {
            rescue = netboot.mkNetbootImage {
              name = "rescue";
              extraModules = [ ./netboot/images/rescue.nix ];
            };
            installer = netboot.mkNetbootImage {
              name = "installer";
              extraModules = [ ./netboot/images/installer.nix ];
            };
            # Ephemeral gaming OS. Unlike the two above, the Nix store is not
            # in the initrd — it ships as a separate squashfs fetched over
            # HTTP and cached on the client's GAMECACHE partition.
            gaming = netboot.mkHttpStoreImage {
              name = "gaming";
              extraModules = [ ./netboot/images/gaming.nix ];
            };
          };
        in
        rec {
          # Individual netboot images (flattened so each is a derivation
          # under packages.<system>, satisfying the flake schema).
          netbootImage-rescue = netbootImages.rescue;
          netbootImage-installer = netbootImages.installer;
          netbootImage-gaming = netbootImages.gaming;

          # NOTE: `gaming` is deliberately NOT in the bundle.
          #
          # machines/router/netboot-server.nix pulls the bundle into the
          # router's system closure, so including the gaming image would make
          # every router deploy carry its ~10 GB closure and — under
          # `deploy-rs --remote-build` — compress a multi-GB squashfs on the
          # router itself. That is hours of router CPU for a change that has
          # nothing to do with netbooting, and it competes with the DNS the
          # router is meant to be serving.
          #
          # The gaming image still builds on its own (`nix build
          # .#netbootImage-gaming`); it just is not served yet. To serve it,
          # pick a delivery path first — either build the bundle on a Linux
          # host and `nix copy` it to the router rather than building there,
          # or point netboot.store.url at nas1 and let it serve the squashfs.
          # Then add `gaming` back here plus `disklessImages = [ "gaming" ];`.
          netbootBundle = netboot.mkNetbootBundle {
            images = { inherit (netbootImages) rescue installer; };
            # Explicit: otherwise this is `lib.head names`, i.e. alphabetical,
            # and adding an image silently changes what every PXE client on
            # the network auto-boots after the menu timeout.
            default = "rescue";
          };

          # Same gaming OS on a stick, for machines whose firmware cannot PXE.
          # Self-contained: no router, no LAN needed to boot.
          #
          #   nix build .#gamingUsb
          #   sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress conv=fsync
          gamingUsb = netboot.mkIsoImage {
            name = "gaming";
            extraModules = [ ./netboot/images/gaming-usb.nix ];
          };

          # Boots the USB image in qemu exactly as a machine would from a
          # stick — UEFI firmware, image attached as a plain USB disk — so the
          # bootloader path is tested, not just the OS on top of it.
          #
          #   nix run .#gamingUsbVmTest
          gamingUsbVmTest = pkgs.writeShellApplication {
            name = "gamingUsbVmTest";
            runtimeInputs = with pkgs; [
              qemu
              coreutils
              OVMF.fd
            ];
            text = ''
              set -euo pipefail

              ISO=$(echo ${gamingUsb}/iso/*.iso)
              WORK=''${GAMING_VM_WORKDIR:-/tmp/gaming-vm}
              mkdir -p "$WORK"

              # Same GAMES disk as the netboot harness, so a library installed
              # under one delivery method is visible under the other.
              if [ ! -e "$WORK/games.raw" ]; then
                echo "note: no $WORK/games.raw — run gamingVmTest first to create one,"
                echo "      or expect a fully ephemeral session."
              fi

              ARGS=()
              if [ -e "$WORK/games.raw" ]; then
                ARGS+=(-drive "file=$WORK/games.raw,if=virtio,format=raw")
              fi

              echo ">>> booting $ISO"
              exec qemu-system-x86_64 \
                -machine q35 -m 8G -smp 4 \
                -drive "if=pflash,format=raw,readonly=on,file=${pkgs.OVMF.fd}/FV/OVMF.fd" \
                -drive "file=$ISO,format=raw,if=none,id=usbstick,readonly=on" \
                -device qemu-xhci -device usb-storage,drive=usbstick \
                -nic user,model=virtio-net-pci \
                "''${ARGS[@]}" \
                -nographic
            '';
          };

          provisionGamingDisk = import ./netboot/provision-disks.nix { inherit pkgs; };

          # Exercises the whole http-store path in qemu without a router, a
          # PXE server, or real hardware: serves the image over HTTP on the
          # host and direct-kernel-boots it.
          #
          #   nix run .#gamingVmTest              # with a cache disk
          #   nix run .#gamingVmTest -- --ram     # diskless, store in RAM
          #
          # First run downloads; second run should log a cache hit and skip it.
          gamingVmTest =
            let
              image = netbootImages.gaming;
            in
            pkgs.writeShellApplication {
              name = "gamingVmTest";
              runtimeInputs = with pkgs; [
                qemu
                python3
                coreutils
                e2fsprogs
                gnugrep
              ];
              text = ''
                set -euo pipefail

                IMG=${image}
                SQ=$(basename "$IMG"/nix-store-*.squashfs)
                WORK=''${GAMING_VM_WORKDIR:-/tmp/gaming-vm}
                RAM_MODE=0
                if [ "''${1:-}" = "--ram" ]; then RAM_MODE=1; fi

                mkdir -p "$WORK"

                # Scratch disks carrying the two labels the image adopts.
                # Deliberately kept across runs: that is what makes the second
                # run exercise the cache-hit path. Delete $WORK to start over.
                #
                # Bare filesystems in files rather than a partition table —
                # qemu exposes each as its own disk and the image only ever
                # looks for labels, never for a layout.
                if [ ! -e "$WORK/gamecache.raw" ]; then
                  echo "creating GAMECACHE + GAMES disks in $WORK"
                  truncate -s 32G "$WORK/gamecache.raw"
                  truncate -s 32G "$WORK/games.raw"
                  mkfs.ext4 -q -F -L GAMECACHE "$WORK/gamecache.raw"
                  mkfs.ext4 -q -F -L GAMES     "$WORK/games.raw"
                fi

                # Serve the image directory; 10.0.2.2 is qemu's host alias.
                python3 -m http.server 8000 --directory "$IMG" >"$WORK/http.log" 2>&1 &
                HTTP_PID=$!
                trap 'kill $HTTP_PID 2>/dev/null || true' EXIT
                sleep 1

                INIT=$(grep -o 'init=[^ ]*' "$IMG/netboot.ipxe" | head -1)
                APPEND="$INIT root=fstab console=ttyS0 systemd.log_level=info"
                APPEND="$APPEND netboot.store.url=http://10.0.2.2:8000/$SQ"
                APPEND="$APPEND netboot.store.name=$SQ"
                if [ "$RAM_MODE" = 1 ]; then APPEND="$APPEND netboot.store.ram=1"; fi

                DISKARGS=()
                if [ "$RAM_MODE" = 0 ]; then
                  DISKARGS=(-drive "file=$WORK/gamecache.raw,if=virtio,format=raw"
                            -drive "file=$WORK/games.raw,if=virtio,format=raw")
                else
                  echo ">>> diskless run: no disks attached to the VM"
                fi

                echo ">>> booting; store = $SQ"
                exec qemu-system-x86_64 \
                  -machine q35 -m 12G -smp 4 \
                  -kernel "$IMG/bzImage" -initrd "$IMG/initrd" \
                  -append "$APPEND" \
                  -nic user,model=virtio-net-pci \
                  "''${DISKARGS[@]}" \
                  -nographic
              '';
            };

          installIso = nixos-generators.nixosGenerate {
            system = system;
            modules = [
              ./installIso.nix
            ];
            format = "iso";
          };

          installTest = pkgs.writeScriptBin "installTest" ''
            nix run github:nix-community/nixos-anywhere -- --flake .#router -- --generate-hardware-config nixos-facter ./hardware/facter/router.json --target-host root@192.168.122.130
          '';

          runVM = pkgs.writeScriptBin "runVM" ''
            ${pkgs.qemu}/bin/qemu-system-x86_64 \
              -enable-kvm \
              -m 2048 \
              -nic user,model=virtio \
              -cdrom ${installIso}/iso/*.iso
          '';
        };
    };
}
