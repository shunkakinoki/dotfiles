{
  inputs,
  username,
  ...
}:
let
  falconDebExists = builtins.pathExists /etc/nixos/falcon-sensor.deb;
in
import ../../hosts/nixos {
  inherit inputs username;
  hostname = "matic";
  userInitialPassword = "changemeow";
  userExtraGroups = [
    "input"
    "video"
    "audio"
    "docker"
  ];
  modules = [
    # Framework 13" AMD AI 300 hardware support
    inputs.nixos-hardware.nixosModules.framework-amd-ai-300-series

    # Hardware configuration
    ./hardware-configuration.nix

    # Kolide launcher
    ./kolide.nix

    # System configuration
    (
      {
        config,
        lib,
        pkgs,
        ...
      }:
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

        # Filesystem hardening
        boot.kernel.sysctl = {
          "fs.protected_regular" = 2;
          "fs.protected_fifos" = 2;
          "fs.protected_symlinks" = 1;
          "fs.protected_hardlinks" = 1;
        };

        # AMD power management kernel params
        boot.kernelParams = [
          "amdgpu.abmlevel=3" # auto backlight management
          "amdgpu.runpm=1" # runtime power management for GPU
          "amd_pstate=active" # AMD P-state driver (better than acpi-cpufreq)
          "amdgpu.dcdebugmask=0x410" # disable PSR and REPLAY to fix screen flickering
        ];

        # Networking
        networking.networkmanager.wifi.powersave = true;

        # Docker
        virtualisation.docker.enable = true;

        # Home Manager activation can take a long time (npm globals, cargo installs, etc.)
        systemd.services."home-manager-${username}".serviceConfig.TimeoutStartSec = lib.mkForce "30m";

        # Immutable root - prevents rm -rf / by blocking top-level entry removal
        systemd.services.immutable-root = {
          description = "Set immutable flag on /";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.e2fsprogs}/bin/chattr +i /";
            ExecStop = "${pkgs.e2fsprogs}/bin/chattr -i /";
          };
        };
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
          # Prevent powertop autosuspend on touchpad so idle detection works on battery
          ACTION=="add", SUBSYSTEM=="i2c", DRIVERS=="i2c_hid_acpi", ATTRS{name}=="PIXA3854:00 093A:0274", ATTR{power/control}="on"
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
        # Credential stored at /etc/credstore.encrypted/gnome-keyring.cred - create once with:
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
                #   2. send \x00 - daemon reads our UID via SO_PEERCRED
                #   3. send [oplen:4][op=1:4][pwlen:4][password bytes]
                #          where oplen = 8 + 4 + len(password)
                #   4. read [8:4][result:4] - result 0 = OK
                unlockPy = pkgs.writeScript "unlock-gnome-keyring.py" (
                  builtins.readFile (
                    pkgs.replaceVars ./unlock-gnome-keyring.py {
                      inherit (pkgs) python3;
                    }
                  )
                );

                # PAM exec script: runs as root, decrypts TPM credential, then
                # uses runuser to run the Python unlock as the target user.
                pamScript = pkgs.writeShellScript "pam-gnome-keyring-tpm-unlock" (
                  builtins.readFile (
                    pkgs.replaceVars ./pam-gnome-keyring-tpm-unlock.sh {
                      logger = "${pkgs.util-linux}/bin/logger";
                      systemd_creds = "${pkgs.systemd}/bin/systemd-creds";
                      id = "${pkgs.coreutils}/bin/id";
                      sleep = "${pkgs.coreutils}/bin/sleep";
                      env = "${pkgs.coreutils}/bin/env";
                      runuser = "${pkgs.util-linux}/bin/runuser";
                      unlock_py = unlockPy;
                    }
                  )
                );
              in
              {
                order = config.security.pam.services.greetd.rules.session.gnome_keyring.order + 10;
                control = "optional";
                modulePath = "${pkgs.pam}/lib/security/pam_exec.so";
                args = [
                  "type=open_session"
                  "${pamScript}"
                ];
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
        # Suspend on lid close
        services.logind.settings.Login.HandleLidSwitch = "suspend";
        services.logind.settings.Login.HandleLidSwitchExternalPower = "suspend";

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
        # Ensure fprintd is ready before greetd starts to avoid PAM fingerprint timeout
        systemd.services.greetd.after = [ "fprintd.service" ];
        systemd.services.greetd.wants = [ "fprintd.service" ];

        # Disk management
        services.gvfs.enable = true;
        services.udisks2.enable = true;

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
              "org.freedesktop.impl.portal.Settings" = [
                "darkman"
                "gtk"
              ];
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
          curl
          glibc
          libgcc
          libnl
          openssl
          zlib
        ];
      }
    )

    # Fonts
    (
      { pkgs, ... }:
      {
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
    )

    # Home Manager integration
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.backupFileExtension = "hm-backup";
      home-manager.extraSpecialArgs = {
        inputs = inputs // {
          host = (import ../../lib/host.nix) // {
            isDesktop = true;
          };
        };
      };
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username} =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          imports = [
            (import ../../home-manager {
              inherit username;
              inputs = inputs // {
                host = (import ../../lib/host.nix) // {
                  isDesktop = true;
                };
              };
              inherit (inputs.nixpkgs) lib;
              inherit pkgs;
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
                wallpaperId = "2826529529";
                scaling = "fill";
                fps = 1;
                audio.silent = true;
                extraOptions = [
                  "--no-audio-processing"
                  "--disable-mouse"
                  "--disable-parallax"
                  "--disable-particles"
                ];
              }
            ];
          };

          # Force RADV (hardware Vulkan) for wallpaper engine instead of lavapipe (software rendering)
          systemd.user.services.linux-wallpaperengine.Service.Environment = [
            "VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
          ];

          home.sessionVariables = {
            VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
          };

          # Pause animated wallpaper on battery to save power (SIGSTOP/SIGCONT)
          systemd.user.services.wallpaper-power-monitor = {
            Unit = {
              Description = "Pause wallpaper engine on battery, resume on AC";
              After = [ "linux-wallpaperengine.service" ];
              BindsTo = [ "linux-wallpaperengine.service" ];
            };
            Service = {
              Type = "simple";
              Restart = "on-failure";
              RestartSec = 5;
              ExecStart = pkgs.writeShellScript "wallpaper-power-check" (
                builtins.readFile (
                  pkgs.replaceVars ../../scripts/wallpaper-power-check.sh {
                    ac_supply_path = "/sys/class/power_supply/ACAD/online";
                    systemctl = "${pkgs.systemd}/bin/systemctl";
                    kill = "${pkgs.coreutils}/bin/kill";
                    sleep = "${pkgs.coreutils}/bin/sleep";
                  }
                )
              );
            };
            Install.WantedBy = [ "linux-wallpaperengine.service" ];
          };

          # Agenix configuration for GitHub SSH key
          age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
          age.secrets = builtins.mapAttrs (
            name: value:
            {
              inherit (value) file;
            }
            // (
              if name == "keys/id_github.age" then
                {
                  path = "/home/${username}/.ssh/id_ed25519_github";
                  mode = "0600";
                }
              else
                { }
            )
          ) (import ./secrets.nix);

          # Ensure SSH directory exists before agenix tries to deploy secrets
          home.activation.ensureSshDirectory = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.ssh"
          '';

          # Ensure agenix config directory exists
          home.activation.ensureAgenixDirectory = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/ensure-directory.sh}" "700" "${config.home.homeDirectory}/.config/agenix"
          '';

          # Manually deploy agenix secrets during activation
          home.activation.deployAgenixSecrets = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/deploy-agenix-secret.sh}" \
              "${config.home.homeDirectory}/.ssh/id_ed25519_github" \
              "${builtins.toString ../galactica/keys/id_ed25519.age}" \
              "${config.home.homeDirectory}/.ssh/id_ed25519" \
              "${pkgs.rage}/bin/rage"
          '';

          # Import GPG key from agenix (all systems with dotfiles)
          home.activation.importGpgKey = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
            $DRY_RUN_CMD ${pkgs.bash}/bin/bash "${../../home-manager/activation/import-gpg-key.sh}" \
              "${config.home.homeDirectory}/dotfiles/named-hosts/galactica/keys/gpg.age" \
              "${config.home.homeDirectory}/.ssh/id_ed25519" \
              "${config.home.homeDirectory}/.config/agenix" \
              "${pkgs.rage}/bin/rage" \
              "${pkgs.gnupg}/bin/gpg" \
              "C2E97FCFF482925D"
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
            defaultCacheTtl = 2147483647;
            maxCacheTtl = 2147483647;
          };

          # GPG_TTY is set in fish shell init instead of sessionVariables
          # because it needs to be evaluated dynamically per shell session
          programs.fish.interactiveShellInit = lib.mkAfter ''
            set -gx GPG_TTY (tty)
          '';
        };
    }
  ]
  ++ (if falconDebExists then [ ./falcon.nix ] else [ ]);
}
