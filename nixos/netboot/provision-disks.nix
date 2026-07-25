# One-shot disk provisioning for machines that netboot the gaming image.
#
# These machines have no OS on disk and no ESP — they always netboot. The only
# thing the local SSD holds is:
#
#   LABEL=GAMECACHE   the store squashfs, so repeat boots are offline
#   LABEL=GAMES       the Steam library and the persistent home
#
# Everything is adopted by label, so a disk this script has not touched is
# never mounted. Run it once per machine from the rescue image.

{ pkgs }:

pkgs.writeShellApplication {
  name = "provision-gaming-disk";
  runtimeInputs = with pkgs; [
    util-linux
    gptfdisk
    e2fsprogs
    coreutils
  ];
  text = ''
    set -euo pipefail

    CACHE_GIB=48
    DISK=""
    FORCE=0

    usage() {
      cat <<'USAGE'
    usage: provision-gaming-disk --disk /dev/nvme0n1 [--cache-gib 48] [--force]

    Wipes the disk and lays down two ext4 partitions:
      1. GAMECACHE  (--cache-gib, default 48G)  netboot store squashfs cache
      2. GAMES      (remainder)                 Steam library + persistent home

    No ESP and no bootloader are created. Refuses to touch a disk that already
    has filesystems unless --force is given.
    USAGE
      exit 1
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        --disk) DISK="''${2:-}"; shift 2 ;;
        --cache-gib) CACHE_GIB="''${2:-}"; shift 2 ;;
        --force) FORCE=1; shift ;;
        -h|--help) usage ;;
        *) echo "unknown argument: $1" >&2; usage ;;
      esac
    done

    if [ -z "$DISK" ]; then
      echo "Available block devices:"
      lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,MOUNTPOINT
      echo
      usage
    fi

    [ -b "$DISK" ] || { echo "not a block device: $DISK" >&2; exit 1; }

    # Never touch a disk that is in use right now — this script is run from a
    # live rescue image and a mistyped device name is otherwise unrecoverable.
    if lsblk -no MOUNTPOINT "$DISK" | grep -q '[^[:space:]]'; then
      echo "REFUSING: $DISK has mounted partitions:" >&2
      lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK" >&2
      exit 1
    fi

    if [ "$FORCE" -eq 0 ]; then
      if lsblk -no FSTYPE,LABEL,PARTLABEL "$DISK" | grep -q '[^[:space:]]'; then
        echo "REFUSING: $DISK already has partitions or filesystems:" >&2
        lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$DISK" >&2
        echo >&2
        echo "Re-run with --force if you are certain this disk is disposable." >&2
        exit 1
      fi
    fi

    echo "About to DESTROY all data on $DISK:"
    lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL "$DISK"
    echo
    read -r -p "Type ERASE to continue: " confirm
    [ "$confirm" = "ERASE" ] || { echo "aborted"; exit 1; }

    wipefs -a "$DISK"
    sgdisk --zap-all "$DISK"
    sgdisk -n "1:0:+''${CACHE_GIB}G" -t 1:8300 -c 1:GAMECACHE "$DISK"
    sgdisk -n "2:0:0"                -t 2:8300 -c 2:GAMES     "$DISK"
    partprobe "$DISK"
    udevadm settle

    # /dev/nvme0n1 -> /dev/nvme0n1p1 ; /dev/sda -> /dev/sda1
    case "$DISK" in
      *[0-9]) P="p" ;;
      *) P="" ;;
    esac

    # The cache is disposable and rewritten wholesale, so skip the journal.
    mkfs.ext4 -F -L GAMECACHE -m 0 -O ^has_journal "''${DISK}''${P}1"
    mkfs.ext4 -F -L GAMES     -m 0                 "''${DISK}''${P}2"
    tune2fs -c 0 -i 0 "''${DISK}''${P}1"
    tune2fs -c 0 -i 0 "''${DISK}''${P}2"

    # Seed GAMES with the directories the image expects, owned by the player
    # uid (1000:100) so nothing has to chown a multi-TB library at boot.
    tmp=$(mktemp -d)
    mount "''${DISK}''${P}2" "$tmp"
    mkdir -p "$tmp/home" "$tmp/steamlib"
    chown -R 1000:100 "$tmp"
    chmod 0700 "$tmp/home"
    umount "$tmp"
    rmdir "$tmp"

    echo
    echo "Done."
    lsblk -o NAME,SIZE,FSTYPE,LABEL "$DISK"
    echo
    echo "GAMECACHE = ''${CACHE_GIB}G, GAMES = remainder. No ESP, no bootloader:"
    echo "this machine netboots. Leave PXE first in the BIOS boot order."
  '';
}
