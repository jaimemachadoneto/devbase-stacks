{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.base.node;
  pm = cfg.packageManager;

  # Only npm and pnpm understand --if-present, so guard on package.json instead
  # and keep the script's real exit code. Node is always in this shell.
  guarded =
    script:
    "if node -e 'const s=(require(\"./package.json\").scripts||{});process.exit(s[process.argv[1]]?0:1)' "
    + lib.escapeShellArg script
    + " 2>/dev/null; then ${pm} run "
    + lib.escapeShellArg script
    + "; else echo \"no '${script}' script in package.json\"; fi";
in
{
  imports = [ ../base.nix ];

  options.base.node = {
    packageManager = lib.mkOption {
      type = lib.types.enum [
        "npm"
        "pnpm"
        "yarn"
        "bun"
      ];
      default = "pnpm";
      description = "Package manager for this project. Only the chosen one is added to the shell.";
    };
    typescript = lib.mkEnableOption "TypeScript toolchain" // {
      default = true;
    };
    # Browsers for Playwright come from nixpkgs, never from `playwright
    # install`. They only work with the same Playwright version, so pin
    # @playwright/test in package.json to the version the shell prints.
    playwright = lib.mkEnableOption "Playwright browsers from nixpkgs (Linux; on macOS Playwright uses its own cache)";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.playwright && pkgs.stdenv.hostPlatform.isLinux) {
      env = {
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
    })
    (lib.mkIf cfg.playwright {
      env.BASE_PLAYWRIGHT_VERSION = pkgs.playwright-driver.version;
      enterShell = ''
        pw_have="$(node -p 'require("./node_modules/@playwright/test/package.json").version' 2>/dev/null || true)"
        if [ -n "$pw_have" ] && [ "$pw_have" != "$BASE_PLAYWRIGHT_VERSION" ]; then
          printf '\033[33m!\033[0m @playwright/test is %s, the browsers are for %s: pin "@playwright/test": "%s" in package.json\n' \
            "$pw_have" "$BASE_PLAYWRIGHT_VERSION" "$BASE_PLAYWRIGHT_VERSION"
        fi
        unset pw_have
      '';
    })
    {
      base.stacks = [ "node" ];

      languages.javascript = {
        enable = true;
        npm.enable = pm == "npm";
        pnpm.enable = pm == "pnpm";
        yarn.enable = pm == "yarn";
        bun.enable = pm == "bun";
      };

      languages.typescript.enable = cfg.typescript;

      # A fresh runner has no node_modules. The frozen flag keeps CI on the
      # committed lockfile; a project without one gets a plain install.
      base.testSetup = [
        ''
          if [ -f package.json ]; then
            if [ -f pnpm-lock.yaml ] && [ "${pm}" = pnpm ]; then
              pnpm install --frozen-lockfile
            elif [ -f package-lock.json ] && [ "${pm}" = npm ]; then
              npm ci
            elif [ -f yarn.lock ] && [ "${pm}" = yarn ]; then
              yarn install --immutable
            else
              ${pm} install
            fi
          fi
        ''
      ];

      base.commands = {
        fmt = [ (guarded "format") ];
        lint = [ (guarded "lint") ];
        check = [ (guarded "test") ];
        build = [ (guarded "build") ];
        run = [ (guarded "dev") ];
      };
    }
  ];
}
