{ ... }:
{
  xdg.configFile."pnpm/rc" = {
    source = ./rc;
    force = true;
  };
}
