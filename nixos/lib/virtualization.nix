{ pkgs, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.docker.package = pkgs.docker_29;
  virtualisation.libvirtd.enable = true;

  programs.virt-manager.enable = true;

}
