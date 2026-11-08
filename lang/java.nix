{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.base.java;

  # Run cmd only if the build file actually configures the plugin, so a project
  # without it gets a clear message instead of a confusing Maven/Gradle error.
  guard =
    needle: files: cmd: label:
    ''if grep -qs ${lib.escapeShellArg needle} ${files}; then ${cmd}; else echo "no ${label} plugin configured in this project"; fi'';

  # Prefer the project's own wrapper when it ships one: it pins the Gradle
  # version the build was tested against, which need not be the version this
  # shell provides -- and a whole major version of drift is normal. Falls back
  # to the shell's gradle for a project with no wrapper checked in.
  gradle = args: "if [ -x ./gradlew ]; then ./gradlew ${args}; else gradle ${args}; fi";
in
{
  imports = [ ../base.nix ];

  options.base.java = {
    jdk = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jdk21_headless;
      description = "JDK used for this project. Pin per project rather than installing a JDK globally.";
    };
    builder = lib.mkOption {
      type = lib.types.enum [
        "maven"
        "gradle"
        "none"
      ];
      default = "maven";
      description = "Build tool wired into the `build`/`check`/`lint` verbs.";
    };
  };

  config = {
    base.stacks = [ "java" ];

    # Maven's transfer progress uses carriage returns, which makes CI logs and
    # captured output unreadable. Maven 3.9+ reads MAVEN_ARGS.
    env = lib.mkIf (cfg.builder == "maven") {
      MAVEN_ARGS = "--batch-mode --no-transfer-progress";
    };

    languages.java = {
      enable = true;
      jdk.package = cfg.jdk;
      maven.enable = cfg.builder == "maven";
      gradle.enable = cfg.builder == "gradle";
    };

    base.commands = lib.mkMerge [
      (lib.mkIf (cfg.builder == "maven") {
        # Guard on the plugin being configured rather than swallowing failures
        # with `|| true`, which would hide a real formatting error.
        fmt = [
          (guard "spotless-maven-plugin" "pom.xml" "mvn -q spotless:apply" "spotless")
        ];
        lint = [ "mvn -q -DskipTests verify" ];
        check = [ "mvn test" ];
        build = [ "mvn -DskipTests package" ];
        run = [
          (guard "exec-maven-plugin" "pom.xml" "mvn -q exec:java" "exec-maven-plugin")
        ];
      })
      (lib.mkIf (cfg.builder == "gradle") {
        fmt = [
          (guard "spotless" "build.gradle build.gradle.kts" (gradle "spotlessApply") "spotless")
        ];
        lint = [ (gradle "check -x test") ];
        check = [ (gradle "test") ];
        build = [ (gradle "assemble") ];
        run = [ (gradle "run") ];
      })
    ];
  };
}
