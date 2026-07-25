# Netboot server bits — imported by router.nix.
#
# Serves the flake-built netboot bundle over TFTP + HTTP and tells kea to
# hand out arch-appropriate iPXE binaries via DHCP options 66/67.

{
  config,
  pkgs,
  lib,
  self,
  ...
}:

let
  # NOTE: this pulls the entire bundle into the router's system closure,
  # including the gaming image's multi-GB store squashfs — so every deploy-rs
  # push of the router copies it, and nix.gc keeps 7 days of generations
  # (lib/base.nix). Check `df` on the router before the first gaming deploy.
  # If it becomes a problem, serve just the squashfs from nas1 and repoint
  # netboot.store.url; the URL is already a build-time parameter of the ipxe
  # script, so that is a one-line change in netboot/lib.nix.
  bundle = self.packages.${pkgs.stdenv.hostPlatform.system}.netbootBundle;

  # Router's primary LAN IP — used as `next-server` for clients across all
  # subnets. Clients on other subnets route through the router, so they can
  # reach this IP for TFTP/HTTP just fine.
  nextServer = "10.10.53.1";
in
{
  # ------------- TFTP: initial iPXE payload -------------
  services.atftpd = {
    enable = true;
    root = "${bundle}/tftp";
  };

  # ------------- HTTP: menu + kernels + initrds + memtest + store -------------
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    virtualHosts."boot.onepunch" = {
      default = true;
      root = "${bundle}";
      locations."/".extraConfig = "autoindex on;";

      # The gaming image's Nix store is a multi-GB squashfs fetched by the
      # client's initrd (see ../../netboot/http-store.nix). Serve it as a
      # plain byte stream: it is already zstd-compressed, so gzipping it on
      # the way out is pure router CPU for nothing.
      locations."~ \\.squashfs$".extraConfig = ''
        gzip off;
        sendfile on;
        tcp_nopush on;
        sendfile_max_chunk 2m;
        # Range support lets a resumed fetch pick up where it left off.
        add_header Accept-Ranges bytes;
        # The filename contains the store hash, so a given URL never changes.
        add_header Cache-Control "public, max-age=31536000, immutable";
      '';
    };
  };

  # Open ports globally. Router's WAN egress is DHCP-only and it doesn't
  # forward these ports outside, so this is LAN-only in practice.
  networking.firewall.allowedTCPPorts = [ 80 ];
  networking.firewall.allowedUDPPorts = [ 69 ];

  # ------------- DHCP: hand out iPXE binaries by client arch -------------
  # These merge with the main kea config in router.nix.
  services.kea.dhcp4.settings = {
    # `next-server` at the DHCP4 root propagates to every subnet4 stanza
    # unless overridden per-subnet. All subnets share the same TFTP host.
    next-server = nextServer;

    # Detect iPXE clients via option 77 (user-class-information) so we can
    # feed them the HTTP menu URL instead of another TFTP fetch. Otherwise
    # match option 93 (client-arch) to distinguish UEFI vs BIOS.
    client-classes = [
      {
        name = "ipxe-loaded";
        test = "substring(option[77].hex,0,4) == 'iPXE'";
        boot-file-name = "http://${nextServer}/menu.ipxe";
      }
      {
        name = "efi-x86_64";
        test = "option[93].hex == 0x0007";
        boot-file-name = "ipxe.efi";
        next-server = nextServer;
      }
      {
        name = "legacy-bios";
        test = "option[93].hex == 0x0000";
        boot-file-name = "undionly.kpxe";
        next-server = nextServer;
      }
    ];
  };
}
