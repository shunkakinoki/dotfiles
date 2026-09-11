{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  serveRoutes = import ./routes.nix;
  hostName = inputs.host.nodeName;
  hostServeRoutes = serveRoutes.${hostName} or [ ];
  activationServeRoutes = lib.filter (route: route.manager == "activation") hostServeRoutes;
  activationServeRouteArgs = lib.concatMap (route: [
    (toString route.httpsPort)
    (toString route.localPort)
  ]) activationServeRoutes;
  routeNames = map (route: route.name) hostServeRoutes;
  routePorts = map (route: route.httpsPort) hostServeRoutes;
  supportedManagers = [
    "activation"
    "t3-service"
  ];
in
{
  options.modules.tailscale.manageServeRoutes = lib.mkEnableOption "this host's Tailscale Serve routes";

  config = lib.mkIf config.modules.tailscale.manageServeRoutes {
    assertions = [
      {
        assertion = lib.length routeNames == lib.length (lib.unique routeNames);
        message = "Tailscale Serve route names must be unique for ${hostName}";
      }
      {
        assertion = lib.length routePorts == lib.length (lib.unique routePorts);
        message = "Tailscale Serve HTTPS ports must be unique for ${hostName}";
      }
      {
        assertion = lib.all (route: lib.elem route.manager supportedManagers) hostServeRoutes;
        message = "Tailscale Serve routes for ${hostName} use an unsupported manager";
      }
      {
        assertion = lib.all (
          route:
          builtins.isInt route.httpsPort
          && route.httpsPort > 0
          && route.httpsPort <= 65535
          && builtins.isInt route.localPort
          && route.localPort > 0
          && route.localPort <= 65535
        ) hostServeRoutes;
        message = "Tailscale Serve routes for ${hostName} must use valid ports";
      }
    ];

    home.activation.tailscaleServeRoutes = lib.mkIf (activationServeRoutes != [ ]) (
      config.lib.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../activation/ensure-tailscale-serve.sh}" ${lib.escapeShellArgs activationServeRouteArgs}
      ''
    );
  };
}
