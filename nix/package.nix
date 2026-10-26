{ lib, writeShellApplication, git, openssh, coreutils, gnugrep, jq }:

writeShellApplication {
  name = "loadout";
  runtimeInputs = [ git openssh coreutils gnugrep jq ];
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ../bin/loadout);
}
