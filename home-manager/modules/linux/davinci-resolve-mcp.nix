{
  pkgs,
  pkgs-unstable,
  lib,
  ...
}:

let
  # The unwrapped application directory -- the thing that would be /opt/resolve
  # on a distro that installs Resolve the normal way. `davinci-resolve-studio'
  # itself is the buildFHSEnv wrapper (a bwrap launcher, no Developer/ or libs/
  # of its own); `.davinci' is the payload it binds to /opt/resolve inside the
  # sandbox. Taking it from `pkgs-unstable' rather than `pkgs' so the MCP server
  # and the GUI in ./default.nix are always the same Resolve build -- the
  # scripting library is version-locked to the app it talks to.
  resolveApp = pkgs-unstable.davinci-resolve-studio.davinci;

  # fusionscript.so is a CPython extension that the scripting module dlopens.
  # Its DT_NEEDED list is a mix of libraries Resolve ships (libc++, libtbbmalloc,
  # libluajit) and ones a normal distro provides (libuuid, libX11, libxkbcommon)
  # -- inside the FHS sandbox both sets sit under /opt/resolve and /usr/lib and
  # it just resolves. Out here neither is on any search path, so loading it
  # straight from the store fails on `libuuid.so.1: cannot open shared object
  # file'.
  #
  # An RPATH rather than LD_LIBRARY_PATH in the wrapper: LD_LIBRARY_PATH takes
  # precedence over the DT_RUNPATH that every nixpkgs binary relies on, so
  # putting Resolve's 380-library directory on it would let its bundled
  # libavcodec/libssl/libc++ hijack the Python interpreter's own dependencies.
  # An RPATH on this one file is scoped to this one file.
  #
  # The DaVinciResolveScript module's fallback path is /opt/resolve, so
  # RESOLVE_SCRIPT_LIB below has to point at this patched copy: the module tries
  # $RESOLVE_SCRIPT_LIB, swallows any ImportError, and silently falls back --
  # which is why the unpatched path fails with a confusing "no such file
  # /opt/resolve/..." rather than the real missing-library error.
  fusionscript = pkgs.runCommand "fusionscript-patched" { nativeBuildInputs = [ pkgs.patchelf ]; } ''
    mkdir -p "$out/lib"
    cp ${resolveApp}/libs/Fusion/fusionscript.so "$out/lib/"
    chmod +w "$out/lib/fusionscript.so"
    patchelf --set-rpath ${
      lib.concatStringsSep ":" [
        "${resolveApp}/libs"
        "${resolveApp}/libs/Fusion"
        (lib.makeLibraryPath [
          pkgs.util-linux.lib
          pkgs.xorg.libX11
          pkgs.libxkbcommon
          pkgs.stdenv.cc.cc.lib
        ])
      ]
    } "$out/lib/fusionscript.so"
  '';

  # mcp is the only non-stdlib import that matters (numpy and anyio come along
  # for a handful of analysis tools). requirements.txt asks for `mcp>=1.29,<2';
  # unstable carries 1.27.1 and the server starts and serves its full tool list
  # on it, so the floor is conservative rather than load-bearing. If a future
  # bump does break, that constraint is the first thing to check.
  pythonEnv = pkgs-unstable.python3.withPackages (ps: [
    ps.mcp
    ps.numpy
    ps.anyio
  ]);

  version = "2.98.4";
in
{
  home.packages = [
    (pkgs.stdenv.mkDerivation {
      pname = "davinci-resolve-mcp";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "samuelgursky";
        repo = "davinci-resolve-mcp";
        # Pinned by commit, not tag: upstream moves fast and re-cuts releases.
        # To bump: set the rev, blank the hash, rebuild, paste the hash nix
        # prints back in.
        rev = "22cfafb1f52fd7c323d905ccfc0255519b23d23f";
        hash = "sha256-fHNAFoPs6l3xwoj21O3iC8JnIXux2ZeoRtXKDvSdoyg=";
      };

      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontBuild = true;
      dontConfigure = true;

      # resolve_mcp_server.py derives the project root from its own __file__ and
      # imports `src.granular', so `src' has to keep its name and its parent.
      # Everything it writes at runtime (transport state, analysis cache) goes to
      # ~/.davinci-resolve-mcp or ~/Documents, so a read-only store copy is fine.
      installPhase = ''
        runHook preInstall

        mkdir -p "$out/share/davinci-resolve-mcp"
        cp -r src "$out/share/davinci-resolve-mcp/"

        makeWrapper ${pythonEnv}/bin/python "$out/bin/davinci-resolve-mcp" \
          --add-flags "$out/share/davinci-resolve-mcp/src/resolve_mcp_server.py" \
          --set RESOLVE_SCRIPT_API "${resolveApp}/Developer/Scripting" \
          --set RESOLVE_SCRIPT_LIB "${fusionscript}/lib/fusionscript.so" \
          --set-default DAVINCI_RESOLVE_MCP_UPDATE_CHECK 0

        runHook postInstall
      '';

      meta = {
        description = "MCP server exposing DaVinci Resolve's scripting API";
        homepage = "https://github.com/samuelgursky/davinci-resolve-mcp";
        license = lib.licenses.mit;
        mainProgram = "davinci-resolve-mcp";
        platforms = lib.platforms.linux;
      };
    })
  ];
}
