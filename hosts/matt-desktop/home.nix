# Home Manager configuration for matt
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  # Fixed wrapper for Jellyfin Media Player (Forces XWayland and Fusion style to avoid crashes)
  jellyfin-wrapped = pkgs.writeShellScriptBin "jellyfinmediaplayer" ''
    export QT_QPA_PLATFORM=xcb
    export QT_STYLE_OVERRIDE=Fusion
    unset QT_QPA_PLATFORMTHEME
    exec ${pkgs.jellyfin-media-player}/bin/jellyfin-desktop "$@"
  '';

  lock-now = pkgs.writeShellApplication {
    name = "lock-now";
    runtimeInputs = [
      pkgs.systemd
      pkgs.procps
      pkgs.hyprlock
    ];
    text = ''
      set -euo pipefail

      if [ -n "''${XDG_SESSION_ID-}" ] &&
        [ "$(loginctl show-session "$XDG_SESSION_ID" -p LockedHint --value 2>/dev/null || true)" = "yes" ]; then
        exit 0
      fi

      if pgrep -xu "$USER" -x hyprlock >/dev/null 2>&1; then
        exit 0
      fi

      exec ${pkgs.hyprlock}/bin/hyprlock
    '';
  };

in
{
  imports = [
    ../../modules/home/opencode-core.nix
  ];

  modules.home.opencodeCore.enable = true;

  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # ===================
  # Hyprland Configuration
  # ===================
  wayland.windowManager.hyprland = {
    enable = false;
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
      # Note: idle is managed via systemd user service (services.swayidle.enable)
      exec-once = [
        # UWSM is not activating graphical-session.target here, so start the
        # expected user services explicitly once the Wayland session is ready.
        "systemctl --user start hyprpaper.service swayidle.service swayosd.service swaync.service elephant.service walker.service"
        "waybar"
        "nm-applet"
        "blueman-applet"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
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

      # Decorations
      decoration = {
        rounding = 10;
        active_opacity = 1.0;
        inactive_opacity = 0.85;
        blur = {
          enabled = true;
          size = 3;
          passes = 3;
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
        kb_options = "caps:escape";
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
        "$mainMod, Q, killactive,"
        "$mainMod SHIFT, E, exit,"
        "$mainMod, E, exec, ghostty -e yazi"
        "$mainMod SHIFT, E, exec, nautilus"
        "$mainMod, V, togglefloating,"
        "$mainMod, Space, exec, walker"
        "$mainMod, P, pseudo,"
        "$mainMod, T, layoutmsg, togglesplit"
        "$mainMod, F, fullscreen,"
        "$mainMod, C, exec, helium"

        # Lock screen (use SUPER+Escape to avoid conflict with vim navigation)
        "$mainMod, Escape, exec, ${lib.getExe lock-now}"

        # Notification center
        "$mainMod, N, exec, swaync-client -t -sw"

        # Screenshots
        ", Print, exec, grim -g \"$(slurp)\" - | swappy -f -"
        "SHIFT, Print, exec, grim - | swappy -f -"

        # Clipboard history (walker has built-in clipboard module)
        "$mainMod SHIFT, V, exec, walker -m clipboard"

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
      ];

      # Window rules (Hyprland 0.53+ syntax)
      windowrule = [
        "suppress_event maximize, match:class .*"
        "float 1, match:class ^(pavucontrol)$"
        "float 1, match:class ^(pwvucontrol)$"
        "float 1, match:class ^(blueman-manager)$"
        "float 1, match:class ^(nm-connection-editor)$"
        "float 1, match:title ^(Picture-in-Picture)$"
        "pin 1, match:title ^(Picture-in-Picture)$"
        # Steam rules
        "float 1, match:class ^(steam)$, match:title ^(Friends List)$"
        "float 1, match:class ^(steam)$, match:title ^(Steam Settings)$"
        # Game rules - allow tearing for better latency
        "immediate 1, match:class ^(cs2)$"
        "immediate 1, match:class ^(steam_app_.*)$"
      ];

      # Layer rules for blur (Hyprland 0.53+ syntax)
      layerrule = [
        "blur 1, match:namespace ^(waybar)$"
        "blur 1, match:namespace ^(walker)$"
        "blur 1, match:namespace ^(launcher)$"
        "blur 1, match:namespace ^(gtk-layer-shell)$"
        "blur 1, match:namespace ^(logout_dialog)$"
        "blur 1, match:namespace ^(swaync-control-center)$"
        "blur 1, match:namespace ^(swaync-notification-window)$"
        # ignore_alpha is critical - blur only pixels above 50% opacity
        "ignore_alpha 0.5, match:namespace ^(waybar)$"
        "ignore_alpha 0.5, match:namespace ^(walker)$"
        "ignore_alpha 0.5, match:namespace ^(launcher)$"
        "ignore_alpha 0.5, match:namespace ^(gtk-layer-shell)$"
        "ignore_alpha 0.5, match:namespace ^(logout_dialog)$"
        "ignore_alpha 0.5, match:namespace ^(swaync-control-center)$"
        "ignore_alpha 0.5, match:namespace ^(swaync-notification-window)$"
        # Walker prefers no animation to avoid flicker during layout changes
        "no_anim 1, match:namespace ^(walker)$"
      ];
    };
  };

  programs.niri.settings = {
    prefer-no-csd = true;

    input = {
      mod-key = "Super";
      keyboard.xkb = {
        layout = "us";
        options = "caps:escape";
      };
      touchpad.natural-scroll = true;
    };

    layout = {
      focus-ring = {
        width = 2;
        inactive.color = "transparent";
      };
    };

    spawn-at-startup = [
      {
        command = [
          "systemctl"
          "--user"
          "start"
          "swayosd.service"
          "swaync.service"
          "elephant.service"
          "walker.service"
        ];
      }
      { command = [ "waybar" ]; }
      { command = [ "nm-applet" ]; }
      { command = [ "blueman-applet" ]; }
      {
        command = [
          "sh"
          "-c"
          "wl-paste --type text --watch cliphist store"
        ];
      }
      {
        command = [
          "sh"
          "-c"
          "wl-paste --type image --watch cliphist store"
        ];
      }
    ];

    binds = {
      "Mod+Shift+Slash".action.show-hotkey-overlay = [ ];
      "Mod+T".action.spawn = "ghostty";
      "Mod+Space".action.spawn = "walker";
      "Mod+B".action.spawn = "helium";
      "Super+Alt+L" = {
        allow-inhibiting = false;
        allow-when-locked = false;
        repeat = false;
        hotkey-overlay.title = "Lock the Screen";
        action.spawn = [ (lib.getExe lock-now) ];
      };

      "XF86AudioRaiseVolume".allow-when-locked = true;
      "XF86AudioRaiseVolume".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "raise"
      ];
      "XF86AudioLowerVolume".allow-when-locked = true;
      "XF86AudioLowerVolume".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "lower"
      ];
      "XF86AudioMute".allow-when-locked = true;
      "XF86AudioMute".action.spawn = [
        "swayosd-client"
        "--output-volume"
        "mute-toggle"
      ];
      "XF86AudioMicMute".allow-when-locked = true;
      "XF86AudioMicMute".action.spawn = [
        "swayosd-client"
        "--input-volume"
        "mute-toggle"
      ];
      "XF86AudioPlay".allow-when-locked = true;
      "XF86AudioPlay".action.spawn = [
        "swayosd-client"
        "--playerctl"
        "play-pause"
      ];
      "XF86AudioStop".allow-when-locked = true;
      "XF86AudioStop".action.spawn = [
        "swayosd-client"
        "--playerctl"
        "stop"
      ];
      "XF86AudioPrev".allow-when-locked = true;
      "XF86AudioPrev".action.spawn = [
        "swayosd-client"
        "--playerctl"
        "prev"
      ];
      "XF86AudioNext".allow-when-locked = true;
      "XF86AudioNext".action.spawn = [
        "swayosd-client"
        "--playerctl"
        "next"
      ];
      "XF86MonBrightnessUp".allow-when-locked = true;
      "XF86MonBrightnessUp".action.spawn = [
        "swayosd-client"
        "--brightness"
        "raise"
      ];
      "XF86MonBrightnessDown".allow-when-locked = true;
      "XF86MonBrightnessDown".action.spawn = [
        "swayosd-client"
        "--brightness"
        "lower"
      ];

      "Mod+O".action.toggle-overview = [ ];
      "Mod+Q".action.close-window = [ ];

      "Mod+Left".action.focus-column-left = [ ];
      "Mod+Down".action.focus-window-down = [ ];
      "Mod+Up".action.focus-window-up = [ ];
      "Mod+Right".action.focus-column-right = [ ];
      "Mod+H".action.focus-column-left = [ ];
      "Mod+J".action.focus-window-down = [ ];
      "Mod+K".action.focus-window-up = [ ];
      "Mod+L".action.focus-column-right = [ ];

      "Mod+Ctrl+Left".action.move-column-left = [ ];
      "Mod+Ctrl+Down".action.move-window-down = [ ];
      "Mod+Ctrl+Up".action.move-window-up = [ ];
      "Mod+Ctrl+Right".action.move-column-right = [ ];
      "Mod+Ctrl+H".action.move-column-left = [ ];
      "Mod+Ctrl+J".action.move-window-down = [ ];
      "Mod+Ctrl+K".action.move-window-up = [ ];
      "Mod+Ctrl+L".action.move-column-right = [ ];

      "Mod+Home".action.focus-column-first = [ ];
      "Mod+End".action.focus-column-last = [ ];
      "Mod+Ctrl+Home".action.move-column-to-first = [ ];
      "Mod+Ctrl+End".action.move-column-to-last = [ ];

      "Mod+Shift+Left".action.focus-monitor-left = [ ];
      "Mod+Shift+Down".action.focus-monitor-down = [ ];
      "Mod+Shift+Up".action.focus-monitor-up = [ ];
      "Mod+Shift+Right".action.focus-monitor-right = [ ];
      "Mod+Shift+H".action.focus-monitor-left = [ ];
      "Mod+Shift+J".action.focus-monitor-down = [ ];
      "Mod+Shift+K".action.focus-monitor-up = [ ];
      "Mod+Shift+L".action.focus-monitor-right = [ ];

      "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [ ];
      "Mod+Shift+Ctrl+Down".action.move-column-to-monitor-down = [ ];
      "Mod+Shift+Ctrl+Up".action.move-column-to-monitor-up = [ ];
      "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [ ];
      "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [ ];
      "Mod+Shift+Ctrl+J".action.move-column-to-monitor-down = [ ];
      "Mod+Shift+Ctrl+K".action.move-column-to-monitor-up = [ ];
      "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [ ];

      "Mod+Page_Down".action.focus-workspace-down = [ ];
      "Mod+Page_Up".action.focus-workspace-up = [ ];
      "Mod+U".action.focus-workspace-down = [ ];
      "Mod+I".action.focus-workspace-up = [ ];
      "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [ ];
      "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [ ];
      "Mod+Ctrl+U".action.move-column-to-workspace-down = [ ];
      "Mod+Ctrl+I".action.move-column-to-workspace-up = [ ];
      "Mod+Shift+Page_Down".action.move-workspace-down = [ ];
      "Mod+Shift+Page_Up".action.move-workspace-up = [ ];
      "Mod+Shift+U".action.move-workspace-down = [ ];
      "Mod+Shift+I".action.move-workspace-up = [ ];

      "Mod+N".action.spawn-sh = "swaync-client -t -sw";
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;
      "Mod+Ctrl+1".action.move-column-to-workspace = 1;
      "Mod+Ctrl+2".action.move-column-to-workspace = 2;
      "Mod+Ctrl+3".action.move-column-to-workspace = 3;
      "Mod+Ctrl+4".action.move-column-to-workspace = 4;
      "Mod+Ctrl+5".action.move-column-to-workspace = 5;
      "Mod+Ctrl+6".action.move-column-to-workspace = 6;
      "Mod+Ctrl+7".action.move-column-to-workspace = 7;
      "Mod+Ctrl+8".action.move-column-to-workspace = 8;
      "Mod+Ctrl+9".action.move-column-to-workspace = 9;

      "Mod+BracketLeft".action.consume-or-expel-window-left = [ ];
      "Mod+BracketRight".action.consume-or-expel-window-right = [ ];
      "Mod+Comma".action.consume-window-into-column = [ ];
      "Mod+Period".action.expel-window-from-column = [ ];

      "Mod+R".action.switch-preset-column-width = [ ];
      "Mod+Shift+R".action.switch-preset-window-height = [ ];
      "Mod+Ctrl+R".action.reset-window-height = [ ];
      "Mod+F".action.maximize-column = [ ];
      "Mod+Shift+F".action.fullscreen-window = [ ];
      "Mod+Ctrl+F".action.expand-column-to-available-width = [ ];
      "Mod+C".action.center-column = [ ];
      "Mod+Ctrl+C".action.center-visible-columns = [ ];
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";
      "Mod+V".action.toggle-window-floating = [ ];
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = [ ];
      "Mod+W".action.toggle-column-tabbed-display = [ ];

      "Print".action.screenshot = [ ];
      "Ctrl+Print".action.screenshot-screen = [ ];
      "Alt+Print".action.screenshot-window = [ ];
      "Mod+S".action.screenshot = [ ];

      "Mod+Escape".allow-inhibiting = false;
      "Mod+Escape".action.toggle-keyboard-shortcuts-inhibit = [ ];
      "Mod+Shift+E".action.quit = [ ];
      "Ctrl+Alt+Delete".action.quit = [ ];
      "Mod+Shift+P".action.power-off-monitors = [ ];
    };

    window-rules = [
      {
        clip-to-geometry = true;
        draw-border-with-background = false;
        geometry-corner-radius = {
          top-left = 12.0;
          top-right = 12.0;
          bottom-right = 12.0;
          bottom-left = 12.0;
        };
      }
      {
        matches = [
          { app-id = "pavucontrol"; }
          { app-id = "pwvucontrol"; }
          { app-id = "blueman-manager"; }
          { app-id = "nm-connection-editor"; }
        ];
        open-floating = true;
      }
      {
        matches = [ { title = "^Picture-in-Picture$"; } ];
        open-floating = true;
      }
    ];
  };

  services.hyprpaper.enable = lib.mkForce false;

  # ===================
  # Hyprlock Configuration
  # ===================
  stylix.targets.hyprlock.enable = false;

  programs.swaylock = {
    enable = true;
    settings = lib.mkForce {
      # Solid black background with minimal indicator
      color = "000000";
      scaling = "solid_color";
      show-failed-attempts = true;

      # Minimal indicator
      indicator = true;
      indicator-radius = 50;
      indicator-thickness = 4;

      # Transparent separators
      line-color = "00000000";
      separator-color = "00000000";

      # Subtle gray ring
      ring-color = "666666";
      ring-clear-color = "888888";
      ring-caps-lock-color = "aaaaaa";
      ring-ver-color = "888888";
      ring-wrong-color = "cc6666";

      # Translucent dark inside
      inside-color = "1a1a1a88";
      inside-clear-color = "1a1a1a88";
      inside-caps-lock-color = "2a2a2a88";
      inside-ver-color = "1a1a1a88";
      inside-wrong-color = "2a1a1a88";

      # Neutral text
      text-color = "cccccc";
      text-clear-color = "aaaaaa";
      text-caps-lock-color = "cccccc";
      text-ver-color = "aaaaaa";
      text-wrong-color = "cc6666";

      # Key highlights
      key-hl-color = "888888";
      bs-hl-color = "cc6666";
      caps-lock-key-hl-color = "aaaaaa";
      caps-lock-bs-hl-color = "cc6666";
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        hide_cursor = true;
        # Note: grace and disable_loading_bar removed in hyprlock v0.9.x
        # grace is now a CLI flag (--grace), set in keybinds and swayidle commands
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
          shadow_size = 6;
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
          text = "$USER";
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
  # Idle Management (evdev-based workaround for Smithay idle bug)
  # ===================
  # WORKAROUND: Smithay/niri's ext_idle_notifier_v1 implementation has a bug where
  # 'resumed' events are not reliably sent after 'idled' events (Smithay #1892, Niri #3136).
  # This breaks standard Wayland idle daemons like swayidle. Until upstream fixes this,
  # we use a custom evdev-based idle tracker that reads input events directly from
  # /dev/input/event* devices, bypassing the broken Wayland idle protocol entirely.
  #
  # Once niri/Smithay fixes the idle-notify protocol, this can be replaced with:
  #   services.swayidle = { enable = true; timeouts = [ ... ]; };
  #
  # Behavior:
  #   - 30 min idle: lock session (hyprlock)
  #   - 60 min idle: power off monitor (niri msg action power-off-monitors)
  #   - On input after 60 min: power on monitor, return to lock screen
  #
  # NOTE: The evdev-idle-daemon is defined in configuration.nix as a system service
  # for proper input device permissions. This home.nix config just disables swayidle
  # to avoid conflicts.
  services.swayidle.enable = lib.mkForce false;

  # ===================
  # SwayOSD (on-screen display for volume/brightness)
  # ===================
  services.swayosd = {
    enable = true;
    topMargin = 0.9; # Show near bottom of screen
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
      widgets = [
        "title"
        "dnd"
        "notifications"
      ];
      widget-config = {
        title = { };
        dnd = { };
        notifications = { };
      };
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
        spacing = 0;

        modules-left = [
          "niri/workspaces"
          "niri/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "tray"
          "custom/notification"
          "pulseaudio"
          "custom/sep"
          "cpu"
          "memory"
          "custom/gpu"
        ];

        "niri/workspaces" = {
          format = "{index}";
          on-click = "activate";
          sort-by-number = true;
        };

        "niri/window" = {
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
          format = "<span font='16px'>{icon}</span> {volume}%";
          format-muted = "<span font='16px'>󰝟</span> muted";
          format-icons = {
            default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
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
          format = "<span font='16px'>{icon}</span>";
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
          spacing = 12;
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
        padding: 0 6px;
      }

      #custom-notification,
      #pulseaudio {
        font-family: "JetBrainsMono Nerd Font";
      }

      #custom-notification {
        padding: 0 3px;
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
  # Walker Launcher (Raycast-like launcher)
  # ===================
  programs.walker = {
    enable = true;
    runAsService = true;
    config = {
      theme = "gruvbox";
      force_keyboard_focus = true;
      selection_wrap = true;
      hide_action_hints = true;
      placeholders = {
        default = {
          input = " Search...";
          list = "No Results";
        };
        files = {
          input = " Search Files...";
          list = "                                                       No Results                                                       ";
        };
      };
      keybinds.quick_activate = [ ];
      columns.symbols = 1;
      # Anchor to top so it doesn't jump around as results change
      shell.anchor_top = true;
      providers = {
        max_results = 256;
        default = [ "desktopapplications" ];
        prefixes = [
          {
            prefix = "/";
            provider = "providerlist";
          }
          {
            prefix = ".";
            provider = "files";
          }
          {
            prefix = ":";
            provider = "symbols";
          }
          {
            prefix = "=";
            provider = "calc";
          }
          {
            prefix = "@";
            provider = "websearch";
          }
          {
            prefix = "$";
            provider = "clipboard";
          }
        ];
      };
    };
    themes.gruvbox = {
      style = ''
        /* Gruvbox color definitions */
        @define-color selected-text #fabd2f;
        @define-color text #ebdbb2;
        @define-color base #282828;
        @define-color border #d79921;
        @define-color foreground #ebdbb2;
        @define-color background #282828;

        * {
          all: unset;
        }

        * {
          font-family: "JetBrains Mono";
          font-size: 16px;
          color: @text;
        }

        scrollbar {
          opacity: 0;
        }

        .normal-icons {
          -gtk-icon-size: 16px;
        }

        .large-icons {
          -gtk-icon-size: 32px;
        }

        .box-wrapper {
          background: alpha(@base, 0.75);
          padding: 20px;
          border: 2px solid @border;
          border-radius: 10px;
        }

        .search-container {
          background: @base;
          padding: 10px;
        }

        .input placeholder {
          opacity: 0.5;
        }

        .input:focus,
        .input:active {
          box-shadow: none;
          outline: none;
        }

        child:selected .item-box * {
          color: @selected-text;
        }

        .item-box {
          padding-left: 14px;
        }

        .item-text-box {
          all: unset;
          padding: 14px 0;
        }

        .item-subtext {
          font-size: 0px;
          min-height: 0px;
          margin: 0px;
          padding: 0px;
        }

        .item-image {
          margin-right: 14px;
          -gtk-icon-transform: scale(0.9);
        }

        .current {
          font-style: italic;
        }

        .keybind-hints {
          background: @background;
          padding: 10px;
          margin-top: 10px;
        }

        .preview {
          padding: 20px;
          background: @background;
          border-radius: 0 10px 10px 0;
        }

        .preview image {
          -gtk-icon-size: 256px;
        }
      '';
      layouts = {
        # Calc items without icon (elephant calc doesn't provide one)
        item_calc = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <interface>
            <requires lib="gtk" version="4.0"></requires>
            <object class="GtkBox" id="ItemBox">
              <style>
                <class name="item-box"></class>
              </style>
              <property name="orientation">horizontal</property>
              <property name="spacing">10</property>
              <child>
                <object class="GtkBox" id="ItemTextBox">
                  <style>
                    <class name="item-text-box"></class>
                  </style>
                  <property name="orientation">vertical</property>
                  <property name="hexpand">true</property>
                  <property name="vexpand">true</property>
                  <property name="vexpand-set">true</property>
                  <property name="spacing">0</property>
                  <child>
                    <object class="GtkLabel" id="ItemText">
                      <style>
                        <class name="item-text"></class>
                      </style>
                      <property name="wrap">false</property>
                      <property name="ellipsize">end</property>
                      <property name="vexpand_set">true</property>
                      <property name="vexpand">true</property>
                      <property name="xalign">0</property>
                    </object>
                  </child>
                </object>
              </child>
            </object>
          </interface>
        '';
        item_files = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <interface>
            <requires lib="gtk" version="4.0"></requires>
            <object class="GtkBox" id="ItemBox">
              <style>
                <class name="item-box"></class>
              </style>
              <property name="orientation">horizontal</property>
              <property name="spacing">10</property>
              <child>
                <object class="GtkImage" id="ItemImage">
                  <style>
                    <class name="item-image"></class>
                  </style>
                </object>
              </child>
              <child>
                <object class="GtkBox" id="ItemTextBox">
                  <style>
                    <class name="item-text-box"></class>
                  </style>
                  <property name="orientation">vertical</property>
                  <property name="hexpand">true</property>
                  <property name="spacing">0</property>
                  <child>
                    <object class="GtkLabel" id="ItemText">
                      <style>
                        <class name="item-text"></class>
                      </style>
                      <property name="ellipsize">end</property>
                      <property name="xalign">0</property>
                    </object>
                  </child>
                  <child>
                    <object class="GtkLabel" id="ItemSubtext">
                      <style>
                        <class name="item-subtext"></class>
                      </style>
                      <property name="ellipsize">end</property>
                      <property name="xalign">0</property>
                    </object>
                  </child>
                </object>
              </child>
            </object>
          </interface>
        '';
        layout = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <interface>
            <requires lib="gtk" version="4.0"></requires>
            <object class="GtkWindow" id="Window">
              <style>
                <class name="window"></class>
              </style>
              <property name="resizable">true</property>
              <property name="title">Walker</property>
              <child>
                <object class="GtkBox" id="BoxWrapper">
                  <style>
                    <class name="box-wrapper"></class>
                  </style>
                  <property name="width-request">640</property>
                  <property name="overflow">hidden</property>
                  <property name="orientation">horizontal</property>
                  <property name="valign">center</property>
                  <property name="halign">center</property>
                  <child>
                    <object class="GtkBox" id="Box">
                      <style>
                        <class name="box"></class>
                      </style>
                      <property name="orientation">vertical</property>
                      <property name="hexpand-set">true</property>
                      <property name="hexpand">true</property>
                      <property name="spacing">10</property>
                      <child>
                        <object class="GtkBox" id="SearchContainer">
                          <style>
                            <class name="search-container"></class>
                          </style>
                          <property name="overflow">hidden</property>
                          <property name="orientation">horizontal</property>
                          <property name="halign">fill</property>
                          <property name="hexpand-set">true</property>
                          <property name="hexpand">true</property>
                          <child>
                            <object class="GtkEntry" id="Input">
                              <style>
                                <class name="input"></class>
                              </style>
                              <property name="halign">fill</property>
                              <property name="hexpand-set">true</property>
                              <property name="hexpand">true</property>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkBox" id="ContentContainer">
                          <style>
                            <class name="content-container"></class>
                          </style>
                          <property name="orientation">horizontal</property>
                          <property name="spacing">10</property>
                          <property name="vexpand">true</property>
                          <property name="vexpand-set">true</property>
                          <child>
                            <object class="GtkLabel" id="ElephantHint">
                              <style>
                                <class name="elephant-hint"></class>
                              </style>
                              <property name="hexpand">false</property>
                              <property name="width-request">600</property>
                              <property name="height-request">100</property>
                              <property name="label">Loading...</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkLabel" id="Placeholder">
                              <style>
                                <class name="placeholder"></class>
                              </style>
                              <property name="label">No Results</property>
                              <property name="halign">center</property>
                              <property name="xalign">0.5</property>
                              <property name="yalign">0.5</property>
                              <property name="hexpand">false</property>
                              <property name="width-request">600</property>
                              <property name="height-request">400</property>
                              <property name="wrap">false</property>
                              <property name="ellipsize">none</property>
                            </object>
                          </child>
                          <child>
                            <object class="GtkScrolledWindow" id="Scroll">
                              <style>
                                <class name="scroll"></class>
                              </style>
                              <property name="hexpand">true</property>
                              <property name="width-request">600</property>
                              <property name="can_focus">false</property>
                              <property name="overlay-scrolling">true</property>
                              <property name="max-content-width">600</property>
                              <property name="max-content-height">400</property>
                              <property name="min-content-height">400</property>
                              <property name="propagate-natural-height">true</property>
                              <property name="propagate-natural-width">false</property>
                              <property name="hscrollbar-policy">never</property>
                              <property name="vscrollbar-policy">automatic</property>
                              <child>
                                <object class="GtkGridView" id="List">
                                  <style>
                                    <class name="list"></class>
                                  </style>
                                  <property name="max_columns">1</property>
                                  <property name="can_focus">false</property>
                                </object>
                              </child>
                            </object>
                          </child>
                          <child>
                            <object class="GtkBox" id="Preview">
                              <style>
                                <class name="preview"></class>
                              </style>
                              <property name="halign">fill</property>
                              <property name="valign">fill</property>
                              <property name="hexpand">false</property>
                              <property name="vexpand">true</property>
                              <property name="width-request">460</property>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkBox" id="Keybinds">
                          <property name="hexpand">true</property>
                          <property name="margin-top">10</property>
                          <style>
                            <class name="keybinds"></class>
                          </style>
                          <child>
                            <object class="GtkBox" id="GlobalKeybinds">
                              <property name="spacing">10</property>
                              <style>
                                <class name="global-keybinds"></class>
                              </style>
                            </object>
                          </child>
                          <child>
                            <object class="GtkBox" id="ItemKeybinds">
                              <property name="hexpand">true</property>
                              <property name="halign">end</property>
                              <property name="spacing">10</property>
                              <style>
                                <class name="item-keybinds"></class>
                              </style>
                            </object>
                          </child>
                        </object>
                      </child>
                      <child>
                        <object class="GtkLabel" id="Error">
                          <style>
                            <class name="error"></class>
                          </style>
                          <property name="xalign">0</property>
                          <property name="visible">false</property>
                        </object>
                      </child>
                    </object>
                  </child>
                </object>
              </child>
            </object>
          </interface>
        '';
      };
    };
  };

  systemd.user.services.walker.Service.Environment = [
    "GDK_BACKEND=wayland"
    "GSK_RENDERER=ngl"
  ];

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
    shellWrapperName = "y";
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
          left = [
            "mode"
            "spinner"
            "file-name"
          ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
          ];
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
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Development
    lazygit
    gh
    jq
    yq
    opencode-desktop

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

    # Icons (for desktop entries)
    papirus-icon-theme
  ];

  # ===================
  # GTK Icon Theme
  # ===================
  gtk.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

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
        "text/html" = "helium.desktop";
        "x-scheme-handler/http" = "helium.desktop";
        "x-scheme-handler/https" = "helium.desktop";
        "image/png" = "imv.desktop";
        "image/jpeg" = "imv.desktop";
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };
    desktopEntries = {
      "Helix" = {
        name = "Helix";
        genericName = "Text Editor";
        comment = "A post-modern text editor";
        exec = "ghostty -e hx %F";
        icon = "helix";
        terminal = false;
        categories = [
          "Utility"
          "TextEditor"
          "Development"
          "IDE"
        ];
        mimeType = [
          "text/plain"
          "text/markdown"
          "application/x-shellscript"
        ];
      };
      "org.gnome.Nautilus" = {
        name = "Files";
        genericName = "File Manager";
        comment = "Access and organize files";
        exec = "nautilus --new-window %U";
        icon = "org.gnome.Nautilus";
        terminal = false;
        categories = [
          "GNOME"
          "GTK"
          "Utility"
          "Core"
          "FileManager"
        ];
        mimeType = [ "inode/directory" ];
      };
      "org.jellyfin.JellyfinDesktop" = {
        name = "Jellyfin Media Player";
        exec = "${jellyfin-wrapped}/bin/jellyfinmediaplayer";
        icon = "jellyfin";
        comment = "Jellyfin Desktop Client (Fixed)";
        terminal = false;
        categories = [
          "Video"
          "AudioVideo"
          "Player"
        ];
      };
      jellyfin-server = {
        name = "Jellyfin Server Dashboard";
        exec = "xdg-open http://localhost:8096";
        icon = "jellyfin";
        comment = "Jellyfin Server Administration";
        terminal = false;
        categories = [
          "Network"
          "Settings"
        ];
      };
      # Power actions (searchable in walker)
      lock-screen = {
        name = "Lock Screen";
        exec = lib.getExe lock-now;
        icon = "system-lock-screen";
        comment = "Lock the screen";
        terminal = false;
        categories = [ "System" ];
      };
      logout = {
        name = "Logout";
        exec = "niri msg action quit";
        icon = "system-log-out";
        comment = "End session and logout";
        terminal = false;
        categories = [ "System" ];
      };
      reboot = {
        name = "Reboot";
        exec = "pkexec systemctl reboot";
        icon = "system-reboot";
        comment = "Restart the system";
        terminal = false;
        categories = [ "System" ];
      };
      shutdown = {
        name = "Shutdown";
        exec = "pkexec systemctl poweroff";
        icon = "system-shutdown";
        comment = "Power off the system";
        terminal = false;
        categories = [ "System" ];
      };
    };
  };
}
