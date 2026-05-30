{ pkgs, ... }:
{
  home.packages = with pkgs; [
    buf
    ghz
    grpcurl
    protobuf
  ];
}
