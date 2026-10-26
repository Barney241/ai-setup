{ config, lib, pkgs, ... }:

let
  cfg = config.programs.loadout;

  loadout = pkgs.callPackage ./package.nix { };

  playwrightChromium = pkgs.runCommand "playwright-chromium" { } ''
    ln -s ${pkgs.playwright-driver.browsers}/chromium-*/chrome-linux64/chrome $out
  '';

  loadoutEnv = {
    LOADOUT_DIR = cfg.checkout;
    LOADOUT_REPO = cfg.repo;
    LOADOUT_BRANCH = cfg.branch;
    LOADOUT_FLEET = lib.concatStringsSep " " cfg.fleet;
  };

  playwrightEnv = lib.optionalAttrs cfg.playwright.enable {
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${playwrightChromium}";
  };

  toolchain = with pkgs; [ gh git jq python3 ripgrep ];

  playwrightTools = with pkgs; [ playwright-test playwright-mcp ];

  servicePath = lib.concatStringsSep ":" [
    (lib.makeBinPath ([ loadout ] ++ toolchain ++ playwrightTools))
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];
in
{
  options.programs.loadout = {
    enable = lib.mkEnableOption "the loadout agent skills, kept in sync across the fleet";

    checkout = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Projects/personal/loadout";
      description = "Live git checkout that skills are linked from. Edit skills here.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Barney241/loadout.git";
      description = "Remote the checkout is cloned from and pushed to.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch to track.";
    };

    fleet = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "desktop" "laptop" "server" ];
      description = "SSH hosts that `loadout push` and `loadout fleet` sync immediately.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = "How often every host fast-forwards its checkout.";
    };

    playwright.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the Playwright CLI and MCP server with a Nix Chromium that runs on NixOS.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ loadout ] ++ toolchain ++ lib.optionals cfg.playwright.enable playwrightTools;

    home.sessionVariables = loadoutEnv // playwrightEnv;

    systemd.user.sessionVariables = loadoutEnv // playwrightEnv;

    systemd.user.services.loadout-sync = {
      Unit.Description = "Fast-forward the loadout checkout and relink agent skills";
      Service = {
        Type = "oneshot";
        ExecStart = "${loadout}/bin/loadout sync";
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") (loadoutEnv // playwrightEnv // { PATH = servicePath; });
      };
    };

    systemd.user.timers.loadout-sync = {
      Unit.Description = "Keep the loadout checkout in sync";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = cfg.interval;
        RandomizedDelaySec = "1min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    home.activation.loadoutLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d ${lib.escapeShellArg cfg.checkout}/.git ]; then
        LOADOUT_DIR=${lib.escapeShellArg cfg.checkout} run ${loadout}/bin/loadout link || true
      fi
    '';
  };
}
