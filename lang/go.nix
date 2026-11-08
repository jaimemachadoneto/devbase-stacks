{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [ ../base.nix ];

  config = {
    base.stacks = [ "go" ];

    languages.go.enable = true;

    packages = with pkgs; [
      gopls
      golangci-lint
      gotools
    ];

    base.commands = {
      fmt = [ "gofmt -w ." ];
      lint = [ "golangci-lint run" ];
      check = [ "go test ./..." ];
      build = [ "go build ./..." ];
      run = [ "go run ." ];
    };
  };
}
