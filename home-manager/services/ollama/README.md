# Ollama server ownership

On Galactica, Home Manager supplies the Nix Ollama package and owns the only
managed server through `org.nix-community.home.ollama`. Its launch-agent
environment binds the server to `127.0.0.1:11434`, independently of GUI-session
environment values.

Homebrew does not manage an Ollama formula or GUI cask. Homebrew activation uses
uninstall cleanup, preserving the shared `~/.ollama` models and user settings
when removing the GUI app. Do not zap the old app or delete the model directory.

After activation, verify the GUI app has quit, the managed launch agent uses its
Nix executable, and port 11434 has only a loopback listener. Requests from a
different tailnet device must fail to connect. Existing models remain in place.
