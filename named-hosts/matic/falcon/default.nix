# CrowdStrike Falcon sensor package for NixOS
#
# Prerequisites:
# 1. Obtain the Falcon sensor .deb from IT
# 2. Place it at: /etc/nixos/falcon-sensor.deb
#    sudo cp ~/Downloads/falcon-sensor*.deb /etc/nixos/falcon-sensor.deb
# 3. Update the version below to match if different
{
  stdenv,
  lib,
  pkgs,
  dpkg,
  openssl,
  libnl,
  zlib,
  autoPatchelfHook,
  buildFHSEnv,
  ...
}:
let
  pname = "falcon-sensor";
  version = "7.31.0-18410";
  arch = "amd64";

  # Use absolute path outside the flake (gitignored files aren't visible to flakes)
  src = /etc/nixos/falcon-sensor.deb;

  falcon-sensor = stdenv.mkDerivation {
    name = pname;
    inherit version arch src;

    buildInputs = [
      dpkg
      zlib
      autoPatchelfHook
    ];
    sourceRoot = ".";

    unpackPhase = ''
      dpkg-deb -x $src .
    '';

    installPhase = ''
      cp -r . $out
    '';

    meta = with lib; {
      description = "CrowdStrike Falcon Sensor";
      homepage = "https://www.crowdstrike.com/";
      license = licenses.unfree;
      platforms = platforms.linux;
    };
  };
in
buildFHSEnv {
  name = "fs-bash";
  targetPkgs = pkgs: [
    libnl
    openssl
    zlib
  ];

  extraInstallCommands = ''
    ln -s ${falcon-sensor}/* $out/
  '';

  runScript = "bash";
}
