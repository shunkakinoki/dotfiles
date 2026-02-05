# CrowdStrike Falcon sensor package for NixOS
#
# Prerequisites:
# 1. Obtain the Falcon sensor .deb from IT
# 2. Place it in this directory as: falcon-sensor_<version>_amd64.deb
# 3. Update the version below to match
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

  src = builtins.path {
    path = ./${pname}_${version}_${arch}.deb;
    name = "${pname}_${version}_${arch}.deb";
  };

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
