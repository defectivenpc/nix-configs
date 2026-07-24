{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.vial ];

  # Vial talks to QMK boards via hidraw. The upstream udev rule matches any
  # device whose USB serial contains the Vial magic string and grants ACL
  # access to the seat's local user — no group membership required.
  # https://get.vial.today/manual/linux-udev.html
  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", TAG+="uaccess", TAG+="udev-acl"
  '';
}
