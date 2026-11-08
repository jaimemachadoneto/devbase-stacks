{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.base.cpp;
in
{
  imports = [ ../base.nix ];

  options.base.cpp = {
    buildDir = lib.mkOption {
      type = lib.types.str;
      default = "build";
      description = "CMake build directory, relative to the project root.";
    };
  };

  config = {
    base.stacks = [ "cpp" ];

    languages.cplusplus.enable = true;

    packages = with pkgs; [
      cmake
      ninja
      clang-tools # clangd + clang-format
      lldb
    ];

    # clangd finds compile_commands.json here; CMake writes it into buildDir.
    env.CMAKE_EXPORT_COMPILE_COMMANDS = "ON";

    base.commands = {
      fmt = [
        "find . -path ./${cfg.buildDir} -prune -o \\( -name '*.cpp' -o -name '*.hpp' -o -name '*.h' -o -name '*.cc' \\) -print0 | xargs -0 -r clang-format -i"
      ];
      lint = [
        "cmake --build ${cfg.buildDir} --target clang-tidy 2>/dev/null || echo 'no clang-tidy target'"
      ];
      build = [
        "cmake -S . -B ${cfg.buildDir} -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON"
        "cmake --build ${cfg.buildDir}"
      ];
      check = [ "ctest --test-dir ${cfg.buildDir} --output-on-failure" ];
    };

    enterShell = ''
      # Keep a stable compile_commands.json at the root for editors and clangd.
      if [ -f "${cfg.buildDir}/compile_commands.json" ] && [ ! -e compile_commands.json ]; then
        ln -sf "${cfg.buildDir}/compile_commands.json" compile_commands.json
      fi
    '';
  };
}
