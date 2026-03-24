# Matic (Framework 13 AMD AI 300)

## HDMI Capture Dongle

View another machine's display (e.g. Mac Mini) via a USB HDMI capture dongle.

### Prerequisites

Packages (`home-manager/packages/default.nix`, isDesktop):
- `mpv` — video player
- `v4l-utils` — device listing/troubleshooting

User groups (`named-hosts/matic/default.nix`):
- `video` — access to capture device
- `audio` — access to audio stream

### Usage

1. Plug the HDMI capture dongle into the Framework USB port
2. Connect an HDMI cable from the source machine to the dongle
3. Identify the device:

```sh
v4l2-ctl --list-devices
```

4. Open the video feed (replace `/dev/video0` with the correct device):

```sh
mpv av://v4l2:/dev/video0 --profile=low-latency --untimed
```

For audio passthrough (if the dongle supports it):

```sh
mpv av://v4l2:/dev/video0 --profile=low-latency --untimed --audio-device=auto
```
