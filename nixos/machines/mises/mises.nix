{ pkgs, config, ... }:
{
  imports = [
    ../../lib/base.nix
    ../../lib/gui.nix
    ../../lib/amdgpu.nix
    #./lib/users.nix
    ../../lib/shell.nix
    #./lib/sops.nix
    ../../lib/printer.nix
    ../../lib/networking.nix
    ../../lib/virtualization.nix
  ];

  networking.hostName = "mises";
  services.desktopManager.cosmic.enable = true;
  #services.displayManager.cosmic-greeter.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [
      pkgs.rocmPackages.clr.icd
    ];
  };

  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIFFzCCAv+gAwIBAgIUMFH4MXQ6woC5Nnrpxfw5D2aWwoswDQYJKoZIhvcNAQEL
      BQAwGzEZMBcGA1UEAwwQQ2F0YWxsYXh5IExhYiBDQTAeFw0yNjA2MDkxNzIzMzRa
      Fw0zNjA2MDYxNzIzMzRaMBsxGTAXBgNVBAMMEENhdGFsbGF4eSBMYWIgQ0EwggIi
      MA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDBTlArhhxWWm1pAjcb6Usof9Li
      36BDASZGFAtZFlCO4cUX5VWDKs1UEPbpqJ7s26gYCK/OGnpMkTRtX69NJpHsIJpr
      /V1GxAR6dKOFHB/HTjFcp1lHLTw6hVeXnvT0+guEf9Dq6B8d1G0xCa60LMoZp89M
      d2iMWgj8hu4GYLIAcjO9fSVQDzmboxH1FjmrnntUhE70+rOb3jdtUuEFcvFJgwL/
      o98Wh4Qog/1tDqpUaINRl3Vc87yzIvjKbl+8bTwhGi3owrjaeE6Ras3StspbFRoQ
      7Zgt5PbqawTKS3aQwOVKpzF5Qwz6ozHVFF35oURSCmIzPyOu5zfTLuH8s2WKU0o3
      GyxEwS9SNG/aM05b9smZPtjaXuhWhUGHoJhVjMEZ51TOUZ6Q6LFm1SCjx8cSVX3C
      fw8DNWR6q1nSVpLp8w/qE+Jhzye4SoSVBgYAGjpjU0O+BxlAHMhLwloXSPcQaKqV
      4XSu3EECOEZgwfBnER1UZGXGB0ANSTHP3nzKOYEYSC9I3c/MiqIlvuPpXKmdShzX
      FMlc/ku56r7CTjnxvx0ak3v9Ih1QFr2p+ifzGiRtl5oEke12tbVs/flm/nwzNaAM
      4j+uYz5hZiHHa+C7qxRhAvblivRUBAUDMgpwg42AOMDeeBGzQrFRwg3zpzoRqQxS
      Be8pD/gmZbIcuPGmAwIDAQABo1MwUTAdBgNVHQ4EFgQULE3sXEHa0vXj/VT1rh3d
      UsxM1S4wHwYDVR0jBBgwFoAULE3sXEHa0vXj/VT1rh3dUsxM1S4wDwYDVR0TAQH/
      BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAgEAjYeGNovoYxn91L4JOdJtxIObMaFp
      Lyl0ree1JHGXV7v3vjZ1ptdY3Lx1ywKDDAYd7cpGMyTHN6kapKTQF7s9oD3B9KNM
      6qsN3ljb+vcDkyefRM6HKZ2eBVcF6XmApxVMKxT+4fU/hIb6fvIMbrq8vC12rv39
      y0Er84KpwN6Dvsf/8UyIJVdv66tqL5V8tsNKdZt1X/dAYHyEHx/hdbT361bxw8oZ
      L5/xCw3Trqd2SRxNWesLkCEwUaUcquOmLvISItJSWTlC3vYQtII0Yi7DihAKJd3I
      JlHDFmI412PvdLhlWPunPQA9V165qAW/nGv+Rjwd8gyL8qwqmH88KaAkZ8FPjLui
      WkJSOgD6wmz0peC0J7wSMr/pFsoK7YJzoX0nuQWwVQUJSJFgPvCg3iCBK1k9ORtS
      dCoEkiz3y8bUmleDHD6vT+wouRHORL32fUae13oZQWdoN49H/FgbCagnKBwHzbjf
      J/LG9noRvFIUDGu9t3VQClu4HUUfdmiLp/b5lN+N2ETfcIFyJxP9niVIO53+mzyO
      Q1R/qEwDc8Cc7rmwhFpeC1ht2oDNim8RRUiIrR0pROCLP/OrNnQIHfbotr9Ldnza
      PYgII3Sssxvf9r0aPzqt7CAaAcQknTuTOEm66LmFNeftR9kUclMfOBJveWZitQyy
      J/JgzEU7OGKJ5Uw=
      -----END CERTIFICATE-----
    ''
  ];

  security.pki.certificateFiles = [
    ../../certs/praxiotic-prod-ca.crt
  ];

  nixpkgs.config.allowUnfree = true;

  systemd.tmpfiles.rules = [
    "d /mnt/extra1 0777 whitehead users"
  ];

  fileSystems."/mnt/share" = {
    device = "10.10.106.50:/mnt/share";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/media" = {
    device = "10.10.106.50:/mnt/media";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/ops-backups" = {
    device = "10.10.106.50:/mnt/ops-backups";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  fileSystems."/mnt/project-backups" = {
    device = "10.10.106.50:/mnt/project-backups";
    fsType = "nfs";
    options = [
      "x-systemd.automount"
      "noauto"
      "nfsvers=4.2"
    ];
  };

  # optional, but ensures rpc-statsd is running for on demand mounting
  boot.supportedFilesystems = [ "nfs" ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  services.resolved.enable = true;

  boot.kernelParams = [
    "video=DP-1:2560x1440@120"
    "video=HDMI-A-1:2560x1440@120"
    "kvm_amd"
  ];

  # sops.defaultSopsFile = ./host-secrets/mises-secrets.yaml;
  # sops.secrets.whitehead-password = { };
  # sops.secrets.whitehead-password.neededForUsers = true;
  #
  security.polkit.enable = true;

  users.users.whitehead = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "docker"
      "libvirtd"
      "kvm"
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAlxuKI8DZvdMA7dHTXG9NATaw9D2RGMQqQKwef4m2oeHFI/r+cPHICtC0SYYk6woPSjjZR7PtiP2VSn0eoX3yk= YubiKey #26922176 PIV Slot 9a (touch: cached)"
    ];
  };
  security.pam.services.kwallet = {
    name = "kwallet";
    enableKwallet = true;
  };

  services.netbird = {
    enable = true;
    package = pkgs.netbird-pinned;
  };

}
