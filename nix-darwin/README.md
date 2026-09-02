# nix-darwin

Shared macOS base config. Everything reusable lives in `../modules/darwin` and
`../home-manager`; this flake exposes it two ways.

- **`darwinConfigurations.personal-mac`** — the personal machine, defined here.
- **`lib.mkMac`** — the builder, for machines whose config must not live in this
  repo. The work mac is one of those: it has its own private flake that takes
  this one as an input.

```sh
sudo darwin-rebuild switch --flake .#personal-mac
```

There is no `networking.hostName` in here, so the attribute name has to be given
explicitly; it is not inferred from the machine's hostname.

## The interface: `lib.mkMac`

```nix
base.lib.mkMac {
  primaryUser = "<short name>";
  users = [ "<short name>" ... ];
  extraModules = [ ./local.nix ];
}
```

| Argument       | Meaning                                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------------------ |
| `primaryUser`  | `system.primaryUser`. Per-user `system.defaults` (dock, scroll direction) are written for this account only. |
| `users`        | Every account to manage. Each gets `../home-manager` built and activated, so they share one shell.           |
| `extraModules` | Extra nix-darwin modules, appended last. This is the override seam.                                          |

Every account in `users` is declared to nix-darwin with a name and home but no
uid, so nix-darwin treats them as pre-existing and will not create or modify the
accounts themselves.

`darwinModules.{base,input,tiling}` are also exported, for a consumer that wants
to compose them directly instead of going through `mkMac`.

### Writing the override module

A module passed via `extraModules` is a plain nix-darwin module. Two levels are
reachable from one file.

System level — write nix-darwin options directly:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.openconnect ];
  security.pki.certificateFiles = [ ./corp-ca.crt ];
}
```

Per-user level — go through `home-manager.sharedModules`, which applies to every
account in `users`, so commits from either the daily driver or the admin account
identify the same way:

```nix
{ ... }:
{
  home-manager.sharedModules = [
    {
      programs.git.settings.user.email = "you@work.example";
      programs.ssh.matchBlocks."git.work.example".identityFile = "~/.ssh/id_work";
    }
  ];
}
```

Values this repo sets that an override is expected to replace — currently
`user.email` and `user.name` in `../home-manager/modules/git.nix` — are declared
with `lib.mkDefault`, so a plain assignment wins with no `lib.mkForce` needed. A
"conflicting definition" error means that option is not yet defaulted; pushing
`lib.mkDefault` down into the shared module is the better fix, `lib.mkForce` at
the override site is the quick one.

## The work mac

Its config lives in a **separate private flake** on the laptop, not here. This
repo therefore contains no work account names, no work identity, and nothing to
keep out of a commit.

`mwhitehead` is the unprivileged daily driver. `admin-mwhitehead` exists to run
the rebuild, and is listed in `users` so that `su -` into it lands in a shell
identical to the daily driver's.

### First-time bootstrap

Both accounts must have logged in at least once, so that `/Users/<name>` exists
for each.

**1. Install Nix, as `admin-mwhitehead`.** Needs sudo; the daemon install is
system-wide, so both accounts get Nix from it.

```sh
su - admin-mwhitehead
curl -sSfL https://artifacts.nixos.org/nix-installer | sh -s -- install --enable-flakes
exec zsh -l
```

`--enable-flakes` is required: this installer, unlike the Determinate one, does
not enable flakes by default, and flakes are needed to bootstrap the first
switch. See "Which Nix" below.

**2. Create the private flake, as `mwhitehead`.** `/Users/Shared` rather than a
home directory: macOS homes are `drwxr-x---`, so admin could not read it, and
flake evaluation happens as the invoking user before `sudo` takes over for
activation. The daily driver owns it because the daily driver is the one editing
it.

```sh
mkdir -p /Users/Shared/nix-work && cd /Users/Shared/nix-work
nix flake init -t 'github:onepunchtech/nix-configs?dir=nix-darwin#work'
$EDITOR local.nix
git init && git add -A && git commit -m 'initial work config'
```

Push that to a **private** remote if you want it backed up. The `git add` is not
optional even before the first commit: a flake only sees git-tracked files, so an
untracked `local.nix` is invisible to `darwin-rebuild` and the import fails.

**3. First switch, as `admin-mwhitehead`.** `darwin-rebuild` does not exist yet,
so it gets run straight out of the flake. The `safe.directory` line is needed
because the checkout is owned by `mwhitehead`, and git refuses to touch a repo
owned by another user:

```sh
su - admin-mwhitehead
git config --global --add safe.directory /Users/Shared/nix-work
cd /Users/Shared/nix-work
sudo nix run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake .#work
```

If activation aborts over pre-existing files in `/etc` — the Nix installer wrote
its own `/etc/zshrc` and `/etc/nix/nix.conf` — move them aside and re-run:

```sh
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
```

### Every switch after that

```sh
su - admin-mwhitehead
cd /Users/Shared/nix-work
sudo darwin-rebuild switch --flake .#work
```

Home-manager is wired in as a nix-darwin module, exactly as it is a NixOS module
on the Linux side, so that one switch builds and activates both accounts' home
configs. There is no separate `home-manager switch` step, and running one would
fight this.

Editing, committing, and `nix flake update` stay on the `mwhitehead` side, since
admin only has read access. In particular, if the lock is stale, `darwin-rebuild`
as admin cannot rewrite it and the switch fails — bump it as the daily driver
first.

### Pulling in changes to the shared base

```sh
nix flake update base      # as mwhitehead, then commit the lock
```

### Editing the shared base from the work laptop

Clone this repo somewhere readable and point the input at it for the duration of
one switch:

```sh
sudo darwin-rebuild switch --flake .#work \
  --override-input base 'path:/Users/Shared/nix-configs?dir=nix-darwin'
```

The flakeref must be **repo root plus `?dir=nix-darwin`**, never a direct path to
the `nix-darwin/` subdirectory. This flake imports `../modules/darwin` and
`../home-manager`, which are outside its own directory; pointing at the
subdirectory makes those relative paths escape the flake root and eval fails.
The `path:` scheme, unlike `git+file:`, picks up uncommitted edits, which is what
makes this useful for iterating.

## What is deliberately absent

- **Karabiner-Elements.** Caps Lock → Control is done in
  `../modules/darwin/input.nix` via `system.keyboard`, which drives macOS's own
  `hidutil` HID remapping. No kext, no virtual HID driver, no Input Monitoring
  grant, nothing to get approved.
- **yabai / skhd** (`../modules/darwin/tiling.nix`, personal host only — the work
  flake does not pass it). Both are unsigned binaries needing Accessibility
  grants.

The ctrl-key ergonomics those were covering are handled by the Caps Lock remap
plus the `cmd+<letter>` → `ctrl+<letter>` bindings already in
`../home-manager/modules/ghostty.nix`.

## Which Nix

Vanilla upstream Nix, installed with
[`NixOS/nix-installer`](https://github.com/NixOS/nix-installer) — the Nix
Foundation's fork of the Determinate installer, maintained by the community's Nix
Installer Working Group. It installs upstream Nix and nothing else.

The original Determinate installer is no longer an option for this: as of
2026-01-01 it
[always installs Determinate Nix](https://determinate.systems/blog/installer-dropping-upstream/),
with no upstream opt-out. Determinate Nix manages `/etc/nix/nix.conf` and its own
daemon, which forces `nix.enable = false` in nix-darwin — and that takes
`nix.settings` out of this repo's hands, on the one machine where the shared
config matters most.

Uninstall, worth knowing on a machine that is not fully ours, is
`/nix/nix-installer uninstall`.

If a machine ever does turn up with Determinate Nix already installed,
`nix.enable = false;` on that host is the flag that stops nix-darwin fighting it.
