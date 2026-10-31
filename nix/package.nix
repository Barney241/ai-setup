{ lib, writeShellApplication, git, openssh, coreutils, gnugrep, gnused, jq, curl }:

writeShellApplication {
  name = "ai-setup";
  runtimeInputs = [ git openssh coreutils gnugrep gnused jq curl ];
  text = lib.removePrefix "#!/usr/bin/env bash\n" (builtins.readFile ../bin/ai-setup);
}
