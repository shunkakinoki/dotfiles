{ pkgs, lib, ... }:
{
  programs = {
    git = {
      enable = true;
      lfs = {
        enable = true;
      };
      includes = [
        # Include GitAlias - update with: scripts/update-gitalias.sh
        { path = "${./gitalias.txt}"; }
      ];
      settings = {
        user = {
          name = "Shun Kakinoki";
          email = "shunkakinoki@gmail.com";
        };
        alias = {
          co = "checkout";
          lt = "log --tags --decorate --simplify-by-decoration --oneline";
          unshallow = "fetch --prune --tags --unshallow";
        };
        core = {
          editor = "nvim";
          compression = -1;
          autocrlf = "input";
          whitespace = "trailing-space,space-before-tab";
          precomposeunicode = true;
          ignorecase = false;
        };
        color = {
          diff = "auto";
          status = "auto";
          branch = "auto";
          ui = true;
        };
        advice = {
          addEmptyPathspec = false;
        };
        apply = {
          whitespace = "nowarn";
        };
        help = {
          autocorrect = 1;
        };
        grep = {
          extendRegexp = true;
          lineNumber = true;
        };
        push = {
          autoSetupRemote = true;
          default = "simple";
        };
        submodule = {
          fetchJobs = 4;
        };
        log = {
          showSignature = false;
        };
        format = {
          signOff = true;
        };
        rerere = {
          enabled = true;
        };
        pull = {
          ff = "only";
        };
        init = {
          defaultBranch = "main";
        };
        delta = {
          navigate = true;
          dark = true;
        };
        merge = {
          conflictStyle = "zdiff3";
        };
        commit = {
          gpgSign = true;
        };
        tag = {
          gpgSign = true;
        };
      };
      signing = {
        signByDefault = true;
        key = "shunkakinoki@gmail.com";
      };
      ignores = lib.splitString "\n" (builtins.readFile ./.gitignore.global);
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
