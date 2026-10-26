{ lib, writeShellApplication, git, openssh, coreutils, gnugrep }:

writeShellApplication {
  name = "loadout";
  runtimeInputs = [ git openssh coreutils gnugrep ];
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ../bin/loadout);
}
