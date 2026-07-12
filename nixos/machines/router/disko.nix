{
  imports = [ ../../disko/basic.nix ];
  _module.args.disks = [ "/dev/nvme0n1" ];
}
