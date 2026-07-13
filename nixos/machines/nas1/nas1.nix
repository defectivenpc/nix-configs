{
  pkgs,
  config,
  lib,
  ...
}:
let
  zfsCompatibleKernelPackages = lib.filterAttrs (
    name: kernelPackages:
    (builtins.match "linux_[0-9]+_[0-9]+" name) != null
    && (builtins.tryEval kernelPackages).success
    && (!kernelPackages.${config.boot.zfs.package.kernelModuleAttribute}.meta.broken)
  ) pkgs.linuxKernel.packages;
  latestKernelPackage = lib.last (
    lib.sort (a: b: (lib.versionOlder a.kernel.version b.kernel.version)) (
      builtins.attrValues zfsCompatibleKernelPackages
    )
  );
in

{
  imports = [
    ../../lib/base.nix
    ../../lib/shell.nix
  ];

  boot.zfs.extraPools = [ "storage1" ];

  boot.kernelPackages = latestKernelPackage;

  networking.hostName = "nas1";

  # optional, but ensures rpc-statsd is running for on demand mounting
  boot.supportedFilesystems = [
    "nfs"
    "zfs"
    "btrfs"
  ];

  # Sole owner: systemd-networkd. dhcpcd is disabled to avoid conflicts.
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  # Mark online as soon as ANY interface is up, so boot doesn't hang.
  systemd.network.wait-online.anyInterface = true;
  networking.hostId = "8425e349";

  # DHCP on any wired interface (matches enp7s0 today, plus any renames).
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "ipv4";
    linkConfig.RequiredForOnline = "routable";
  };

  services.zfs = {
    autoScrub.enable = true;
    trim.enable = true;
  };

  services.sanoid = {
    enable = true;
    templates.backup = {
      hourly = 24;
      daily = 15;
      monthly = 1;
      autoprune = true;
      autosnap = true;
    };

    datasets."storage1/repositories" = {
      useTemplate = [ "backup" ];
    };

    datasets."storage1/ops-backups" = {
      useTemplate = [ "backup" ];
    };

    datasets."storage1/project-backups" = {
      useTemplate = [ "backup" ];
    };

    datasets."storage1/share" = {
      useTemplate = [ "backup" ];
    };

    datasets."storage1/media" = {
      useTemplate = [ "backup" ];
    };
  };

  users.users.zfs = {
    shell = pkgs.bash;
    isNormalUser = true;
    extraGroups = [
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR+DhzZ7fDLf6zVmOokIT/MwXQ0BQ08nOyoFrV+Gadv whitehead@nas1"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHodVIKNrDnLmE18C+nJHgb+tL6SR6WN+EsYsklvUplw zfs@nas1"
    ];
  };

  services.nfs.server = {
    enable = true;
    lockdPort = 4001;
    mountdPort = 4002;
    statdPort = 4000;
    extraNfsdConfig = '''';
  };

  fileSystems."/nfs" = {
    device = "/mnt/nas";
    options = [ "bind" ];
  };

  # systemd.tmpfiles.rules = [
  #   "d /nfs 0777 nobody nogroup"
  # ];
  #
  # services.nfs.server.exports = ''
  #   /nfs/share    10.10.100.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #   /nfs/share    10.10.106.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #
  #   /nfs/repositories    10.10.100.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #   /nfs/repositories    10.10.106.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #
  #   /nfs/media    10.10.100.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #   /nfs/media    10.10.106.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #
  #   /nfs/ops-backups    10.10.100.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #   /nfs/ops-backups    10.10.106.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #
  #   /nfs/project-backups    10.10.100.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  #   /nfs/project-backups    10.10.106.0/24(insecure,rw,sync,no_subtree_check,anonuid=1000,anongid=100)
  # '';
  #
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
    allowedUDPPorts = [
      111
      2049
      4000
      4001
      4002
      20048
    ];
  };

}
