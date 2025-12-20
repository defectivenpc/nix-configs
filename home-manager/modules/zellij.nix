{ ... }:
{
  programs.zellij = {
    enable = true;
    settings = {
      pane_frames = false;
      theme = "catppuccin-macchiato";
      default_layout = "compact";
      show_startup_tips = false;
      mouse_mode = true;
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
