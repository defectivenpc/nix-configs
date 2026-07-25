{ pkgs, pkgs-unstable }:

let
  version = "2.1.219";
  baseUrl = "https://downloads.claude.ai/claude-code-releases";
  platforms = {
    "aarch64-darwin" = {
      key = "darwin-arm64";
      sha256 = "a8e806faaefac53c7a0f26523d8a45c60dbef3407b14ef990c75765d08febc82";
    };
    "x86_64-darwin" = {
      key = "darwin-x64";
      sha256 = "03be9f988ed88391b4a5f08e4c5dc317ce2fffa4a9dc66c01106326e7698ee76";
    };
    "aarch64-linux" = {
      key = "linux-arm64";
      sha256 = "1f834b322ba9d1291cc7ffeff16a6795a59145bda279dbd59cd7ecebc7b7f15a";
    };
    "x86_64-linux" = {
      key = "linux-x64";
      sha256 = "22cfd6f5b3061c0391ba84e9cf8c9deaa37783aac18b004d42ec061e98f00691";
    };
  };
  p = platforms.${pkgs.stdenv.hostPlatform.system};
in
pkgs-unstable.claude-code.overrideAttrs (_: {
  inherit version;
  src = pkgs.fetchurl {
    url = "${baseUrl}/${version}/${p.key}/claude";
    sha256 = p.sha256;
  };
})
