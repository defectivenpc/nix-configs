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
    ./netboot-server.nix
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

      # ---- SQM / CAKE shaping rates ----
      #
      # Shape to ~90-95% of ACTUAL line rate. The point is to move the queue
      # off the ISP's buffer (which is huge and dumb) and onto this box, where
      # CAKE can manage it. Shaping above the real rate does nothing at all,
      # which is the single most common way to get this wrong.
      #
      # These are set for the stated gigabit service. Verify with a WIRED
      # bufferbloat test before trusting them — a test over WiFi measures the
      # wireless link, not the WAN.
      #
      # CPU caveat: CAKE is single-threaded per qdisc and this is an Atom
      # C3558. It may not sustain ~900 Mbit of shaping. If a wired speed test
      # with shaping on comes back well below line rate, or ksoftirqd pins a
      # core, lower these until throughput recovers — you are trading peak
      # bandwidth for latency, and that trade is usually worth it.
      wanDownMbit = 900;
      wanUpMbit = 900;

      # ---- nftables software flow offload ----
      #
      # Puts established TCP/UDP conntrack entries on a fast path that skips
      # the normal forwarding traversal, cutting per-packet CPU. The kernel
      # modules were already being loaded; the ruleset just never used them.
      #
      # READ THIS BEFORE LEAVING IT ON: flow offload and SQM are in tension.
      # Offloaded packets bypass most of the forwarding path, and OpenWrt
      # documents flow offloading as conflicting with SQM for exactly this
      # reason. The CAKE shaping above is fixing a measured Grade D
      # bufferbloat problem — if offload undoes that, offload is the thing to
      # give up, not the shaping. Latency under load beats a few points of
      # router CPU on a link this size.
      #
      # Only established connections are offloaded, i.e. ones the forward
      # chain's accept rules already permitted. Once a flow is offloaded its
      # later packets skip the forward chain entirely, so any rule added there
      # will not see them — safe only because the connection was already
      # accepted. `flow add` does not accept by itself; the first packets of a
      # connection still fall through to the normal rules.
      #
      # Left as a toggle so you can A/B it against a bufferbloat test without
      # editing the ruleset in three places.
      #
      # Currently OFF, in favour of the CAKE shaping above: the measured
      # problem was Grade D bufferbloat, not a CPU-bound router. Flip to true
      # only if a wired speed test shows a core pinned by ksoftirqd, and
      # re-run a bufferbloat test afterwards to confirm it did not undo the
      # shaping.
      enableFlowOffload = false;

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

        # Ceiling for the socket buffers unbound asks for below. Without
        # raising these the kernel silently clamps the request — that is the
        # "so-sndbuf 4194304 was not granted. Got 425984" warning in the
        # journal. Small buffers mean dropped replies under query bursts.
        "net.core.rmem_max" = 8388608;
        "net.core.wmem_max" = 8388608;
      };

      boot.kernelModules = [
        "nf_flow_table_inet"
        "nf_flow_table"

        # SQM: ifb provides the pseudo-device that WAN *ingress* is redirected
        # onto, since a qdisc can only shape egress. act_mirred does the
        # redirect, cls_matchall selects everything, sch_cake is the shaper.
        "ifb"
        "act_mirred"
        "cls_matchall"
        "sch_cake"
      ];

      systemd.network = {
        wait-online.anyInterface = true;

        # Pseudo-device that WAN ingress gets mirrored onto. Shaping the
        # download direction is only possible by redirecting inbound traffic
        # to an ifb and shaping *its* egress.
        netdevs."10-ifb-wan".netdevConfig = {
          Name = "ifb-wan";
          Kind = "ifb";
        };

        networks = {
          "10-wan" = {
            matchConfig.Name = wan;
            networkConfig = {
              DHCP = "ipv4";
              IPv4Forwarding = true;
              IPMasquerade = "ipv4";
            };

            # Upload shaping. A qdisc only ever controls egress, and egress on
            # the WAN interface is exactly the upload direction, so this side
            # needs no tricks.
            #
            # NAT=true lets CAKE undo masquerading and see the real internal
            # source address, which is what makes dual-src-host fairness work
            # per LAN host rather than lumping every client into one flow.
            cakeConfig = {
              Bandwidth = "${toString wanUpMbit}M";
              NAT = true;
              FlowIsolationMode = "dual-src-host";
              PriorityQueueingPreset = "besteffort";
            };
          };

          # Download shaping. Traffic arriving on the WAN is mirrored here by
          # wan-ingress-redirect.service, so this link's egress *is* the
          # download direction and CAKE can manage it.
          #
          # dual-dst-host (rather than dual-src-host on the WAN above) because
          # here the LAN client is the destination — that is what we want
          # fairness between.
          "10-ifb-wan" = {
            matchConfig.Name = "ifb-wan";
            linkConfig.RequiredForOnline = "no";
            networkConfig.ConfigureWithoutCarrier = true;
            cakeConfig = {
              Bandwidth = "${toString wanDownMbit}M";
              NAT = true;
              FlowIsolationMode = "dual-dst-host";
              PriorityQueueingPreset = "besteffort";
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
${lib.optionalString enableFlowOffload ''
              flowtable f {
                hook ingress priority filter
                devices = { ${wan}, ${lan1.iface}, ${lan2.iface}, ${lan3.iface} }
              }
''}
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
${lib.optionalString enableFlowOffload ''
                # Offload only established flows; see enableFlowOffload above.
                ct state established ip protocol { tcp, udp } flow add @f
''}
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

      # The upstream module only orders AdGuard after network.target, so at
      # boot it can start querying 127.0.0.1:5335 before unbound is listening
      # — that is the "connection refused" burst in the journal. Ordering does
      # not help when unbound is restarted underneath a running AdGuard (a
      # rebuild, say); those brief refusals are expected and self-correcting.
      systemd.services.adguardhome = {
        after = [ "unbound.service" ];
        wants = [ "unbound.service" ];
      };

      # The one piece of SQM networkd cannot express: attach an ingress qdisc
      # to the WAN and mirror everything arriving on it to ifb-wan, whose CAKE
      # qdisc (declared above) then shapes the download direction. networkd
      # has no support for tc filters or mirred actions, so this is done with
      # tc directly.
      #
      # Deliberately not ordered before anything: if it fails, the router
      # still routes, it just is not shaping downloads.
      systemd.services.wan-ingress-redirect = {
        description = "Mirror ${wan} ingress to ifb-wan for CAKE shaping";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-networkd.service" ];
        wants = [ "systemd-networkd.service" ];
        path = [ pkgs.iproute2 ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          # networkd may not have created ifb-wan yet.
          for _ in $(seq 1 30); do
            [ -e /sys/class/net/ifb-wan ] && break
            sleep 1
          done
          if [ ! -e /sys/class/net/ifb-wan ]; then
            echo "ifb-wan never appeared; download shaping inactive" >&2
            exit 1
          fi

          ip link set dev ifb-wan up

          # Idempotent: drop any previous ingress qdisc before re-adding, so a
          # restart does not stack duplicate redirect filters.
          tc qdisc del dev ${wan} handle ffff: ingress 2>/dev/null || true
          tc qdisc add dev ${wan} handle ffff: ingress
          tc filter add dev ${wan} parent ffff: protocol all matchall \
            action mirred egress redirect dev ifb-wan
        '';
        preStop = ''
          tc qdisc del dev ${wan} handle ffff: ingress 2>/dev/null || true
        '';
      };

      # unbound consumes roughly num-threads * outgoing-range file descriptors
      # (4 * 4096 with the settings above). The module sets no LimitNOFILE, so
      # it inherits systemd's 1024 soft limit and would fail to open its
      # outgoing ports once num-threads was raised. Explicit headroom.
      systemd.services.unbound.serviceConfig.LimitNOFILE = 32768;

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

              # Used ONLY to resolve the hostnames of AdGuard's own outbound
              # services — the parental-control / safe-browsing lookups against
              # family.adguard-dns.com, and DoH/DoT upstreams if any are added.
              # It must not point at 127.0.0.1:5335: bootstrap runs before (and
              # independently of) the local resolver chain, so depending on
              # unbound here deadlocks whenever unbound is down or still
              # starting.
              #
              # Without this, `parental_enabled = true` below makes AdGuard
              # attempt an HTTPS lookup it can never resolve, and every client
              # query stalls on a multi-second timeout. The NixOS module only
              # skips asserting on this because mutableSettings is true — i.e.
              # it assumes you set it in the web UI, which we never did.
              bootstrap_dns = [
                "9.9.9.10"
                "149.112.112.10"
              ];

              # AdGuard's default is 20 requests/sec, and — critically — it is
              # applied per /24, not per client (the journal confirms:
              # "ratelimit is enabled rps=20 ipv4_subnet_mask_len=24"). Every
              # machine in 10.10.100.0/24 shares one 20 rps budget, which a
              # single browser opening a page can exhaust on its own; excess
              # queries are dropped, and a dropped query looks exactly like
              # "DNS is slow" to the client.
              #
              # Safe to disable here: the nftables input chain drops all WAN
              # input except established/related, so :53 is unreachable from
              # outside and this only ever serves the LANs.
              ratelimit = 0;

              # AdGuard is the front-line cache — unbound only ever sees its
              # misses, which is why unbound's own hit rate reads so low in the
              # stats (5 of 130). Sizing this well matters more than sizing
              # unbound's cache.
              cache_size = 33554432; # 32 MiB
              cache_ttl_min = 60;

              # Answer from a stale entry immediately and refresh in the
              # background, instead of making the client wait for the upstream
              # round trip. This is the single biggest perceived-latency win.
              cache_optimistic = true;
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

            # Allowlist. These replace (not append to) whatever has been added
            # through the web UI, because yaml-merge in the module's preStart
            # overwrites lists wholesale — so anything added by hand there has
            # to be mirrored here or it disappears on the next rebuild.
            #
            # The ppfeufer list classifies error-reporting backends as
            # telemetry and blocks ||sentry.io^, ||sentry-cdn.com^ and
            # ||app.glitchtip.com^. That is fine for third-party sites phoning
            # home, but it also kills our own crash reporting: AdGuard answers
            # 0.0.0.0 and the SDK drops every event without surfacing an error.
            # ||sentry.io^ covers the per-org ingest hosts too
            # (o<id>.ingest.sentry.io, o<id>.ingest.us.sentry.io, ...).
            user_rules = [
              "@@||search.brave.com^$important"
              "@@||sentry.io^$important"
              "@@||sentry-cdn.com^$important"
              "@@||glitchtip.com^$important"
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
              $ORIGIN onepunchtech.io.
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

            authonepunchtechcomZone = pkgs.writeText "auth-onepunchtechcom.zone" ''
              $ORIGIN auth-onepunchtech.com.
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

            reverseRootZone = pkgs.writeText "reverse-51.10.10.zone" ''
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

            reverseHomeZone = pkgs.writeText "reverse-100.10.10.zone" ''
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

            reverseOnepunchZone = pkgs.writeText "reverse-106.10.10.zone" ''
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

            reverseManagementZone = pkgs.writeText "reverse-108.10.10.zone" ''
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
                edns-buffer-size = 1232;

                # ---- performance ----
                # Sized for this box: Atom C3558, 4 cores, 8 GiB (see
                # hardware/facter/router.json). unbound defaults to a single
                # thread, so it was using one of four cores.
                num-threads = 4;
                so-reuseport = true; # required for threads to scale

                # Slab counts must be powers of two and should match the
                # thread count to avoid lock contention.
                msg-cache-slabs = 4;
                rrset-cache-slabs = 4;
                infra-cache-slabs = 4;
                key-cache-slabs = 4;

                # Defaults are 4m/4m, tiny for a network this size. rrset is
                # conventionally twice msg. ~300 MiB resident at worst, which
                # is nothing against 8 GiB.
                msg-cache-size = "64m";
                rrset-cache-size = "128m";
                neg-cache-size = "4m";

                # Refresh popular entries before they expire, so a cache hit
                # stays a cache hit. prefetch-key does the same for DNSKEYs,
                # which matters with the validator enabled.
                prefetch = true;
                prefetch-key = true;

                # Answer from an expired entry while revalidating in the
                # background rather than stalling the client. Unlike
                # cache-min-ttl this does not misreport TTLs to clients.
                serve-expired = true;
                serve-expired-ttl = 3600;

                # Needs net.core.{r,w}mem_max raised above — see sysctl block.
                so-rcvbuf = "4m";
                so-sndbuf = "4m";

                rrset-roundrobin = true;

                # Optional further step, deliberately left off: it overrides
                # authoritative TTLs, which speeds up domains that publish
                # 5-second records but breaks low-TTL failover and DNS-based
                # load balancing. Enable only if you hit a case that needs it.
                # cache-min-ttl = 60;
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
          allowInterfaces = [
            lan1.iface
            lan2.iface
            lan3.iface
          ];
        };
      };

    };
}
