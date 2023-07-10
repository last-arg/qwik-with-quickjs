{ pkgs ? import <nixpkgs> { } }:
with pkgs;
mkShell {
  buildInputs = [
    zig
    quickjs
    clang
    binutils
    bintools
  ];
}
