# Home Manager configuration for matt
{ config, pkgs, inputs, lib, ... }:

let
  # Fixed wrapper for Jellyfin Media Player (Forces XWayland and Fusion style to avoid crashes)
  jellyfin-wrapped = pkgs.writeShellScriptBin "jellyfinmediaplayer" ''
    export QT_QPA_PLATFORM=xcb
    export QT_STYLE_OVERRIDE=Fusion
    unset QT_QPA_PLATFORMTHEME
    exec ${pkgs.jellyfin-media-player}/bin/jellyfin-desktop "$@"
  '';

in
{
  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # ===================
  # Hyprland Configuration
  # ===================
  wayland.windowManager.hyprland = {
    enable = true;
    # Disable systemd integration since we use UWSM
    systemd.enable = false;

    settings = {
      # Monitor configuration (1.5x scaling for HiDPI)
      monitor = [
        ",preferred,auto,1.5"
      ];

      # XWayland scaling fix
      xwayland = {
        force_zero_scaling = true;
      };

      # Startup applications
      exec-once = [
        "waybar"
        "swaync"
        "hypridle"
        "nm-applet"
        "blueman-applet"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
        "GDK_SCALE,1.5"
      ];

      # General settings
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        "col.active_border" = lib.mkForce "rgb(d79921) rgb(fe8019) 45deg";
        "col.inactive_border" = lib.mkForce "rgb(3c3836)";
        layout = "dwindle";
        allow_tearing = true;
      };

      # Render settings for lower latency
      render = {
        direct_scanout = true;
      };

      # Decorations
      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.85;
        blur = {
          enabled = true;
          size = 3; 
          passes = 3;
          new_optimizations = true;
          xray = false;
          ignore_opacity = true;
        };
        shadow = {
          enabled = true;
          range = 12;
          render_power = 3;
          color = lib.mkForce "rgba(1d202188)";
        };
      };

      # Animations - fast and subtle
      animations = {
        enabled = true;
        bezier = [
          "easeOutQuint, 0.23, 1, 0.32, 1"
          "easeOutExpo, 0.16, 1, 0.3, 1"
          "linear, 0, 0, 1, 1"
        ];
        animation = [
          "windows, 1, 4, easeOutQuint, popin 90%"
          "windowsOut, 1, 3, easeOutExpo, popin 90%"
          "windowsMove, 1, 3, easeOutQuint"
          "border, 1, 4, easeOutQuint"
          "borderangle, 1, 30, linear, loop"
          "fade, 1, 3, easeOutQuint"
          "workspaces, 1, 4, easeOutQuint, slide"
          "specialWorkspace, 1, 4, easeOutQuint, slidefadevert"
        ];
      };

      # Layout settings
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      master = {
        new_status = "master";
      };

      # Input settings
      input = {
        kb_layout = "us";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          natural_scroll = true;
        };
      };

      # Misc
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Nvidia specific
      cursor = {
        no_hardware_cursors = true;
      };

      # Keybindings
      "$mainMod" = "SUPER";

      bind = [
        # Core
        "$mainMod, Return, exec, ghostty"
        "$mainMod SHIFT, Return, exec, ghostty -e nu"
        "$mainMod, Q, killactive,"
        "$mainMod SHIFT, E, exit,"
        "$mainMod, E, exec, ghostty -e yazi"
        "$mainMod SHIFT, E, exec, nautilus"
        "$mainMod, V, togglefloating,"
        "$mainMod, Space, exec, fuzzel"
        "$mainMod, P, pseudo,"
        "$mainMod, T, togglesplit,"
        "$mainMod, F, fullscreen,"
        "$mainMod, C, exec, zen"

        # Lock screen (use SUPER+Escape to avoid conflict with vim navigation)
        "$mainMod, Escape, exec, hyprlock"



        # Notification center
        "$mainMod, N, exec, swaync-client -t -sw"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "SHIFT, Print, exec, grim - | swappy -f -"

        # Clipboard history
        "$mainMod SHIFT, V, exec, cliphist list | fuzzel -d | cliphist decode | wl-copy"

        # Color picker (copies hex to clipboard)
        "$mainMod SHIFT, C, exec, hyprpicker -a"

        # Move focus with vim keys
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"

        # Move focus with arrow keys
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"

        # Move windows with vim keys
        "$mainMod SHIFT, H, movewindow, l"
        "$mainMod SHIFT, L, movewindow, r"
        "$mainMod SHIFT, K, movewindow, u"
        "$mainMod SHIFT, J, movewindow, d"

        # Workspaces
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move to workspace
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # Resize mode
        "$mainMod, R, submap, resize"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Media keys - using swayosd for visual feedback
      bindel = [
        ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume raise"
        ", XF86AudioLowerVolume, exec, swayosd-client --output-volume lower"
        ", XF86MonBrightnessUp, exec, swayosd-client --brightness raise"
        ", XF86MonBrightnessDown, exec, swayosd-client --brightness lower"
      ];

      # Window rules
      windowrulev2 = [
        "suppressevent maximize, class:.*"
        "float, class:^(pavucontrol)$"
        "float, class:^(pwvucontrol)$"
        "float, class:^(blueman-manager)$"
        "float, class:^(nm-connection-editor)$"
        "float, title:^(Picture-in-Picture)$"
        "pin, title:^(Picture-in-Picture)$"
        # Steam rules
        "float, class:^(steam)$,title:^(Friends List)$"
        "float, class:^(steam)$,title:^(Steam Settings)$"
        # Game rules - allow tearing for better latency
        "immediate, class:^(cs2)$"
        "immediate, class:^(steam_app_.*)$"
      ];

      # Layer rules for blur
      layerrule = [
        "blur, waybar"
        "blur, fuzzel"
        "blur, launcher"
        "blur, gtk-layer-shell"
        "blur, logout_dialog"
        "blur, swaync-control-center"
        "blur, swaync-notification-window"
        # ignorealpha is critical - blur only pixels above 50% opacity
        "ignorealpha 0.5, waybar"
        "ignorealpha 0.5, fuzzel"
        "ignorealpha 0.5, launcher"
        "ignorealpha 0.5, gtk-layer-shell"
        "ignorealpha 0.5, logout_dialog"
        "ignorealpha 0.5, swaync-control-center"
        "ignorealpha 0.5, swaync-notification-window"
      ];
    };
  };

  # ===================
  # Hyprlock Configuration
  # ===================
  stylix.targets.hyprlock.enable = false;
  stylix.targets.fuzzel.enable = false;

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        grace = 3;
        disable_loading_bar = true;
      };

      background = [
        {
          monitor = "";
          path = "screenshot";
          blur_passes = 3;
          blur_size = 6;
          noise = 0.02;
          brightness = 0.7;
        }
      ];

      label = [
        # Time
        {
          monitor = "";
          text = "$TIME";
          font_size = 120;
          font_family = "JetBrains Mono";
          color = "rgb(ebdbb2)"; # Gruvbox fg
          position = "0, 200";
          halign = "center";
          valign = "center";
          shadow_passes = 2;
          shadow_size = 3;
        }
        # Date
        {
          monitor = "";
          text = ''cmd[update:3600000] date +"%A, %B %d"'';
          font_size = 24;
          font_family = "JetBrains Mono";
          color = "rgb(a89984)"; # Gruvbox gray
          position = "0, 80";
          halign = "center";
          valign = "center";
          shadow_passes = 1;
        }
        # Greeting
        {
          monitor = "";
          text = "Hi, $USER";
          font_size = 18;
          font_family = "JetBrains Mono";
          color = "rgb(83a598)"; # Gruvbox blue
          position = "0, -80";
          halign = "center";
          valign = "center";
          shadow_passes = 1;
        }
      ];

      input-field = [
        {
          monitor = "";
          size = "300, 50";
          position = "0, -150";
          halign = "center";
          valign = "center";
          placeholder_text = "";
          hide_input = false;
          fade_on_empty = false;
          outline_thickness = 2;
          dots_size = 0.25;
          dots_spacing = 0.3;
          dots_center = true;
          rounding = 10;
          outer_color = "rgb(458588)"; # Gruvbox blue
          inner_color = "rgb(282828)"; # Gruvbox bg
          font_color = "rgb(ebdbb2)"; # Gruvbox fg
          check_color = "rgb(b8bb26)"; # Gruvbox green
          fail_color = "rgb(fb4934)"; # Gruvbox red
          shadow_passes = 2;
        }
      ];
    };
  };

  # ===================
  # Hypridle Configuration
  # ===================
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 1500; # 25 min - dim before lock
          on-timeout = "brightnessctl -s set 30%";
          on-resume = "brightnessctl -r";
        }
        {
          timeout = 1800; # 30 min - lock
          on-timeout = "loginctl lock-session";
        }
        # NVIDIA workaround: DPMS off crashes hyprlock, so we skip it.
        # The monitor will use its own power saving mode.
        # Uncomment below if hyprlock gets fixed upstream:
        # {
        #   timeout = 3600; # 60 min - display off
        #   on-timeout = "hyprctl dispatch dpms off";
        #   on-resume = "hyprctl dispatch dpms on";
        # }
      ];
    };
  };

  # ===================
  # SwayOSD (on-screen display for volume/brightness)
  # ===================
  services.swayosd = {
    enable = true;
    topMargin = 0.9;  # Show near bottom of screen
  };

  # ===================
  # SwayNC Notifications (feature-rich notification center)
  # ===================
  services.swaync = {
    enable = true;
    settings = {
      positionX = "right";
      positionY = "top";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      notification-icon-size = 64;
      notification-body-image-height = 100;
      notification-body-image-width = 200;
      timeout = 5;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = true;
      control-center-width = 400;
      notification-window-width = 400;
      keyboard-shortcuts = true;
      image-visibility = "when-available";
      transition-time = 200;
      hide-on-clear = false;
      hide-on-action = true;
      script-fail-notify = true;
    };
    style = ''
      * {
        font-family: "JetBrains Mono";
        font-size: 13px;
      }

      .notification-row {
        outline: none;
      }

      .notification {
        background-color: #282828;
        border: 1px solid #3c3836;
        border-radius: 10px;
        margin: 6px;
      }

      .notification-content {
        padding: 10px;
      }

      .summary {
        color: #ebdbb2;
        font-weight: bold;
      }

      .body {
        color: #d5c4a1;
      }

      .control-center {
        background-color: #282828;
        border: 1px solid #d79921;
        border-radius: 10px;
      }

      .control-center-list {
        background: transparent;
      }

      .widget-title {
        color: #ebdbb2;
        font-weight: bold;
      }

      .widget-title > button {
        background: #3c3836;
        border-radius: 6px;
        color: #ebdbb2;
        padding: 4px 10px;
      }

      .widget-title > button:hover {
        background: #504945;
      }

      .widget-dnd > switch {
        background: #3c3836;
        border-radius: 6px;
      }

      .widget-dnd > switch:checked {
        background: #d79921;
      }

      .notification-action {
        background: #3c3836;
        border-radius: 6px;
        color: #ebdbb2;
        margin: 4px;
        padding: 6px;
      }

      .notification-action:hover {
        background: #504945;
      }

      .close-button {
        background: #fb4934;
        border-radius: 6px;
        color: #282828;
        margin: 4px;
        padding: 2px 6px;
      }
    '';
  };

  # ===================
  # Waybar (theming handled by Stylix, keeping minimal custom styles)
  # ===================
  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 38;
        spacing = 4;

        modules-left = [ "hyprland/workspaces" "hyprland/window" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "custom/notification" "pulseaudio" "custom/sep" "cpu" "memory" "custom/gpu" ];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          sort-by-number = true;
        };

        "hyprland/window" = {
          max-length = 50;
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        cpu = {
          format = "CPU {usage}%";
          tooltip = true;
        };

        memory = {
          format = "RAM {}%";
        };

        "custom/gpu" = {
          exec = "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits";
          format = "GPU {}%";
          interval = 5;
          tooltip = false;
        };

        network = {
          format-wifi = " {signalStrength}%";
          format-ethernet = "󰈀";
          format-disconnected = "󰖪 Disconnected";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "󰝟 muted";
          format-icons = {
            default = [ "󰕿" "󰖀" "󰕾" ];
          };
          on-click = "pwvucontrol";
          on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
          on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
          tooltip = false;
        };

        "custom/sep" = {
          format = "|";
          tooltip = false;
        };

        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "󰂚";
            none = "󰂜";
            dnd-notification = "󰂛";
            dnd-none = "󰪑";
          };
          return-type = "json";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };

        tray = {
          spacing = 10;
        };
      };
    };
    style = ''
      * {
        font-family: "JetBrains Mono";
        font-size: 13px;
      }

      window#waybar {
        background-color: #282828;
        color: #ebdbb2;
      }

      #workspaces button {
        color: #a89984;
        padding: 0 6px;
      }

      #workspaces button.active {
        color: #ebdbb2;
      }

      #workspaces button:hover {
        background-color: #3c3836;
      }

      /* Right-side modules spacing */
      #tray,
      #custom-notification,
      #pulseaudio,
      #custom-gpu,
      #cpu,
      #memory {
        padding: 0 5px;
      }

      /* Fixed width for percentage modules */
      #cpu,
      #memory,
      #custom-gpu {
        min-width: 65px;
      }

      #pulseaudio {
        min-width: 55px;
      }

      /* Separator */
      #custom-sep {
        color: #504945;
        padding: 0 2px;
      }
    '';
  };

  # ===================
  # Fuzzel Launcher (Stylix disabled - manual theming)
  # ===================
  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        terminal = "ghostty -e";
        prompt = "❯ ";
        width = 50;
        lines = 15;
        horizontal-pad = 20;
        vertical-pad = 10;
        dpi-aware = "auto";
        icons-enabled = true;
        layer = "overlay";
      };
      border = {
        width = 2;
        radius = 10;
      };
      colors = {
        # Gruvbox with more transparency for visible blur (aa = 67% opacity)
        background = "282828aa";
        text = "ebdbb2ff";
        match = "fabd2fff";
        selection = "3c3836dd";
        selection-text = "ebdbb2ff";
        selection-match = "fe8019ff";
        border = "d79921ff";
      };
    };
  };

  # ===================
  # Terminal: Ghostty (theming/fonts handled by Stylix)
  # ===================
  programs.ghostty = {
    enable = true;
    settings = {
      command = "nu"; # Launch nushell directly
      background-opacity = 0.95;
      window-padding-x = 10;
      window-padding-y = 10;
      cursor-style = "block";
      cursor-style-blink = false;
      copy-on-select = true;
      confirm-close-surface = false;
    };
  };

  # ===================
  # File Manager: Yazi (modern, fast terminal file manager)
  # ===================
  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      manager = {
        show_hidden = false;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };
      preview = {
        image_filter = "triangle";
        image_quality = 75;
        max_width = 600;
        max_height = 900;
      };
    };
  };

  # ===================
  # Shell: Nushell (modern, structured data shell)
  # ===================
  programs.nushell = {
    enable = true;

    # Extra config appended to config.nu
    extraConfig = ''
      # Disable banner
      $env.config.show_banner = false

      # Editor
      $env.config.buffer_editor = "hx"

      # History settings
      $env.config.history = {
        max_size: 10000
        sync_on_enter: true
        file_format: "sqlite"
      }

      # Completions
      $env.config.completions = {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
      }

      # Table display
      $env.config.table = {
        mode: rounded
        index_mode: auto
        show_empty: true
        padding: { left: 1, right: 1 }
        trim: {
          methodology: wrapping
          wrapping_try_keep_words: true
        }
        header_on_separator: false
      }

      # Aliases (Nushell native)
      alias ll = ls -l
      alias la = ls -la
      alias lt = eza --tree --icons
      alias cat = bat
      alias vim = hx
      alias vi = hx

      # NixOS shortcuts
      alias nrs = sudo nixos-rebuild switch --flake ~/.config/nix-config#matt-desktop
      alias nrt = sudo nixos-rebuild test --flake ~/.config/nix-config#matt-desktop

      # Git shortcuts
      alias gs = git status
      alias gd = git diff
      alias ga = git add
      alias gc = git commit
      alias gp = git push
      alias gl = git pull
      alias lg = lazygit
    '';

    # Environment variables (env.nu)
    extraEnv = ''
      # PATH additions if needed
      $env.EDITOR = "hx"
      $env.VISUAL = "hx"
    '';

    # Shell aliases (also available via alias command above, but this integrates with HM)
    shellAliases = {
      ls = "eza --icons";
      grep = "rg";
      find = "fd";
    };
  };

  # Carapace - multi-shell completion generator (works great with Nushell)
  programs.carapace = {
    enable = true;
    enableNushellIntegration = true;
  };

  # ===================
  # Starship Prompt
  # ===================
  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = lib.concatStrings [
        "$directory"
        "$git_branch"
        "$git_status"
        "$nix_shell"
        "$character"
      ];
      directory = {
        style = "blue bold";
        truncation_length = 3;
        truncate_to_repo = true;
      };
      git_branch = {
        style = "purple";
        format = "[$branch]($style) ";
      };
      git_status = {
        style = "red";
      };
      nix_shell = {
        format = "[$symbol$state]($style) ";
        symbol = "❄️ ";
      };
      character = {
        success_symbol = "[❯](green)";
        error_symbol = "[❯](red)";
      };
    };
  };

  # ===================
  # Editor: Helix (theming handled by Stylix)
  # ===================
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      editor = {
        line-number = "relative";
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
        lsp.display-messages = true;
        file-picker.hidden = false;
        statusline = {
          left = [ "mode" "spinner" "file-name" ];
          right = [ "diagnostics" "selections" "position" "file-encoding" ];
        };
        indent-guides = {
          render = true;
          character = "│";
        };
        soft-wrap.enable = true;
      };
    };
  };

  # ===================
  # Git
  # ===================
  programs.git = {
    enable = true;
    settings = {
      user.name = "Matt Cernohorsky";
      user.email = "matt@cernohorsky.ca";
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "hx";
      merge.conflictstyle = "diff3";
      diff.colorMoved = "default";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      };
    };

  # ===================
  # Modern CLI Tools (theming handled by Stylix)
  # ===================
  programs.bat.enable = true;

  programs.eza.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    enableNushellIntegration = true;
    nix-direnv.enable = true;
  };

  # Btop system monitor (theming handled by Stylix)
  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      vim_keys = true;
    };
  };

  # ===================
  # Additional Packages
  # ===================
  home.packages = with pkgs; [
    # Browser
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Development
    nushell
    lazygit
    gh
    jq
    yq

    # System info
    fastfetch
    cpufetch

    # Media
    playerctl
    imv

    # GUI file manager (backup)
    nautilus

    # Archive tools
    unrar

    # Fonts (user-level)
    cascadia-code
  ];

  # ===================
  # XDG
  # ===================
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "zen.desktop";
        "x-scheme-handler/http" = "zen.desktop";
        "x-scheme-handler/https" = "zen.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };
    desktopEntries = {
      "org.jellyfin.JellyfinDesktop" = {
        name = "Jellyfin Media Player";
        exec = "${jellyfin-wrapped}/bin/jellyfinmediaplayer";
        icon = "org.jellyfin.JellyfinDesktop";
        comment = "Jellyfin Desktop Client (Fixed)";
        terminal = false;
        categories = [ "Video" "AudioVideo" "Player" ];
      };
      jellyfin-server = {
        name = "Jellyfin Server Dashboard";
        exec = "xdg-open http://localhost:8096";
        icon = "org.jellyfin.JellyfinDesktop";
        comment = "Jellyfin Server Administration";
        terminal = false;
        categories = [ "Network" "Settings" ];
      };
    };
  };
}
