{
  pkgs,
  lib,
  config,
  ...
}:
let
  pm = config.base.node.packageManager;
  manifest = "--manifest-path src-tauri/Cargo.toml";
in
{
  # A Tauri desktop app is a web front end (the node stack) and a Rust shell
  # in src-tauri/. The front end is the web app, so it gets the shared design
  # the same way. Importing node.nix here is safe: the module system loads a
  # file once, whatever imports it.
  imports = [
    ../base.nix
    ./node.nix
  ];

  config = {
    base.stacks = [ "tauri" ];

    languages.rust.enable = true;

    # WebKitGTK and its libraries on Linux. macOS uses the system WebKit.
    packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux (
      with pkgs;
      [
        pkg-config
        webkitgtk_4_1
        libsoup_3
        gtk3
        librsvg
        openssl
      ]
    );

    # HTTPS in the webview needs the GIO TLS module on Linux.
    env = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      GIO_MODULE_DIR = "${pkgs.glib-networking}/lib/gio/modules/";
    };

    # The node stack runs the package.json scripts; these add the Rust half.
    # `tauri build` runs the front-end build itself (beforeBuildCommand), so
    # build and run replace the node commands rather than add to them.
    base.commands = {
      fmt = [ "cargo fmt ${manifest}" ];
      lint = [ "cargo clippy ${manifest} --all-targets -- -D warnings" ];
      check = [ "cargo test ${manifest}" ];
      build = lib.mkForce [ "${pm} tauri build" ];
      run = lib.mkForce [ "${pm} tauri dev" ];
    };
  };
}
