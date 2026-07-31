{ ... }:
{
  # Syntax-highlighted pager for diff/show/log.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      line-numbers = true;
    };
  };

  programs.git = {
    enable = true;
    settings = {

      user.email = "onepunchlinux@gmail.com";
      user.name = "Michael Whitehead";

      core = {
        autocrlf = false;
        safecrlf = false;
        eol = "lf";
      };

      url = {
        "git@github.com:" = {
          insteadOf = "https://github.com/";
        };

        "https://github.com/rust-lang/crates.io-index" = {
          insteadOf = "https://github.com/rust-lang/crates.io-index";
        };

        "https://github.com/RustSec/advisory-db" = {
          insteadOf = "https://github.com/RustSec/advisory-db";
        };
      };
    };
  };
}
