{
  pkgs,
  config,
  lib,
  ...
}:

{

  imports = [
    ../../lib/base.nix
    ../../lib/users.nix
    ../../lib/shell.nix
    ../../lib/sops.nix
  ];

  options = {
    options.services.unbound.settings.server.local-data = lib.mkOption {
      type = lib.types.anything;
    };

    options.services.unbound.settings.server.local-zone = lib.mkOption {
      type = lib.types.anything;
    };

  };
  config =
    let
      wan = "enp4s0";

      lan1 = {
        iface = "eno1";
        gw = "10.10.51.0";
        ip = "10.10.51.0/31";
      };

      lan2 = {
        iface = "eno2";
        gw = "10.10.53.1";
        ip = "10.10.53.1/24";
        subnet = "10.10.53.0/24";
      };

      lan3 = {
        iface = "enp5s0";
        gw = "10.10.55.1";
        ip = "10.10.55.1/24";
        subnet = "10.10.55.0/24";
      };
    in
    {

      services.nixAutoUpdate.enable = lib.mkForce false;

      boot.kernel.sysctl = {
        "net.ipv4.conf.all.forwarding" = true;
        "net.ipv6.conf.all.forwarding" = true;
      };

      boot.kernelModules = [
        "nf_flow_table_inet"
        "nf_flow_table"
      ];

      systemd.network = {
        wait-online.anyInterface = true;
        networks = {
          "10-wan" = {
            matchConfig.Name = wan;
            networkConfig = {
              DHCP = "ipv4";
              IPv4Forwarding = true;
              IPMasquerade = "ipv4";
            };
          };
          "10-lan1" = {
            matchConfig.Name = lan1.iface;
            address = [ lan1.ip ];
            linkConfig.RequiredForOnline = "no";
            networkConfig = {
              ConfigureWithoutCarrier = true;
            };
            routes = [
              {
                Destination = "10.10.100.0/24";
                Gateway = "10.10.51.1";
              }
              {
                Destination = "10.10.102.0/24";
                Gateway = "10.10.51.1";
              }
              {
                Destination = "10.10.104.0/24";
                Gateway = "10.10.51.1";
              }
              {
                Destination = "10.10.106.0/24";
                Gateway = "10.10.51.1";
              }
              {
                Destination = "10.10.108.0/24";
                Gateway = "10.10.51.1";
              }
            ];
          };
          "10-lan2" = {
            matchConfig.Name = lan2.iface;
            address = [ lan2.ip ];
            linkConfig.RequiredForOnline = "no";
            networkConfig = {
              ConfigureWithoutCarrier = true;
            };
          };
          "10-lan3" = {
            matchConfig.Name = lan3.iface;
            address = [ lan3.ip ];
            linkConfig.RequiredForOnline = "no";
            networkConfig = {
              ConfigureWithoutCarrier = true;
            };
          };
        };
      };

      networking = {
        hostName = "router";
        useNetworkd = true;
        useDHCP = false;

        nat.enable = false;
        firewall.enable = false;

        nftables = {
          enable = true;
          checkRuleset = false;
          ruleset = ''
            table inet filter {

              #flowtable f {
              #  hook ingress priority 0;
              #  devices = { ${wan}, ${lan1.iface}, ${lan2.iface}, ${lan3.iface} };
              #}

              chain output {
                type filter hook output priority 100; policy accept;
              }

              chain input {
                type filter hook input priority 0; policy drop;

                iifname "lo" accept
                iifname { "${lan1.iface}", "${lan2.iface}", "${lan3.iface}" } accept
                iifname "${wan}" ct state { established, related } accept
                iifname "${wan}" drop
              }

              chain forward {
                type filter hook forward priority filter; policy drop;

                #ip protocol { tcp, udp } flow offload @f

                iifname { "${lan1.iface}", "${lan2.iface}", "${lan3.iface}" } oifname { "${wan}" } accept
                iifname { "${lan1.iface}", "${lan2.iface}", "${lan3.iface}" } oifname { "${lan1.iface}", "${lan2.iface}", "${lan3.iface}" } accept
                iifname { "${wan}" } oifname { "${lan1.iface}", "${lan2.iface}", "${lan3.iface}" } ct state { established, related } accept
              }
            }

            table ip nat {
              chain prerouting {
                type nat hook prerouting priority -100; policy accept;
                ip saddr 10.10.100.0/24 udp dport 53 counter dnat to 10.10.51.0;
                ip saddr 10.10.102.0/24 udp dport 53 counter dnat to 10.10.51.0
                ip saddr 10.10.104.0/24 udp dport 53 counter dnat to 10.10.51.0

                ip saddr 10.10.100.0/24 tcp dport 53 counter dnat to 10.10.51.0
                ip saddr 10.10.102.0/24 tcp dport 53 counter dnat to 10.10.51.0
                ip saddr 10.10.104.0/24 tcp dport 53 counter dnat to 10.10.51.0

                ip saddr 10.10.100.0/24 tcp dport 853 counter dnat to 10.10.51.0
                ip saddr 10.10.102.0/24 tcp dport 853 counter dnat to 10.10.51.0
                ip saddr 10.10.104.0/24 tcp dport 853 counter dnat to 10.10.51.0

              }

              chain postrouting {
                type nat hook postrouting priority 100; policy accept;
                oifname "${wan}" masquerade 
              }
            }
          '';
        };
      };

      environment.systemPackages = with pkgs; [
        htop
        vim
        wget
        dig
        kitty
        ethtool
        tcpdump
        traceroute
        conntrack-tools
      ];

      services = {
        resolved.enable = false;
        openssh = {
          enable = true;
        };

        adguardhome = {
          enable = true;
          settings = {
            http = {
              address = "0.0.0.0:3000";
            };
            dns = {
              upstream_dns = [
                "127.0.0.1:5335"
              ];
              local_ptr_upstreams = [
                "127.0.0.1:5335"
              ];
            };
            filtering = {
              protection_enabled = true;
              filtering_enabled = true;

              parental_enabled = true;
              safe_search = {
                enabled = false;
              };
            };
            filters =
              map
                (url: {
                  enabled = true;
                  url = url;
                })
                [
                  "https://big.oisd.nl"
                  "https://nsfw.oisd.nl"
                  "https://github.com/ppfeufer/adguard-filter-list/blob/master/blocklist?raw=true"
                ];
          };

          # tls = {
          #   enabled = true;
          #   server_name = "router.onepunchtech.io";
          #   force_https = true;
          #   port_dns_over_tls = 853;
          #   certificate_chain = "";
          #   private_key = "";
          # };

        };
        unbound =
          let
            onepunchZone = pkgs.writeText "onepunch.zone" ''
              $ORIGIN onepunch.
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                                    IN      NS      ns1.onepunch.
              ns1                   IN      A       10.10.51.0
              router                IN      A       10.10.51.0
              torswitch1            IN      A       10.10.51.1

              dlink                 IN      A       10.10.108.2
              tplink1               IN      A       10.10.108.3
              tplink2               IN      A       10.10.108.4



              accontrol             IN      A       10.10.100.99
              masterprinter         IN      A       10.10.100.90
              3dprinter1            IN      A       10.10.100.92

              ca               IN      A       10.10.106.3
              officelab        IN      A       10.10.106.41
              cp1.officelab    IN      A       10.10.106.41
              cp2.officelab    IN      A       10.10.106.42
              cp3.officelab    IN      A       10.10.106.43

              masterlab        IN      A       10.10.106.31
              cp1.masterlab    IN      A       10.10.106.31
              cp2.masterlab    IN      A       10.10.106.32
              cp3.masterlab    IN      A       10.10.106.33
              nas.masterlab    IN      A       10.10.106.39

              bigtux           IN      A       10.10.106.101
              nas1             IN      A       10.10.106.50
              nas2             IN      A       10.10.106.51

              argocd           IN      A       10.10.110.0


            '';

            onepunchtechioZone = pkgs.writeText "onepunchtechio.zone" ''
              $ORIGIN onepunchtech.io
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                                    IN      NS      ns1.onepunchtech.io.
              ns1                   IN      A       10.10.51.0
              router                IN      A       10.10.51.0
              torswitch1            IN      A       10.10.51.1

              dlink                 IN      A       10.10.108.2
              tplink1               IN      A       10.10.108.3
              tplink2               IN      A       10.10.108.4



              accontrol             IN      A       10.10.100.99
              masterprinter         IN      A       10.10.100.90
              3dprinter1            IN      A       10.10.100.92

              ca               IN      A       10.10.106.3
              officelab        IN      A       10.10.106.41
              cp1.officelab    IN      A       10.10.106.41
              cp2.officelab    IN      A       10.10.106.42
              cp3.officelab    IN      A       10.10.106.43

              masterlab        IN      A       10.10.110.1
              cp1.masterlab    IN      A       10.10.106.31
              cp2.masterlab    IN      A       10.10.106.32
              cp3.masterlab    IN      A       10.10.106.33
              nas.masterlab    IN      A       10.10.106.39

              nas1             IN      A       10.10.106.50
              nas2             IN      A       10.10.106.51

              argocd           IN      A       10.10.110.3
              code             IN      A       10.10.110.3
              jellyfin         IN      A       10.10.110.3

            '';

            authonepunchtechcomZone = pkgs.writeText "onepunchtechio.zone" ''
              $ORIGIN auth-onepunchtech.com
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                                    IN      NS      ns1.onepunchtech.io.
              ns1                   IN      A       10.10.51.0

              idm           IN      A       10.10.110.3

            '';

            reverseRootZone = pkgs.writeText "" ''
              $ORIGIN 51.10.10.in-addr.arpa.
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                  IN NS ns1.onepunch.

              0   IN PTR router.onepnuch.
            '';

            reverseHomeZone = pkgs.writeText "" ''
              $ORIGIN 100.10.10.in-addr.arpa.
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                  IN NS ns1.onepunch.

              99   IN PTR accontrol.onepnuch.
              90   IN PTR masterprinter.onepnuch.
            '';

            reverseOnepunchZone = pkgs.writeText "" ''
              $ORIGIN 106.10.10.in-addr.arpa.
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                  IN NS ns1.onepunch.

              3  IN PTR ca.onepnuch.
              41 IN PTR officelab.onepnuch.
              41 IN PTR cp1.officelab.onepnuch.
              42 IN PTR cp2.officelab.onepnuch.
              43 IN PTR cp3.officelab.onepnuch.

              31 IN PTR masterlab
              31 IN PTR cp1.masterlab
              32 IN PTR cp2.masterlab
              33 IN PTR cp3.masterlab
              39 IN PTR nas.masterlab

              101 IN PTR bigtux.onepunch.
            '';

            reverseManagementZone = pkgs.writeText "" ''
              $ORIGIN 108.10.10.in-addr.arpa.
              $TTL 86400
              @       IN      SOA     ns1.onepunch. admin.onepunch. (
                                      2023010101 ; serial
                                      3600       ; refresh
                                      1800       ; retry
                                      1209600    ; expire
                                      86400 )    ; minimum
                  IN NS ns1.onepunch.

              2   IN PTR dlink.onepnuch.
              3   IN PTR tplink1.onepnuch.
              4   IN PTR tplink2.onepnuch.
            '';

          in
          {
            enable = true;
            settings = {
              server = {
                # verbosity = 2;
                interface = [ "127.0.0.1" ];
                port = 5335;
                access-control = [ "127.0.0.1 allow" ];
                harden-glue = true;
                harden-dnssec-stripped = true;
                use-caps-for-id = false;
                prefetch = true;
                edns-buffer-size = 1232;
                hide-identity = true;
                hide-version = true;

                private-domain = [
                  "onepunch."
                  "onepunchtech.io."
                  "51.10.10.in-addr.arpa."
                ];
                local-zone = [
                  "\"10.in-addr.arpa.\" nodefault"
                ];
              };
              # forward-zone = [
              #   {
              #     name = ".";
              #     forward-addr = [
              #       "1.1.1.1@853#cloudflare-dns.com"
              #       "1.0.0.1@853#cloudflare-dns.com"
              #     ];
              #     forward-first = false;
              #     forward-tls-upstream = true;
              #   }
              # ];
              auth-zone = [
                {
                  name = "onepunch";
                  zonefile = "${onepunchZone}";
                }
                {
                  name = "onepunchtech.io";
                  zonefile = "${onepunchtechioZone}";
                }
                {
                  name = "auth-onepunchtech.com";
                  zonefile = "${authonepunchtechcomZone}";
                }
                {
                  name = "51.10.10.in-addr.arpa";
                  zonefile = "${reverseRootZone}";
                }
                {
                  name = "100.10.10.in-addr.arpa";
                  zonefile = "${reverseHomeZone}";
                }
                {
                  name = "106.10.10.in-addr.arpa";
                  zonefile = "${reverseOnepunchZone}";
                }
                {
                  name = "108.10.10.in-addr.arpa";
                  zonefile = "${reverseManagementZone}";
                }

              ];
            };
          };

        kea.dhcp4 = {
          enable = true;
          settings = {
            interfaces-config = {
              interfaces = [
                "${lan1.iface}"
                "${lan2.iface}"
                "${lan3.iface}"
              ];
            };
            lease-database = {
              name = "/var/lib/kea/dhcp4.leases";
              persist = true;
              type = "memfile";
            };
            rebind-timer = 2000;
            renew-timer = 1000;
            subnet4 = [
              # {
              #   id = 1;
              #   pools = [
              #     {
              #       pool = "10.10.51.140 - 10.10.51.240";
              #     }
              #   ];
              #   subnet = lan1.subnet;
              #   interface = lan1.iface;
              #   option-data = [
              #     {
              #       "name" = "routers";
              #       "data" = lan1.gw;
              #     }
              #     {
              #       "name" = "domain-name-servers";
              #       "data" = lan1.gw;
              #     }
              #   ];
              #   reservations = [
              #
              #
              #   ];
              # }
              {
                id = 1;
                pools = [
                  {
                    pool = "10.10.53.100 - 10.10.53.240";
                  }
                ];
                subnet = lan2.subnet;
                interface = lan2.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = lan2.gw;
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan2.gw;
                  }
                ];

                reservations = [

                ];
              }
              {
                id = 2;
                pools = [
                  {
                    pool = "10.10.55.100 - 10.10.55.254";
                  }
                ];
                subnet = lan3.subnet;
                interface = lan3.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = lan3.gw;
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan3.gw;
                  }
                ];
              }
              {
                id = 3;
                pools = [
                  {
                    pool = "10.10.100.100 - 10.10.100.254";
                  }
                ];
                subnet = "10.10.100.0/24";
                interface = lan1.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = "10.10.100.1";
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan1.gw;
                  }
                ];

                reservations = [
                  {
                    hw-address = "02:42:74:c9:7a:69";
                    ip-address = "10.10.100.99"; # ac control
                  }
                  {
                    hw-address = "80:a5:89:f3:f4:51";
                    ip-address = "10.10.100.90"; # printer
                  }
                  {
                    hw-address = "ce:65:7f:c4:04:49";
                    ip-address = "10.10.100.91"; # 3dprinter1
                  }
                  {
                    hw-address = "c8:3a:35:cd:98:f0";
                    ip-address = "10.10.100.92"; # 3dprinter1
                  }

                ];
              }
              {
                id = 4;
                pools = [
                  {
                    pool = "10.10.102.100 - 10.10.102.254";
                  }
                ];
                subnet = "10.10.102.0/24";
                interface = lan1.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = "10.10.102.1";
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan1.gw;
                  }
                ];

                reservations = [
                ];
              }
              {
                id = 5;
                pools = [
                  {
                    pool = "10.10.104.100 - 10.10.104.254";
                  }
                ];
                subnet = "10.10.104.0/24";
                interface = lan1.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = "10.10.104.1";
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan1.gw;
                  }
                ];

                reservations = [
                ];
              }
              {
                id = 6;
                pools = [
                  {
                    pool = "10.10.106.100 - 10.10.106.254";
                  }
                ];
                subnet = "10.10.106.0/24";
                interface = lan1.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = "10.10.106.1";
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan1.gw;
                  }
                ];

                reservations = [
                  {
                    hw-address = "00:e0:4c:68:07:9f";
                    ip-address = "10.10.106.41"; # k8scontrol1
                  }
                  {
                    hw-address = "34:1a:4d:0e:9b:ee";
                    ip-address = "10.10.106.42"; # k8scontrol2
                  }
                  {
                    hw-address = "34:1a:4d:0e:9f:49";
                    ip-address = "10.10.106.43"; # k8scontrol3
                  }
                  {
                    hw-address = "6c:bf:b5:02:3d:a6";
                    ip-address = "10.10.106.39"; # nas
                  }
                  {
                    hw-address = "e0:51:d8:1a:a9:43";
                    ip-address = "10.10.106.31"; # cp1.masterlab
                  }
                  {
                    hw-address = "e0:51:d8:1a:c4:5b";
                    ip-address = "10.10.106.32"; # cp2.masterlab
                  }
                  {
                    hw-address = "e0:51:d8:1a:af:7a";
                    ip-address = "10.10.106.33"; # cp3.masterlab
                  }
                  {
                    hw-address = "34:1a:4d:0e:9f:4a";
                    ip-address = "10.10.106.3"; # authority
                  }
                  {
                    hw-address = "1c:86:0b:2d:da:18";
                    ip-address = "10.10.106.50"; # nas1
                  }
                  {
                    hw-address = "1c:86:0b:2d:da:aa";
                    ip-address = "10.10.106.51"; # nas2
                  }

                ];
              }
              {
                id = 7;
                pools = [
                  {
                    pool = "10.10.108.100 - 10.10.108.254";
                  }
                ];
                subnet = "10.10.108.0/24";
                interface = lan1.iface;
                option-data = [
                  {
                    "name" = "routers";
                    "data" = "10.10.108.1";
                  }
                  {
                    "name" = "domain-name-servers";
                    "data" = lan1.gw;
                  }
                ];

                reservations = [
                  {
                    hw-address = "e0:1c:fc:aa:8f:24";
                    ip-address = "10.10.108.2"; # d-link switch
                  }
                  {
                    hw-address = "00:5f:67:72:18:da";
                    ip-address = "10.10.108.3"; # tplink1
                  }
                  {
                    hw-address = "00:5f:67:72:28:f6";
                    ip-address = "10.10.108.4"; # tplink2
                  }
                ];
              }
            ];
            valid-lifetime = 43200;
          };
        };

        frr =
          let

            masterLabGroup = "masterlab";
            officeLabGroup = "officelab";
          in
          {
            bgpd.enable = true;
            config = ''
              ! -*- bgp -*-
              !
              frr defaults traditional

              debug bgp neighbor-events
              debug bgp updates
              debug bgp zebra

              router bgp 65000
               bgp bestpath as-path multipath-relax
               no bgp ebgp-requires-policy
               !bgp ebgp-requires-policy
               bgp router-id 10.10.51.0


               neighbor 10.10.51.1 remote-as 65001
               neighbor 10.10.51.1 activate

               ! neighbor ${officeLabGroup} peer-group
               ! neighbor ${officeLabGroup} remote-as 65002
               ! neighbor ${officeLabGroup} activate
               ! neighbor ${officeLabGroup} soft-reconfiguration inbound
               ! neighbor 10.10.106.41 peer-group ${officeLabGroup}
               ! neighbor 10.10.106.42 peer-group ${officeLabGroup}
               ! neighbor 10.10.106.43 peer-group ${officeLabGroup}

               ! address-family ipv4 unicast
                ! redistribute connected
                ! neighbor ${masterLabGroup} activate
                ! neighbor ${masterLabGroup} route-map ALLOW-ALL in
                ! neighbor ${masterLabGroup} route-map ALLOW-ALL out
                ! neighbor ${masterLabGroup} next-hop-self

                ! neighbor ${officeLabGroup} activate
                ! neighbor ${officeLabGroup} route-map ALLOW-ALL in
                ! neighbor ${officeLabGroup} route-map ALLOW-ALL out
                ! neighbor ${officeLabGroup} next-hop-self
               ! exit-address-family

              ! route-map ALLOW-ALL permit 10
            '';
          };

        avahi = {
          enable = true;
          reflector = true;
          interfaces = [
            lan1.iface
            lan2.iface
            lan3.iface
          ];
        };
      };

      sops.defaultSopsFile = ../../host-secrets/router-secrets.yaml;
      sops.secrets.whitehead-password = { };
      sops.secrets.whitehead-password.neededForUsers = true;
    };
}
