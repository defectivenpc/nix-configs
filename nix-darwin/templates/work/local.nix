{ pkgs, ... }:

{
  home-manager.sharedModules = [
    {
      programs.git.settings = {
        user.email = "you@work.example";
        user.name = "Michael Whitehead";
      };

      home.packages = with pkgs; [
        awscli2
      ];

      programs.ssh.matchBlocks."git.work.example" = {
        user = "git";
        identityFile = "~/.ssh/id_work";
      };
    }
  ];

  environment.systemPackages = with pkgs; [
    openconnect
  ];
}
