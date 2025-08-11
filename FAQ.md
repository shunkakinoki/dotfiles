# FAQ

## Dock items lost on reboot (macOS)

If you experience your Dock items being lost on every reboot, you might be encountering an issue related to `com.apple.dock.plist` becoming read-only or corrupted. This can sometimes be resolved by running the following commands in your terminal:

```bash
defaults delete com.apple.dock
killall Dock
```

After running these commands, you may need to re-add your desired applications to the Dock. Subsequent reboots should then persist your Dock configuration.

For more details, see [nix-darwin issue #789](https://github.com/LnL7/nix-darwin/issues/789).
