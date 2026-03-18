{
  inputs,
  username,
  ...
}:
let
  system = "x86_64-linux";
  nixpkgsConfig = import ../../lib/nixpkgs-config.nix {
    nixpkgsLib = inputs.nixpkgs.lib;
  };
  overlays = import ../../overlays { inherit inputs; };
  pkgs = import inputs.nixpkgs {
    inherit system overlays;
    config = nixpkgsConfig;
  };

  # Check if falcon .deb exists (for conditional import)
  # In CI, this will be false; locally with .deb present, it will be true
  falconDebExists = builtins.pathExists /etc/nixos/falcon-sensor.deb;
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = {
    inherit inputs username;
  };
  modules = [
    # Framework 13" AMD AI 300 hardware support
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series

    # Hardware configuration
    ./hardware-configuration.nix

    # Kolide launcher
    ./kolide.nix

    # Base system configuration
    (
      { config, lib, ... }:
      {
        # Boot loader (EFI/systemd-boot)
        boot.loader.systemd-boot.enable = true;
        boot.loader.systemd-boot.configurationLimit = 10;
        boot.loader.efi.canTouchEfiVariables = true;
        boot.loader.grub.enable = false;
        boot.loader.timeout = 3;

        # TPM2 auto-unlock for LUKS disk encryption
        boot.initrd.systemd.enable = true;
        boot.initrd.luks.devices."luks-4a2ddfc4-1a40-4e18-99f5-250baf72b4ac".crypttabExtraOpts = [
          "tpm2-device=auto"
        ];

        # Pin kernel to 6.18 for CrowdStrike Falcon compatibility (RFM on 6.19)
        boot.kernelPackages = pkgs.linuxPackages_6_18;

        # AMD power management kernel params
        boot.kernelParams = [
          "amdgpu.abmlevel=3" # auto backlight management
          "amdgpu.runpm=1" # runtime power management for GPU
          "amd_pstate=active" # AMD P-state driver (better than acpi-cpufreq)
        ];

        # Networking
        networking.hostName = "matic";
        networking.networkmanager.enable = true;
        networking.networkmanager.wifi.powersave = true;

        # Enable fish shell
        programs.fish.enable = true;

        # User configuration
        users.users.${username} = {
          isNormalUser = true;
          extraGroups = [
            "wheel"
            "networkmanager"
            "input"
            "video"
            "docker"
          ];
          home = "/home/${username}";
          shell = pkgs.fish;
          initialPassword = "changemeow"; # Change this after first login with: passwd
        };

        # Docker
        virtualisation.docker.enable = true;

        security.sudo.wheelNeedsPassword = false;
        # Keyd configuration (Linux desktop only)
        services.keyd.enable = true;
        users.groups.keyd = { };
        systemd.services.keyd.serviceConfig = {
          CapabilityBoundingSet = [ "CAP_SETGID" ];
          AmbientCapabilities = [ "CAP_SETGID" ];
        };
        systemd.services.keyd.restartTriggers = [
          (builtins.hashFile "sha256" ../../config/keyd/default.conf)
        ];
        environment.etc."keyd/default.conf".source = ../../config/keyd/default.conf;

        # Input remapping (xremap)
        hardware.uinput.enable = true;
        services.udev.extraRules = ''
          KERNEL=="uinput", GROUP="input", TAG+="uaccess", MODE:="0660", OPTIONS+="static_node=uinput"
          KERNEL=="event*", ATTRS{name}=="keyd virtual keyboard", GROUP="input", MODE:="0660"
          KERNEL=="event*", ATTRS{name}=="keyd virtual pointer", GROUP="input", MODE:="0660"
        '';

        # AMD graphics with hardware acceleration
        hardware.graphics.enable = true;
        hardware.graphics.extraPackages = with pkgs; [
          libva
          libva-vdpau-driver
          libvdpau-va-gl
        ];

        # Thunderbolt support
        services.hardware.bolt.enable = true;

        # GNOME Keyring - auto-unlocks GPG key on login via PAM
        services.gnome.gnome-keyring.enable = true;

        # Unlock GNOME Keyring via TPM2 credential at login (PAM exec).
        # Runs in the PAM session stack right after pam_gnome_keyring starts the daemon,
        # so there are no timing/retry issues. Runs as root (can access TPM), then uses
        # runuser to speak the control socket protocol as the target user (SO_PEERCRED).
        #
        # Credential stored at /etc/credstore.encrypted/gnome-keyring.cred — create once with:
        #   sudo bash -c 'mkdir -p /etc/credstore.encrypted && \
        #     systemd-ask-password "Keyring password:" | \
        #     systemd-creds encrypt --name=gnome-keyring --with-key=tpm2+host \
        #     - /etc/credstore.encrypted/gnome-keyring.cred'

        # Fingerprint authentication
        services.fprintd.enable = true;
        security.pam.services.greetd = {
          fprintAuth = true;
          enableGnomeKeyring = true;
          rules.session = {
            # Run after pam_gnome_keyring (which starts the daemon but can't unlock
            # on fingerprint login). Decrypts the TPM2 credential and sends the
            # password to the running daemon via the control socket protocol.
            gnome_keyring_tpm_unlock =
              let
                # Speaks the gnome-keyring control socket protocol directly.
                # gnome-keyring-daemon --unlock (v48) ignores GNOME_KEYRING_CONTROL
                # and always starts a new instance, so we bypass it entirely.
                #
                # Protocol (all big-endian):
                #   1. connect to $XDG_RUNTIME_DIR/keyring/control (UNIX stream)
                #   2. send \x00 — daemon reads our UID via SO_PEERCRED
                #   3. send [oplen:4][op=1:4][pwlen:4][password bytes]
                #          where oplen = 8 + 4 + len(password)
                #   4. read [8:4][result:4] — result 0 = OK
                unlockPy = pkgs.writeScript "unlock-gnome-keyring.py" ''
                  #!${pkgs.python3}/bin/python3
                  import os, socket, struct, stat, sys

                  def unlock(password):
                      uid = os.getuid()
                      xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
                      sock_path = os.path.join(xdg, "keyring", "control")
                      st = os.lstat(sock_path)
                      if not stat.S_ISSOCK(st.st_mode) or st.st_uid != uid:
                          raise RuntimeError(f"bad socket: {sock_path}")
                      pw = password.encode()
                      oplen = 8 + 4 + len(pw)
                      pkt = struct.pack(">II", oplen, 1) + struct.pack(">I", len(pw)) + pw
                      with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                          s.connect(sock_path)
                          s.sendall(b"\x00")
                          s.sendall(pkt)
                          resp = b""
                          while len(resp) < 8:
                              resp += s.recv(8 - len(resp))
                      _, result = struct.unpack(">II", resp)
                      return result

                  pw = sys.stdin.read().rstrip("\n")
                  result = unlock(pw)
                  codes = {0: "OK", 1: "DENIED", 2: "FAILED", 3: "NO_DAEMON"}
                  print(f"gnome-keyring unlock: {codes.get(result, result)}", flush=True)
                  sys.exit(0 if result == 0 else 1)
                '';

                # PAM exec script: runs as root, decrypts TPM credential, then
                # uses runuser to run the Python unlock as the target user.
                pamScript = pkgs.writeShellScript "pam-gnome-keyring-tpm-unlock" ''
                  log() { echo "gnome-keyring-tpm: $*" | ${pkgs.util-linux}/bin/logger -t gnome-keyring-tpm; }
                  CRED="/etc/credstore.encrypted/gnome-keyring.cred"
                  [ -f "$CRED" ] || exit 0

                  # Decrypt synchronously — requires root/TPM access (not available after fork).
                  PW=$(${pkgs.systemd}/bin/systemd-creds decrypt --name=gnome-keyring "$CRED" -)
                  if [ -z "$PW" ]; then
                    log "credential decrypt failed"
                    exit 1
                  fi

                  # The gnome-keyring-daemon p11-kit backend is not fully initialized at
                  # PAM session-open time — unlock attempts at this point return DENIED.
                  # Fork a background retry loop so login is never blocked; the daemon
                  # is ready within a few seconds of the user session starting.
                  USER_UID=$(id -u "$PAM_USER")
                  # Skip system/greeter users (uid < 1000)
                  [ "$USER_UID" -lt 1000 ] && exit 0
                  SOCK="/run/user/$USER_UID/keyring/control"
                  (
                    for attempt in 1 2 3 4 5 6 7 8; do
                      sleep 3
                      [ -S "$SOCK" ] || { log "attempt $attempt: socket not found"; continue; }
                      OUT=$(printf '%s' "$PW" | \
                        ${pkgs.util-linux}/bin/runuser -u "$PAM_USER" -- \
                          ${pkgs.coreutils}/bin/env XDG_RUNTIME_DIR="/run/user/$USER_UID" \
                          ${unlockPy} 2>&1)
                      STATUS=$?
                      log "attempt $attempt: $OUT (exit $STATUS)"
                      [ "$STATUS" -eq 0 ] && break
                    done
                  ) &

                  exit 0
                '';
              in
              {
                order = config.security.pam.services.greetd.rules.session.gnome_keyring.order + 10;
                control = "optional";
                modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
                args = [ "${pamScript}" ];
              };
          };
        };
        security.pam.services.hyprlock = {
          fprintAuth = true;
        };
        security.pam.services.sudo = {
          fprintAuth = true;
        };

        # Firmware updates
        services.fwupd.enable = true;

        # Power management
        powerManagement.enable = true;
        powerManagement.powertop.enable = true;
        services.upower.enable = true;
        services.power-profiles-daemon.enable = false;
        services.auto-cpufreq = {
          enable = true;
          settings = {
            battery = {
              governor = "powersave";
              turbo = "never";
            };
            charger = {
              governor = "performance";
              turbo = "auto";
            };
          };
        };

        # Power button behavior - lock screen instead of shutdown
        services.logind.settings.Login.HandlePowerKey = "lock";
        # On battery: suspend immediately when lid closed
        # On AC: ignore lid close — let hypridle's 30-min idle timer handle suspension
        services.logind.settings.Login.HandleLidSwitch = "suspend";
        services.logind.settings.Login.HandleLidSwitchExternalPower = "ignore";

        # Auto timezone (via geolocation)
        services.geoclue2.enable = true;
        services.localtimed.enable = true;

        # Audio (PipeWire)
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          wireplumber.enable = true;
        };
        services.pulseaudio.enable = false;
        security.rtkit.enable = true;

        # Bluetooth
        hardware.bluetooth.enable = true;
        hardware.bluetooth.powerOnBoot = true;

        # Login manager (greetd + tuigreet)
        services.greetd = {
          enable = true;
          settings = {
            default_session = {
              command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --sessions /etc/greetd/wayland-sessions";
              user = "greeter";
            };
          };
        };

        # Disk management
        services.gvfs.enable = true; # For automounting external drives in Nautilus and managing disk permissions
        services.udisks2.enable = true; # For better integration with external drives, including NTFS support and proper permissions handling

        # Provide Hyprland session file for tuigreet to discover
        environment.etc."greetd/wayland-sessions/hyprland.desktop".text = ''
          [Desktop Entry]
          Name=Hyprland
          Exec=uwsm start hyprland-uwsm.desktop
          Type=Application
        '';

        programs.hyprland = {
          enable = true;
          package = pkgs.hyprland;
          portalPackage = pkgs.xdg-desktop-portal-hyprland;
          xwayland.enable = true;
          withUWSM = true;
        };

        # Steam (for Wallpaper Engine assets)
        programs.steam.enable = true;

        programs.dconf.enable = true;

        xdg.portal = {
          enable = true;
          extraPortals = with pkgs; [
            xdg-desktop-portal-gtk
          ];
          config = {
            hyprland = {
              default = [
                "hyprland"
                "gtk"
              ];
              "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
            };
          };
        };

        # WiFi MT7925e fix (disable ASPM)
        boot.extraModprobeConfig = ''
          options mt7925e disable_aspm=1
        '';

        # Enable nix-ld for running dynamically linked binaries (CrowdStrike, Kolide, etc.)
        programs.nix-ld.enable = true;
        programs.nix-ld.libraries = with pkgs; [
          # Common libraries needed by security tools
          glibc
          zlib
          openssl
          curl
          libnl
          libgcc
        ];

        # Nix settings
        nix = {
          settings = {
            experimental-features = [
              "nix-command"
              "flakes"
            ];
            trusted-users = [
              "root"
              username
            ];
          };
          package = pkgs.nixVersions.stable;
        };

        system.stateVersion = "24.11";
      }
    )

    # Fonts
    {
      nixpkgs.pkgs = pkgs;

      fonts.fontconfig.enable = true;
      fonts.packages = with pkgs; [
        inter
        ipaexfont
        ipafont
        joypixels
        nerd-fonts.jetbrains-mono
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
        noto-fonts-color-emoji
      ];
      fonts.fontconfig.defaultFonts = {
        serif = [
          "Noto Serif CJK JP"
          "DejaVu Serif"
        ];
        sansSerif = [
          "Inter"
          "Noto Sans CJK JP"
          "DejaVu Sans"
        ];
        monospace = [
          "JetBrainsMono Nerd Font"
          "Noto Sans Mono CJK JP"
        ];
        emoji = [
          "JoyPixels"
          "Noto Color Emoji"
        ];
      };
    }

    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = {
        # Override host detection for matic (isDesktop = true)
        inputs = inputs // {
          host = (import ../../lib/host.nix) // {
            isDesktop = true;
          };
        };
      };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} =
        { config, lib, ... }:
        {
          imports = [
            (import ../../home-manager {
              inherit username;
              # Override host detection for matic (isDesktop = true)
              inputs = inputs // {
                host = (import ../../lib/host.nix) // {
                  isDesktop = true;
                };
              };
              lib = inputs.nixpkgs.lib;
              pkgs = pkgs;
              config = { };
            })
          ];

          # Animated wallpaper via Wallpaper Engine
          services.linux-wallpaperengine = {
            enable = true;
            assetsPath = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/wallpaper_engine/assets";
            wallpapers = [
              {
                monitor = "eDP-1";
                wallpaperId = "3602362048";
                scaling = "fill";
                fps = 30;
                audio.silent = true;
              }
            ];
          };

          # Agenix configuration for GitHub SSH key
          age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
          age.secrets = builtins.mapAttrs (
            name: value:
            {
              file = value.file;
            }
            // (
              if name == "keys/id_github.age" then
                {
                  # Deploy GitHub SSH key to ~/.ssh/ with correct permissions
                  path = "/home/${username}/.ssh/id_ed25519_github";
                  mode = "0600";
                }
              else
                { }
            )
          ) (import ./secrets.nix);

          # Ensure SSH directory exists before agenix tries to deploy secrets
          home.activation.ensureSshDirectory = config.lib.dag.entryBefore [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.ssh
            $DRY_RUN_CMD chmod $VERBOSE_ARG 700 ${config.home.homeDirectory}/.ssh
          '';

          # Ensure agenix config directory exists
          home.activation.ensureAgenixDirectory = config.lib.dag.entryBefore [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p $VERBOSE_ARG ${config.home.homeDirectory}/.config/agenix
            $DRY_RUN_CMD chmod $VERBOSE_ARG 700 ${config.home.homeDirectory}/.config/agenix
          '';

          # Manually deploy agenix secrets during activation
          # This ensures secrets are deployed even if the agenix activation hook doesn't run properly
          home.activation.deployAgenixSecrets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
            # Decrypt and deploy GitHub SSH key if it doesn't exist
            if [[ ! -f "${config.home.homeDirectory}/.ssh/id_ed25519_github" ]]; then
              echo "Deploying GitHub SSH key from agenix..."
              SECRET_FILE="${builtins.toString ../galactica/keys/id_ed25519.age}"
              if [[ -f "$SECRET_FILE" ]]; then
                if $DRY_RUN_CMD ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 "$SECRET_FILE" -o ${config.home.homeDirectory}/.ssh/id_ed25519_github 2>/dev/null; then
                  $DRY_RUN_CMD chmod $VERBOSE_ARG 0600 ${config.home.homeDirectory}/.ssh/id_ed25519_github
                  echo "✅ GitHub SSH key deployed successfully"
                else
                  echo "⚠️  Warning: SSH key not authorized to decrypt — skipping"
                fi
              else
                echo "⚠️  Warning: Secret file not found at $SECRET_FILE"
              fi
            fi
          '';

          # Import GPG key from agenix (all systems with dotfiles)
          # Fails silently if SSH key isn't authorized to decrypt
          home.activation.importGpgKey = config.lib.dag.entryAfter [ "linkGeneration" ] ''
            $VERBOSE_ECHO "🔑 Starting GPG key import process..."
            GPG_SECRET_FILE="${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age"
            GPG_TEMP_FILE="${config.home.homeDirectory}/.config/agenix/gpg.key"

            # Create agenix directory if it doesn't exist
            mkdir -p "${config.home.homeDirectory}/.config/agenix"

            if [[ -f "$GPG_SECRET_FILE" ]]; then
              # Check if key is already imported
              if ! ${pkgs.gnupg}/bin/gpg --list-secret-keys 2>/dev/null | grep -q "C2E97FCFF482925D"; then
                echo "Importing GPG key from agenix..."
                # Try to decrypt - will fail silently if SSH key isn't authorized
                if ${pkgs.rage}/bin/rage -d -i ${config.home.homeDirectory}/.ssh/id_ed25519 -o "$GPG_TEMP_FILE" "$GPG_SECRET_FILE" 2>/dev/null; then
                  ${pkgs.gnupg}/bin/gpg --batch --import "$GPG_TEMP_FILE" 2>/dev/null
                  rm -f "$GPG_TEMP_FILE"
                  echo "✅ GPG key imported successfully"
                fi
              else
                $VERBOSE_ECHO "ℹ️  GPG key already imported"
              fi
            fi
          '';

          # GPG configuration for commit signing
          programs.gpg = {
            enable = true;
            settings = {
              default-key = "shunkakinoki@gmail.com";
            };
          };

          # GPG agent configuration
          services.gpg-agent = {
            enable = true;
            enableSshSupport = false;
            pinentry.package = pkgs.pinentry-gnome3;
            defaultCacheTtl = 2147483647; # max (effectively forever)
            maxCacheTtl = 2147483647; # max (effectively forever)
          };

          # GPG_TTY is set in fish shell init instead of sessionVariables
          # because it needs to be evaluated dynamically per shell session
          programs.fish.interactiveShellInit = lib.mkAfter ''
            set -gx GPG_TTY (tty)
          '';
        };
    }
  ]
  ++ (if falconDebExists then [ ./falcon.nix ] else [ ]); # CrowdStrike Falcon (only if .deb exists)
}
