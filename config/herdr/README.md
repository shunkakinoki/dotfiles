# OpenCode detection

After Home Manager installs or changes the detection manifest, run
`herdr server reload-agent-manifests` for the active server. This reloads
rules without restarting agents. Verify the active manifest and state with
`herdr agent explain <agent-name> --json`; local overrides take precedence
over bundled and remote manifests.
