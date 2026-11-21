_: {
  # CLIProxy force-maps the paid DeepSeek routes back to these public aliases.
  # Keep Tokscale's pricing keys aligned with the client-visible model IDs.
  home.file.".config/tokscale/custom-pricing.json" = {
    source = ./custom-pricing.json;
  };
}
