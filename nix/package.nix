{ lib, writeShellApplication, git, openssh, coreutils, gnugrep, jq }:

writeShellApplication {
  name = "ai-setup";
  runtimeInputs = [ git openssh coreutils gnugrep jq ];
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ../bin/ai-setup);
}
