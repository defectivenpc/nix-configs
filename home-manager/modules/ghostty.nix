{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;

    package = pkgs.ghostty-bin;

    settings = {
      theme = "light:Gruvbox Material Light,dark: Gruvbox Material Dark";
      font-size = 14;
      quit-after-last-window-closed = true;
      keybind = [
        "cmd+a=text:\\x01"
        "cmd+b=text:\\x02"
        "cmd+c=text:\\x03"
        "cmd+d=text:\\x04"
        "cmd+e=text:\\x05"
        "cmd+f=text:\\x06"
        "cmd+g=text:\\x07"
        "cmd+h=text:\\x08"
        "cmd+i=text:\\x09"
        "cmd+j=text:\\x0A"
        "cmd+k=text:\\x0B"
        "cmd+l=text:\\x0C"
        "cmd+m=text:\\x0D"
        "cmd+n=text:\\x0E"
        "cmd+o=text:\\x0F"
        "cmd+p=text:\\x10"
        "cmd+q=text:\\x11"
        "cmd+r=text:\\x12"
        "cmd+s=text:\\x13"
        "cmd+t=text:\\x14"
        "cmd+u=text:\\x15"
        "cmd+v=text:\\x16"
        "cmd+w=text:\\x17"
        "cmd+x=text:\\x18"
        "cmd+y=text:\\x19"
        "cmd+z=text:\\x1A"
        "cmd+shift+c=copy_to_clipboard"
        "cmd+shift+v=paste_from_clipboard"
        "shift+enter=text:\\n"
      ];
    };

  };
}
