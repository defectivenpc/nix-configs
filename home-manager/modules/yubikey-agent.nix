{
  config,
  lib,
  pkgs,
  ...
}:

let
  socket = "${config.home.homeDirectory}/.yubikey-agent.sock";
  logFile = "${config.home.homeDirectory}/Library/Logs/yubikey-agent.log";
in
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    home.packages = [ pkgs.yubikey-agent ];

    launchd.agents.yubikey-agent = {
      enable = true;
      config = {
        ProgramArguments = [
          "${pkgs.yubikey-agent}/bin/yubikey-agent"
          "-l"
          socket
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardOutPath = logFile;
        StandardErrorPath = logFile;
      };
    };

    home.sessionVariablesExtra = ''
      case "$SSH_AUTH_SOCK" in
        "" | /var/run/com.apple.launchd.*/Listeners)
          export SSH_AUTH_SOCK="${socket}"
          ;;
      esac
    '';
  };
}
