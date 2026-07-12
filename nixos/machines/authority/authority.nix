{ pkgs, lib, ... }:

{

  imports = [
    ../../lib/base.nix
    ../../lib/shell.nix
    ../../lib/sops.nix
  ];

  networking.hostName = "authority";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      8443
    ];
  };

  virtualisation.docker.enable = true;

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
  environment.etc = {
    "step/onepunch/ca.crt" = {
      text = ''
        -----BEGIN CERTIFICATE-----
        MIIBnjCCAUWgAwIBAgIQGg468lzOSakx6V2G0+dRYzAKBggqhkjOPQQDAjAuMREw
        DwYDVQQKEwhPbmVwdW5jaDEZMBcGA1UEAxMQT25lcHVuY2ggUm9vdCBDQTAeFw0y
        NTA3MDUxODI0MjJaFw0zNTA3MDMxODI0MjJaMC4xETAPBgNVBAoTCE9uZXB1bmNo
        MRkwFwYDVQQDExBPbmVwdW5jaCBSb290IENBMFkwEwYHKoZIzj0CAQYIKoZIzj0D
        AQcDQgAEisBy8TzYylZzuAlQq68R3UXdMnENW1wcude0IGJfVs9RAbX530mTkQ+G
        LxIMO+iKe23+I72IL/6toFLTvCqL6aNFMEMwDgYDVR0PAQH/BAQDAgEGMBIGA1Ud
        EwEB/wQIMAYBAf8CAQEwHQYDVR0OBBYEFCDNcJSwge3tl2aiWnFBHwo0dMITMAoG
        CCqGSM49BAMCA0cAMEQCIBObWB59VJbLFZkqXY9WJcAbXNgdf3aXLgRoMBN+nTMm
        AiBFqP26+q4Hy38SqL76hIuul8pqx+FTPgES7V9EnkuS0g==
        -----END CERTIFICATE-----
      '';
    };

    "step/onepunch/intermediate_ca.crt" = {
      text = ''
        -----BEGIN CERTIFICATE-----
        MIIByTCCAW+gAwIBAgIRAO6mX78sGSXRXbuPmYHNAz4wCgYIKoZIzj0EAwIwLjER
        MA8GA1UEChMIT25lcHVuY2gxGTAXBgNVBAMTEE9uZXB1bmNoIFJvb3QgQ0EwHhcN
        MjUwNzA1MTgyNDIzWhcNMzUwNzAzMTgyNDIzWjA2MREwDwYDVQQKEwhPbmVwdW5j
        aDEhMB8GA1UEAxMYT25lcHVuY2ggSW50ZXJtZWRpYXRlIENBMFkwEwYHKoZIzj0C
        AQYIKoZIzj0DAQcDQgAEekaszH/nxb4lJ53AFAKPutmX0SYqmXN2EJGQb2ObWiQp
        5PsdwYIm0OOLnE/kz2A5PxggfGCWPWUFZfrKWPqNZKNmMGQwDgYDVR0PAQH/BAQD
        AgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFBDG5ptraBXLq3JK2L9L
        fLZKpa9AMB8GA1UdIwQYMBaAFCDNcJSwge3tl2aiWnFBHwo0dMITMAoGCCqGSM49
        BAMCA0gAMEUCIG/JJI9kt6rQvdMB16nYdoCk3jv1X84NEGP96KN2ENomAiEA43Rx
        PSBzfrnxmJ9mw17U1J8ypCjriOTSuSdmjx8o9+U=
        -----END CERTIFICATE-----
      '';
    };

    "step/config.json" = {
      text = ''
        {
          "root": "/etc/step/onepunch/ca.crt",
          "federatedRoots": [],
          "crt": "/etc/step/onepunch/intermediate_ca.crt",
          "key": "yubikey:slot-id=9c",
          "kms": {
            "type": "yubikey",
            "pin": "690592"
          },
          "address": ":8443",
          "dnsNames": [
            "ca.onepunch",
            "ca.local",
            "localhost"
          ],
          "logger": {
            "format": "text"
          },
          "db": {
            "type": "badgerv2",
            "dataSource": "/var/lib/step/db"
          }, 
          "crl": {
            "enabled": false
          }, 
          "authority": {
            "disableIssuedAtCheck": false,
            "claims": {
              "minTLSCertDuration": "5m",
              "maxTLSCertDuration": "24h",
              "defaultTLSCertDuration": "24h",
              "disableRenewal": false,
              "allowRenewalAfterExpiry": false,
              "minHostSSHCertDuration": "5m",
              "maxHostSSHCertDuration": "1680h",
              "defaultHostSSHCertDuration": "720h",
              "minUserSSHCertDuration": "5m",
              "maxUserSSHCertDuration": "24h",
              "defaultUserSSHCertDuration": "16h"
            },
            "policy": {
              "x509": {
                "allow": {
                  "dns": ["*.local", "*.onepunch"]
                },
                "allowWildcardNames": false
              },
              "ssh": {
                "user": {
                  "allow": {
                    "email": ["@local" ]
                  }
                },
                "host": {
                  "allow": {
                    "dns": ["*.local"]
                  }
                }
              }
            },
            "provisioners": [
              {
                  "type": "JWK",
                  "name": "whitehead@onepunch",

                  "key": {
                    "use": "sig",
                    "kty": "EC",
                    "kid": "CdSLq0mzWCXVQrm0JO_8zZiM2Y5SkGbV-_9zQtniP70",
                    "crv": "P-256",
                    "alg": "ES256",
                    "x": "gjKqY3OlQgMpRO_eWLDGU1cmKRpo0VeVHk-ckX3MB38",
                    "y": "19VyyHhxjeDRNelFjgA9g_K0fKT30UEp8YQmlWysnLw"
                  },
                  "encryptedKey": "eyJhbGciOiJQQkVTMi1IUzI1NitBMTI4S1ciLCJlbmMiOiJBMjU2R0NNIiwicDJjIjo2MDAwMDAsInAycyI6Inl0TmVCaTlMWWJ2eFFNcjdBeVRpU3cifQ.zryZBm3kwKCdVQBfHEjLnNrqk4Vh3GLsps0_l54AdJPU_pCZSzpIuQ.R74z7TliMnyPiAjy.tWizYIApoLgEbvF-QrE5kL5bUCJm5dNciA9UfyQja8B3lQMro5AUD1ILhpG45shqW1AdDhYiJU7gb4tGQemXUFgozJYJbAK_-n7gLMRRicjWC8Gpp4NsANme6dnzJ6y9Hgbb83_8KUeS9JWjXEIwHNOToHhgXEAEgQX_5QHsw7E1OMjEGI4j0mGt--A5hWIme3BIqxukF8qtpKPfVgiIiO7_QKrG4HwXK-NT6t0lZ1xyax_a1zzvniYsaFBK_Tc8i0WLqlzgksa8o4MzacGvypvDWaTUEn1ubSWUoQ0ri1fCXes6AOBXX-s.GEnGURSQ-68kQsqCe0ZoTw",
                  "claims": {
                      "minTLSCertDuration": "5m",
                      "maxTLSCertDuration": "24h",
                      "defaultTLSCertDuration": "24h",
                      "disableRenewal": false,
                      "minHostSSHCertDuration": "5m",
                      "maxHostSSHCertDuration": "1680h",
                      "minUserSSHCertDuration": "5m",
                      "maxUserSSHCertDuration": "24h",
                      "enableSSHCA": true
                  }
              },
              {
                "type": "SSHPOP",
                "name": "sshpop-smallstep",
                "claims": {
                  "enableSSHCA": true
                }
              },
              {
                "type": "ACME",
                "name": "acme-provisioner"
              }
            ]
          },
          "tls": {
            "cipherSuites": [
              "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
              "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
            ],
            "minVersion": 1.2,
            "maxVersion": 1.3,
            "renegotiation": false
          },
          "password": "password"
        }
      '';
    };
  };

  services.pcscd.enable = true;

  users.groups.step = { };

  users.users.step = {
    isSystemUser = true;
    home = "/var/lib/step";
    description = "step-ca user";
    group = "step";
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.debian.pcsc-lite.access_card" &&
            subject.isInGroup("step")) {
            return polkit.Result.YES;
        }
    });
    polkit.addRule(function(action, subject) {
      if (action.id == "org.debian.pcsc-lite.access_pcsc" &&
        subject.isInGroup("step")) {
        return polkit.Result.YES;
      }
    });
  '';

  systemd.services.step-ca = {
    enable = true;
    description = "step-ca";
    restartTriggers = [ "/etc/step/config.json" ];
    serviceConfig = {
      User = "step";
      Group = "step";
      UMask = "0077";
      WorkingDirectory = "";
      ReadWritePaths = "";
      Type = "simple";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = "HOME=%S/step";
      ExecStart = [
        ""
        "${pkgs.step-ca}/bin/step-ca /etc/step/config.json"
      ];
      DynamicUser = true;
      StateDirectory = "step";
    };
    wantedBy = [ "multi-user.target" ];
  };

  environment.systemPackages = with pkgs; [
    step-ca
  ];
}
