# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # If set, NixOS will enforce the immutability of the Nix store by making /nix/store a read-only bind mount.
  # Manual https://nixos.org/manual/nixos/stable/options.html#opt-nix.readOnlyStore
  nix.readOnlyStore = true;

  # Linux kernel
  # Wiki https://nixos.wiki/wiki/Linux_kernel
  # Source https://github.com/NixOS/nixpkgs/blob/nixos-22.05/pkgs/os-specific/linux/kernel/
  # boot.kernelPackages = pkgs.linuxPackages; # LTS
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_0.override {
    argsOverride = rec {
      version = "6.0.5-rt14";
      modDirVersion = "6.0.5-rt14-isyana"; # localversion
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v6.x/linux-6.0.5.tar.xz";
        sha256 = "YTMu8itTxQwQ+qv7lliWp9GtTzOB8PiWQ8gg8opgQY4=";
      };
    };
  });
  # Source config https://github.com/NixOS/nixpkgs/blob/nixos-22.05/pkgs/os-specific/linux/kernel/common-config.nix
  boot.kernelPatches = [ {
      name = "rt";
      patch = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/projects/rt/6.0/older/patch-6.0.5-rt14.patch.xz";
        sha256 = "BkTq7aIWBfcd3Pmeq5cOPtoVVQYtQIQJSKlWvsmkcWc=";
      };
      extraConfig = ''
        LOCALVERSION -isyana
        PREEMPT_RT y
        EXPERT y
        PREEMPT_VOLUNTARY n
        RT_GROUP_SCHED n
	DRM_AMDGPU_SI n
	DRM_AMDGPU_CIK n
	DRM_AMD_DC_DCN1_0 n
        DRM_AMD_DC_PRE_VEGA n
        DRM_AMD_DC_DCN2_0 n
        DRM_AMD_DC_DCN2_1 n
        DRM_AMD_DC_DCN3_0 n
        DRM_AMD_DC_DCN n
        DRM_AMD_DC_HDCP n
        DRM_AMD_DC_SI n
	MICROCODE_AMD n
	PINCTRL_AMD n
	HSA_AMD n
	DRM_AMDGPU_USERPTR n
	X86_AMD_PLATFORM_DEVICE n
      '';
  } ];
  boot.kernelParams = [ "systemd.unified_cgroup_hierarchy=0" ];
  
  boot.kernel.sysctl."vm.swappiness" = 100;

  # QEMU/KVM
  boot.extraModprobeConfig = "options kvm_intel nested=1";

  # Use the systemd-boot EFI boot loader.
  boot.loader.timeout = 2; # timeout
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev"; # set "nodev" for EFI only
  boot.loader.grub.splashImage = null; # Remove background bootloader

  # zRAM configuration
  zramSwap.enable = true;
  zramSwap.memoryPercent = 100;

  # Optimising the store
  # Wiki https://nixos.wiki/wiki/Storage_optimization
  nix.settings.auto-optimise-store = true;

  networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Asia/Jakarta";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkbOptions in tty.
  # };
  
  # Enable Backlight Thinkpad
  # programs.light.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;
  services.xserver.displayManager.sddm.settings = {
    Theme = {
      CursorTheme = "breeze_cursors";
    };
  };

  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = {
  #   "eurosign:e";
  #   "caps:escape" # map caps to escape.
  # };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Wiki https://nixos.wiki/wiki/PipeWire
  # Enable sound.
  # sound.enable = true;
  hardware.pulseaudio.enable = false;
  # rtkit is optional but recommended
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
    # Some useful knobs if you want to finetune or debug your setup
    config.pipewire = {
      "context.properties" = {
        "link.max-buffers" = 16; # version < 3 clients can't handle more than this
        "log.level" = 2; # https://docs.pipewire.org/page_daemon.html
        "default.clock.rate" = 44100; # or you can set '48000'
        "default.clock.quantum" = 1024; # latency for recording
      };
      # Pro Audio
      "context.objects" = [
      {
        # A default dummy driver. This handles nodes marked with the "node.always-driver"
        # properyty when no other driver is currently active. JACK clients need this.
        factory = "spa-node-factory";
        args = {
          "factory.name"     = "support.node.driver";
          "node.name"        = "Dummy-Driver";
          "priority.driver"  = 8000;
        };
      }
      {
        factory = "adapter";
        args = {
          "factory.name"     = "support.null-audio-sink";
          "node.name"        = "Microphone-Proxy";
          "node.description" = "Microphone";
          "media.class"      = "Audio/Source/Virtual";
          "audio.position"   = "MONO";
        };
      }
      {
        factory = "adapter";
        args = {
          "factory.name"     = "support.null-audio-sink";
          "node.name"        = "Main-Output-Proxy";
          "node.description" = "Main Output";
          "media.class"      = "Audio/Sink";
          "audio.position"   = "FL,FR";
        };
      }
      ];
    };
    # Bluetooth Pipewire
    media-session.config.bluez-monitor.rules = [
      {
        # Matches all cards
        matches = [ { "device.name" = "~bluez_card.*"; } ];
        actions = {
          "update-props" = {
            "bluez5.reconnect-profiles" = [ "hfp_hf" "hsp_hs" "a2dp_sink" ];
            # mSBC is not expected to work on all headset + adapter combinations.
            "bluez5.msbc-support" = true;
            # SBC-XQ is not expected to work on all headset + adapter combinations.
            "bluez5.sbc-xq-support" = true;
          };
        };
      }
      {
        matches = [
          # Matches all sources
          { "node.name" = "~bluez_input.*"; }
          # Matches all outputs
          { "node.name" = "~bluez_output.*"; }
        ];
      }
    ];
    # PulseAudio backend
    config.pipewire-pulse = {
      "context.properties" = {
        "log.level" = 2;
      };
      "context.modules" = [
        {
          name = "libpipewire-module-rtkit";
          args = {
            "nice.level" = -15;
            "rt.prio" = 88;
            "rt.time.soft" = 200000;
            "rt.time.hard" = 200000;
          };
          flags = [ "ifexists" "nofail" ];
        }
        { name = "libpipewire-module-protocol-native"; }
        { name = "libpipewire-module-client-node"; }
        { name = "libpipewire-module-adapter"; }
        { name = "libpipewire-module-metadata"; }
        {
          name = "libpipewire-module-protocol-pulse";
          args = {
            "pulse.min.req" = "32/44100";
            "pulse.default.req" = "32/44100";
            "pulse.max.req" = "32/44100";
            "pulse.min.quantum" = "32/44100";
            "pulse.max.quantum" = "32/44100";
            "server.address" = [ "unix:native" ];
          };
        }
      ];
      "stream.properties" = {
        "node.latency" = "32/44100";
        "resample.quality" = 1;
      };
    };
    # Controlling the ALSA devices
    media-session.config.alsa-monitor = {
      rules = [
        {
          matches = [ { "node.name" = "alsa_output.*"; } ];
          actions = {
            update-props = {
              "audio.format" = "S32LE";
              "audio.rate" = 44100; # for USB soundcards it should be twice your desired rate
              "api.alsa.period-size" = 32; # defaults to 1024, tweak by trial-and-error
              # "api.alsa.disable-batch" = true; # generally, USB soundcards use the batch mode
            };
          };
        }
      ];
    };
    # End Pro Audio 
  };

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  nixpkgs.config.allowUnfree = true; # Allow Unfree packages
  
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.agung = {
    isNormalUser = true;
    uid = 1000;
    home = "/home/agung";
    description = "Agung Wijaya";
    extraGroups = [
      "wheel"
      "networkmanager"
      "adbusers"
      "docker"
      "disk"
      "audio"
      "video"
      "kvm"
      "render"
      "input"
      "uucp"
      "libvirtd"
      "wireshark"
      "vboxusers"
    ];
    packages = with pkgs; [
      vim
    ];
  };

  # Virt-manager
  virtualisation.libvirtd.enable = true;
  systemd.services.virsh-sessiond = {
      wantedBy = [ "multi-user.target" ]; 
      after = [ "network.target" ];
      description = "Start connect qemu for virbr0.";
      serviceConfig = {
        ExecStart = ''${pkgs.libvirt}/bin/virsh connect qemu:///system'';
      };
  };

  # Docker wiki https://nixos.wiki/wiki/Docker
  virtualisation.docker.enable = true;

  # VirtualBox wiki https://nixos.wiki/wiki/VirtualBox
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;

  # Environment variables
  # Wiki https://nixos.wiki/wiki/Environment_variables
  environment.sessionVariables = rec {
    # Wine https://wiki.archlinux.org/title/wine
    FREETYPE_PROPERTIES = "truetype:interpreter-version=35";
    # Java https://wiki.archlinux.org/title/Java_Runtime_Environment_fonts#Font_selection
    _JAVA_OPTIONS = "-Dawt.useSystemAAFontSettings=lcd";

    XDG_CACHE_HOME  = "\${HOME}/.cache";
    XDG_CONFIG_HOME = "\${HOME}/.config";
    XDG_BIN_HOME    = "\${HOME}/.local/bin";
    XDG_DATA_HOME   = "\${HOME}/.local/share";

    PATH = [ 
      "\${XDG_BIN_HOME}"
    ];
  };
  
  environment.loginShellInit = ''
    if [ -e $HOME/.bash_profile ];
    then
	. $HOME/.bash_profile
    fi
  '';

  # System Packages
  environment.systemPackages = with pkgs; [
    efibootmgr # EFI wiki https://nixos.wiki/wiki/Bootloader
    psmisc
    pciutils
    inetutils
    usbutils
    bridge-utils
    dnsmasq
    python310
    python310Packages.virtualenv
    wget
    sof-firmware
    alsa-firmware
    broadcom-bt-firmware
    git
    curl
    aria
    unzip
    unrar
    unar
    p7zip
    zip
    neofetch
    libsForQt5.ark # KDE
    libsForQt5.kcalc # KDE
    libsForQt5.kwrited # KDE
    libsForQt5.kate # KDE
    android-tools # adb and fastboot
    android-udev-rules # udev rules
    ntfs3g # support NTFS
    docker # Docker
    virt-manager # Virt Manager
    # GNS3
    vpcs
    dynamips
    ubridge
    gns3-server
    gns3-gui
    wireshark
  ];
  
  # Wireshark
  programs.wireshark.enable = true;

  # GNS3 Config
  security.wrappers = {
    ubridge = {
      source = "${pkgs.ubridge.out}/bin/ubridge";
      capabilities = "cap_net_admin,cap_net_raw=ep";
      owner = "root";
      group = "users";
      permissions = "u+rx,g+x";
    };
    dynamips = {
      source = "${pkgs.dynamips.out}/bin/dynamips";
      capabilities = "cap_net_admin,cap_net_raw=ep";
      owner = "root";
      group = "users";
      permissions = "u+rx,g+x";
    };
  };

  # Needed for store VS Code auth token 
  services.gnome.gnome-keyring.enable = true;
  
  # Font directory
  fonts.fontDir.enable = true;
  fonts.enableGhostscriptFonts = true;
  fonts.fonts = with pkgs; [
    corefonts  # Micrsoft free fonts
    inconsolata  # monospaced
    ubuntu_font_family  # Ubuntu fonts
    terminus_font # for hidpi screens, large fonts
    liberation_ttf #  Liberation
    iosevka # Iosevka
  ];
  # fonts.fontconfig.dpi = 192;

  # For Pro Audio /etc/security/limits.conf
  # Reference https://discourse.nixos.org/t/security-pam-loginlimits-is-set-but-etc-security-limits-conf-is-not-created/1776
  # Module https://github.com/NixOS/nixos/blob/master/modules/security/pam.nix
  security.pam.loginLimits = [
    { domain = "@audio"; item = "memlock"; type = "-";    value = "unlimited"; }
    { domain = "@audio"; item = "rtprio";  type = "-";    value = "99"; }
    { domain = "@audio"; item = "nofile";  type = "soft"; value = "99999"; }
    { domain = "@audio"; item = "nofile";  type = "hard"; value = "99999"; }
  ];

  # Bash completion
  programs.bash.enableCompletion = true;
  # Wiki android adb setup
  programs.adb.enable = true;
  # Wiki https://nixos.wiki/wiki/Java
  programs.java.enable = true;
  # programs.java.package = pkgs.jdk11;
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.dconf.enable = true;

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # Wiki https://nixos.wiki/wiki/Firewall
  # networking.firewall.allowedTCPPorts = [ 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = true;
  # networking.firewall.interfaces."eth0".allowedTCPPorts = [ 80 443 ];
  networking.firewall.interfaces."wlp3s0".allowedTCPPorts = [];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

}

