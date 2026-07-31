{ pkgs, ... }:
{
  home.packages = [
    (pkgs.writeShellScriptBin "z" ''
      is_dark() {
        if [[ "$(uname)" == "Darwin" ]]; then
          defaults read -g AppleInterfaceStyle 2>/dev/null | grep -q Dark
        else
          result=$(dbus-send --session --print-reply=literal \
            --dest=org.freedesktop.portal.Desktop \
            /org/freedesktop/portal/desktop \
            org.freedesktop.portal.Settings.Read \
            string:'org.freedesktop.appearance' \
            string:'color-scheme' 2>/dev/null)
          # color-scheme: 0=default, 1=dark, 2=light
          echo "$result" | grep -q "uint32 1"
        fi
      }

      if is_dark; then
        exec zellij "$@" options --theme gruvbox-dark
      else
        exec zellij "$@" options --theme gruvbox-light
      fi
    '')

  ];
  programs.zellij = {
    enable = true;
    settings = {
      pane_frames = false;
      theme = "gruvbox-dark";
      default_layout = "welcome";
      show_startup_tips = false;
      mouse_mode = true;
      session_serialization = true;
      copy_on_select = true;
      keybinds = {
        unbind = [
          "Ctrl g"
          "Ctrl o"
          "Ctrl p"
          "Ctrl n"
          "Ctrl h"
        ];
        normal = {
          "bind \"Alt p\"" = {
            SwitchToMode = "pane";
          };
          "bind \"Alt g\"" = {
            SwitchToMode = "locked";
          };
        };
        pane = {
          "bind \"Alt p\"" = {
            SwitchToMode = "Normal";
          };
        };
        locked = {
          "bind \"Alt g\"" = {
            SwitchToMode = "Normal";
          };
        };
        session = {
          "bind \"Alt o\"" = {
            SwitchToMode = "Normal";
          };
        };
        "shared_except \"session\" \"locked\"" = {
          "bind \"Alt o\"" = {
            SwitchToMode = "Session";
          };
        };
      };
    };
  };
}
