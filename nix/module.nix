{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ai-setup;

  aiSetupScript = pkgs.callPackage ./package.nix { };

  playwrightChromium = pkgs.runCommand "playwright-chromium" { } ''
    ln -s ${pkgs.playwright-driver.browsers}/chromium-*/chrome-linux64/chrome $out
  '';

  aiSetupEnv = {
    AI_SETUP_DIR = cfg.checkout;
    AI_SETUP_REPO = cfg.repo;
    AI_SETUP_BRANCH = cfg.branch;
    AI_SETUP_FLEET = lib.concatStringsSep " " cfg.fleet;
  };

  playwrightEnv = lib.optionalAttrs cfg.playwright.enable {
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = "${playwrightChromium}";
  };

  aiSetup = pkgs.symlinkJoin {
    name = "ai-setup";
    paths = [ aiSetupScript ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/ai-setup ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "--set-default ${name} ${lib.escapeShellArg value}") (aiSetupEnv // playwrightEnv))}
    '';
  };

  toolchain = with pkgs; [ gh git jq python3 ripgrep ];

  playwrightTools = with pkgs; [ playwright-test playwright-mcp ];

  servicePath = lib.concatStringsSep ":" [
    (lib.makeBinPath ([ aiSetup ] ++ toolchain ++ playwrightTools))
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];
in
{
  options.programs.ai-setup = {
    enable = lib.mkEnableOption "the ai-setup agent skills, kept in sync across the fleet";

    checkout = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Projects/personal/ai-setup";
      description = "Live git checkout that skills are linked from. Edit skills here.";
    };

    repo = lib.mkOption {
      type = lib.types.str;
      default = "https://github.com/Barney241/ai-setup.git";
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
      description = "SSH hosts that `ai-setup push` and `ai-setup fleet` sync immediately.";
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
    home.packages = [ aiSetup ] ++ toolchain ++ lib.optionals cfg.playwright.enable playwrightTools;

    home.sessionVariables = aiSetupEnv // playwrightEnv;

    systemd.user.sessionVariables = aiSetupEnv // playwrightEnv;

    systemd.user.services.ai-setup-sync = {
      Unit.Description = "Fast-forward the ai-setup checkout and relink agent skills";
      Service = {
        Type = "oneshot";
        ExecStart = "${aiSetup}/bin/ai-setup sync";
        Environment = lib.mapAttrsToList (name: value: "${name}=${value}") (aiSetupEnv // playwrightEnv // { PATH = servicePath; });
      };
    };

    systemd.user.timers.ai-setup-sync = {
      Unit.Description = "Keep the ai-setup checkout in sync";
      Timer = {
        OnStartupSec = "1min";
        OnUnitActiveSec = cfg.interval;
        RandomizedDelaySec = "1min";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    home.activation.aiSetupLink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d ${lib.escapeShellArg cfg.checkout}/.git ]; then
        AI_SETUP_DIR=${lib.escapeShellArg cfg.checkout} run ${aiSetup}/bin/ai-setup link || true
      fi
    '';
  };
}
