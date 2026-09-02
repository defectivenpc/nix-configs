{ ... }:

{
  services.yabai = {
    enable = true;

    config = {
      focus_follows_mouse = "autoraise";
      mouse_follows_focus = "off";
      window_placement = "second_child";
      window_opacity = "off";
      top_padding = 0;
      bottom_padding = 5;
      left_padding = 5;
      right_padding = 5;
      window_gap = 5;
      layout = "bsp";
    };
  };

  services.skhd = {
    enable = true;
    skhdConfig = ''
      alt - h : yabai -m window --focus west
      alt - l : yabai -m window --focus east
      alt - k : yabai -m window --focus north
      alt - j : yabai -m window --focus south
      shift + alt - h : yabai -m window --swap west
      shift + alt - l : yabai -m window --swap east
      shift + alt - k : yabai -m window --swap north
      shift + alt - j : yabai -m window --swap south
      alt - b : open -a "Brave Browser"
      alt - c : $(yabai -m window $(yabai -m query --windows --window | jq -re ".id") --close)
      alt - return : open -n /Applications/Nix\ Apps/Ghostty.app
    '';
  };
}
