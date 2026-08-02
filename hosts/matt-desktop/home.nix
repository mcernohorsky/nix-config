# Home Manager configuration for matt
{
  config,
  pkgs,
  inputs,
  lib,
  stylixWallpaperImage,
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

      # Only treat the session as locked if logind agrees *and* a locker process is running.
      # LockedHint can stay "yes" after a crash or tool mismatch, which made Walker launches no-op.
      if [ -n "''${XDG_SESSION_ID-}" ] &&
        [ "$(loginctl show-session "$XDG_SESSION_ID" -p LockedHint --value 2>/dev/null || true)" = "yes" ] &&
        pgrep -xu "$USER" -x hyprlock >/dev/null 2>&1; then
        exit 0
      fi

      if pgrep -xu "$USER" -x hyprlock >/dev/null 2>&1; then
        exit 0
      fi

      exec ${pkgs.hyprlock}/bin/hyprlock
    '';
  };

  brightness-control = pkgs.writeShellApplication {
    name = "brightness-control";
    runtimeInputs = [
      pkgs.asdbctl
      pkgs.gawk
      pkgs.libnotify
      pkgs.swayosd
    ];
    text = ''
      set -euo pipefail

      studio_display_available() {
        asdbctl get >/dev/null 2>&1
      }

      current_brightness() {
        asdbctl get | awk 'END { gsub(/[^0-9]/, "", $NF); print $NF }'
      }

      notify_brightness() {
        local brightness
        brightness="$(current_brightness)"
        notify-send \
          -h string:x-canonical-private-synchronous:studio-display-brightness \
          -h int:value:"$brightness" \
          "Studio Display brightness" \
          "$brightness%"
      }

      command="''${1:-get}"

      case "$command" in
        up|down)
          if studio_display_available; then
            asdbctl "$command"
            notify_brightness
          else
            swayosd-client --brightness "$command"
          fi
          ;;
        get)
          if studio_display_available; then
            current_brightness
          else
            printf 'No Apple Studio Display detected for asdbctl.\n' >&2
            exit 1
          fi
          ;;
        set)
          if [ $# -lt 2 ]; then
            printf 'Usage: brightness-control set <percent>\n' >&2
            exit 2
          fi

          if studio_display_available; then
            asdbctl set "$2"
            notify_brightness
          else
            printf 'No Apple Studio Display detected for asdbctl.\n' >&2
            exit 1
          fi
          ;;
        *)
          printf 'Usage: brightness-control [get|up|down|set <percent>]\n' >&2
          exit 2
          ;;
      esac
    '';
  };

in
{
  imports = [
    ../../modules/home/opencode-core.nix
    ../../modules/home/dev-templates.nix
  ];

  modules.home.opencodeCore.enable = true;
  modules.home.devTemplates.enable = true;
  nix.package = lib.mkForce null;

  home.username = "matt";
  home.homeDirectory = "/home/matt";
  home.stateVersion = "25.05";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  manual = {
    manpages.enable = false;
    html.enable = false;
    json.enable = false;
  };

  home.activation.configureCemu = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        cemu_config_dir="${config.home.homeDirectory}/.config/Cemu"
        cemu_settings="$cemu_config_dir/settings.xml"
        cemu_library_dir="${config.home.homeDirectory}/Games/WiiU"
        cemu_game_dir="$cemu_library_dir/games"
        cemu_legacy_game_dir="$cemu_library_dir"
        xmlstarlet="${pkgs.xmlstarlet}/bin/xmlstarlet"

        seed_cemu_settings() {
          cat > "$cemu_settings" <<'EOF'
    <?xml version="1.0" encoding="UTF-8"?>
    <content>
      <console_language>1</console_language>
      <disable_screensaver>true</disable_screensaver>
      <play_boot_sound>false</play_boot_sound>
      <feral_gamemode>true</feral_gamemode>
      <check_update>false</check_update>
      <receive_untested_updates>false</receive_untested_updates>
      <GamePaths/>
      <Graphic>
        <api>1</api>
        <VSync>0</VSync>
        <GX2DrawdoneSync>true</GX2DrawdoneSync>
        <UpscaleFilter>1</UpscaleFilter>
        <DownscaleFilter>0</DownscaleFilter>
        <FullscreenScaling>0</FullscreenScaling>
        <AsyncCompile>true</AsyncCompile>
        <vkAccurateBarriers>true</vkAccurateBarriers>
      </Graphic>
      <Audio>
        <api>3</api>
        <delay>2</delay>
        <TVChannels>1</TVChannels>
        <PadChannels>1</PadChannels>
        <InputChannels>0</InputChannels>
        <TVVolume>100</TVVolume>
        <PadVolume>100</PadVolume>
        <InputVolume>100</InputVolume>
        <PortalVolume>100</PortalVolume>
        <TVDevice>default</TVDevice>
        <PadDevice>default</PadDevice>
        <InputDevice/>
        <PortalDevice/>
      </Audio>
      <Input>
        <DSUC host="127.0.0.1" port="26760"/>
      </Input>
    </content>
    EOF
        }

        ensure_element() {
          path="$1"
          parent="$2"
          name="$3"
          if [ "$("$xmlstarlet" sel -t -v "count($path)" "$cemu_settings")" = "0" ]; then
            "$xmlstarlet" ed -L -s "$parent" -t elem -n "$name" -v "" "$cemu_settings"
          fi
        }

        set_value() {
          path="$1"
          parent="$2"
          name="$3"
          value="$4"
          ensure_element "$path" "$parent" "$name"
          "$xmlstarlet" ed -L -u "$path" -v "$value" "$cemu_settings"
        }

        install -d "$cemu_config_dir"
        install -d "$cemu_game_dir"
        install -d "$cemu_library_dir/installers/updates"
        install -d "$cemu_library_dir/installers/dlc"

        if [ ! -s "$cemu_settings" ]; then
          seed_cemu_settings
        elif ! "$xmlstarlet" val "$cemu_settings" >/dev/null 2>&1 || [ "$("$xmlstarlet" sel -t -v 'count(/content)' "$cemu_settings")" = "0" ]; then
          mv "$cemu_settings" "$cemu_settings.invalid"
          seed_cemu_settings
        fi

        ensure_element "/content/Graphic" "/content" "Graphic"
        ensure_element "/content/Audio" "/content" "Audio"
        ensure_element "/content/Input" "/content" "Input"
        ensure_element "/content/GamePaths" "/content" "GamePaths"

        "$xmlstarlet" ed -L -d "/content/GamePaths/Entry[text()='$cemu_legacy_game_dir']" "$cemu_settings"

        if [ "$("$xmlstarlet" sel -t -v "count(/content/GamePaths/Entry[text()='$cemu_game_dir'])" "$cemu_settings")" = "0" ]; then
          "$xmlstarlet" ed -L -s "/content/GamePaths" -t elem -n "Entry" -v "$cemu_game_dir" "$cemu_settings"
        fi

        set_value "/content/feral_gamemode" "/content" "feral_gamemode" "true"
        set_value "/content/check_update" "/content" "check_update" "false"
        set_value "/content/receive_untested_updates" "/content" "receive_untested_updates" "false"
        set_value "/content/disable_screensaver" "/content" "disable_screensaver" "true"
        set_value "/content/Graphic/api" "/content/Graphic" "api" "1"
        set_value "/content/Graphic/VSync" "/content/Graphic" "VSync" "0"
        set_value "/content/Graphic/AsyncCompile" "/content/Graphic" "AsyncCompile" "true"
        set_value "/content/Audio/api" "/content/Audio" "api" "3"
        set_value "/content/Audio/TVVolume" "/content/Audio" "TVVolume" "100"
        set_value "/content/Audio/PadVolume" "/content/Audio" "PadVolume" "100"
  '';

  # NixOS owns the compositor session; Home Manager owns and validates its config.
  wayland.windowManager.niri = {
    enable = true;
    package = pkgs.niri;
    systemd.enable = false;
    xwaylandSatellitePackage = null;
    portalPackage = null;

    settings = {
      screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
      prefer-no-csd = { };

      input = {
        mod-key = "Super";
        keyboard.xkb = {
          layout = "us";
          options = "caps:escape";
        };
        touchpad = {
          tap = { };
          natural-scroll = { };
        };
      };

      layout = {
        gaps = 16;
        struts = {
          left = 0;
          right = 0;
          top = 0;
          bottom = 0;
        };
        focus-ring.off = { };
        border = {
          width = 4;
          active-color = "#83a598";
          inactive-color = "#665c54";
        };
        default-column-width = { };
        center-focused-column = "never";
      };

      cursor = {
        xcursor-theme = "phinger-cursors-light";
        xcursor-size = 24;
      };

      binds = {
        "Mod+Shift+Slash".show-hotkey-overlay = { };
        "Mod+T".spawn = [ "ghostty" ];
        "Mod+Space".spawn = [ "walker" ];
        "Mod+B".spawn = [ "helium" ];
        "Super+Alt+L" = {
          _props = {
            allow-inhibiting = false;
            allow-when-locked = false;
            repeat = false;
            hotkey-overlay-title = "Lock the Screen";
          };
          spawn = [ (lib.getExe lock-now) ];
        };

        "XF86AudioRaiseVolume" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--output-volume"
            "raise"
          ];
        };
        "XF86AudioLowerVolume" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--output-volume"
            "lower"
          ];
        };
        "XF86AudioMute" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--output-volume"
            "mute-toggle"
          ];
        };
        "XF86AudioMicMute" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--input-volume"
            "mute-toggle"
          ];
        };
        "XF86AudioPlay" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--playerctl"
            "play-pause"
          ];
        };
        "XF86AudioStop" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--playerctl"
            "stop"
          ];
        };
        "XF86AudioPrev" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--playerctl"
            "prev"
          ];
        };
        "XF86AudioNext" = {
          _props.allow-when-locked = true;
          spawn = [
            "swayosd-client"
            "--playerctl"
            "next"
          ];
        };
        "XF86MonBrightnessUp" = {
          _props.allow-when-locked = true;
          spawn = [
            (lib.getExe brightness-control)
            "up"
          ];
        };
        "XF86MonBrightnessDown" = {
          _props.allow-when-locked = true;
          spawn = [
            (lib.getExe brightness-control)
            "down"
          ];
        };

        "Mod+O".toggle-overview = { };
        "Mod+Q".close-window = { };

        "Mod+Left".focus-column-left = { };
        "Mod+Down".focus-window-down = { };
        "Mod+Up".focus-window-up = { };
        "Mod+Right".focus-column-right = { };
        "Mod+H".focus-column-left = { };
        "Mod+J".focus-window-down = { };
        "Mod+K".focus-window-up = { };
        "Mod+L".focus-column-right = { };

        "Mod+Ctrl+Left".move-column-left = { };
        "Mod+Ctrl+Down".move-window-down = { };
        "Mod+Ctrl+Up".move-window-up = { };
        "Mod+Ctrl+Right".move-column-right = { };
        "Mod+Ctrl+H".move-column-left = { };
        "Mod+Ctrl+J".move-window-down = { };
        "Mod+Ctrl+K".move-window-up = { };
        "Mod+Ctrl+L".move-column-right = { };

        "Mod+Home".focus-column-first = { };
        "Mod+End".focus-column-last = { };
        "Mod+Ctrl+Home".move-column-to-first = { };
        "Mod+Ctrl+End".move-column-to-last = { };

        "Mod+Shift+Left".focus-monitor-left = { };
        "Mod+Shift+Down".focus-monitor-down = { };
        "Mod+Shift+Up".focus-monitor-up = { };
        "Mod+Shift+Right".focus-monitor-right = { };
        "Mod+Shift+H".focus-monitor-left = { };
        "Mod+Shift+J".focus-monitor-down = { };
        "Mod+Shift+K".focus-monitor-up = { };
        "Mod+Shift+L".focus-monitor-right = { };

        "Mod+Shift+Ctrl+Left".move-column-to-monitor-left = { };
        "Mod+Shift+Ctrl+Down".move-column-to-monitor-down = { };
        "Mod+Shift+Ctrl+Up".move-column-to-monitor-up = { };
        "Mod+Shift+Ctrl+Right".move-column-to-monitor-right = { };
        "Mod+Shift+Ctrl+H".move-column-to-monitor-left = { };
        "Mod+Shift+Ctrl+J".move-column-to-monitor-down = { };
        "Mod+Shift+Ctrl+K".move-column-to-monitor-up = { };
        "Mod+Shift+Ctrl+L".move-column-to-monitor-right = { };

        "Mod+Page_Down".focus-workspace-down = { };
        "Mod+Page_Up".focus-workspace-up = { };
        "Mod+U".focus-workspace-down = { };
        "Mod+I".focus-workspace-up = { };
        "Mod+Ctrl+Page_Down".move-column-to-workspace-down = { };
        "Mod+Ctrl+Page_Up".move-column-to-workspace-up = { };
        "Mod+Ctrl+U".move-column-to-workspace-down = { };
        "Mod+Ctrl+I".move-column-to-workspace-up = { };
        "Mod+Shift+Page_Down".move-workspace-down = { };
        "Mod+Shift+Page_Up".move-workspace-up = { };
        "Mod+Shift+U".move-workspace-down = { };
        "Mod+Shift+I".move-workspace-up = { };

        "Mod+N".spawn-sh = "swaync-client -t -sw";
        "Mod+1".focus-workspace = 1;
        "Mod+2".focus-workspace = 2;
        "Mod+3".focus-workspace = 3;
        "Mod+4".focus-workspace = 4;
        "Mod+5".focus-workspace = 5;
        "Mod+6".focus-workspace = 6;
        "Mod+7".focus-workspace = 7;
        "Mod+8".focus-workspace = 8;
        "Mod+9".focus-workspace = 9;
        "Mod+Ctrl+1".move-column-to-workspace = 1;
        "Mod+Ctrl+2".move-column-to-workspace = 2;
        "Mod+Ctrl+3".move-column-to-workspace = 3;
        "Mod+Ctrl+4".move-column-to-workspace = 4;
        "Mod+Ctrl+5".move-column-to-workspace = 5;
        "Mod+Ctrl+6".move-column-to-workspace = 6;
        "Mod+Ctrl+7".move-column-to-workspace = 7;
        "Mod+Ctrl+8".move-column-to-workspace = 8;
        "Mod+Ctrl+9".move-column-to-workspace = 9;

        "Mod+BracketLeft".consume-or-expel-window-left = { };
        "Mod+BracketRight".consume-or-expel-window-right = { };
        "Mod+Comma".consume-window-into-column = { };
        "Mod+Period".expel-window-from-column = { };

        "Mod+R".switch-preset-column-width = { };
        "Mod+Shift+R".switch-preset-window-height = { };
        "Mod+Ctrl+R".reset-window-height = { };
        "Mod+F".maximize-column = { };
        "Mod+Shift+F".fullscreen-window = { };
        "Mod+Ctrl+F".expand-column-to-available-width = { };
        "Mod+C".center-column = { };
        "Mod+Ctrl+C".center-visible-columns = { };
        "Mod+Minus".set-column-width = "-10%";
        "Mod+Equal".set-column-width = "+10%";
        "Mod+Shift+Minus".set-window-height = "-10%";
        "Mod+Shift+Equal".set-window-height = "+10%";
        "Mod+V".toggle-window-floating = { };
        "Mod+Shift+V".switch-focus-between-floating-and-tiling = { };
        "Mod+W".toggle-column-tabbed-display = { };

        "Print".screenshot = { };
        "Ctrl+Print".screenshot-screen = { };
        "Alt+Print".screenshot-window = { };
        "Mod+S".screenshot = { };

        "Mod+Escape" = {
          _props.allow-inhibiting = false;
          toggle-keyboard-shortcuts-inhibit = { };
        };
        "Mod+Shift+E".quit = { };
        "Ctrl+Alt+Delete".quit = { };
        "Mod+Shift+P".power-off-monitors = { };
      };

      _children = [
        {
          spawn-at-startup._args = [
            "systemctl"
            "--user"
            "start"
            "swayosd.service"
            "swaync.service"
            "elephant.service"
            "walker.service"
          ];
        }
        { spawn-at-startup._args = [ "waybar" ]; }
        { spawn-at-startup._args = [ "nm-applet" ]; }
        { spawn-at-startup._args = [ "blueman-applet" ]; }
        {
          spawn-at-startup._args = [
            "sh"
            "-c"
            "wl-paste --type text --watch cliphist store"
          ];
        }
        {
          spawn-at-startup._args = [
            "sh"
            "-c"
            "wl-paste --type image --watch cliphist store"
          ];
        }
        {
          window-rule = {
            clip-to-geometry = true;
            draw-border-with-background = false;
            geometry-corner-radius = [
              12.0
              12.0
              12.0
              12.0
            ];
          };
        }
        {
          window-rule._children = [
            { match._props.app-id = "pavucontrol"; }
            { match._props.app-id = "pwvucontrol"; }
            { match._props.app-id = "blueman-manager"; }
            { match._props.app-id = "nm-connection-editor"; }
            { open-floating = true; }
          ];
        }
        {
          window-rule._children = [
            { match._props.title = "^Picture-in-Picture$"; }
            { open-floating = true; }
          ];
        }
        {
          window-rule._children = [
            { match._props.app-id = "^com[.]mitchellh[.]ghostty$"; }
            { background-effect.blur = true; }
          ];
        }
        {
          layer-rule = {
            match._props.namespace = "^walker$";
            geometry-corner-radius = 12;
            background-effect.blur = true;
          };
        }
        {
          layer-rule = {
            match._props.namespace = "^waybar$";
            background-effect.blur = true;
          };
        }
        {
          layer-rule = {
            match._props.namespace = "^swaync-control-center$";
            geometry-corner-radius = 10;
            background-effect.blur = true;
          };
        }
        {
          layer-rule = {
            match._props.namespace = "^swaync-notification-window$";
            geometry-corner-radius = 10;
            background-effect.blur = true;
          };
        }
      ];
    };
  };

  services.hyprpaper.enable = lib.mkForce false;
  services.wpaperd.enable = true;

  # ===================
  # Hyprlock Configuration
  # ===================
  stylix.targets.hyprlock.enable = false;

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
          # Same image as Stylix desktop wallpaper (see configuration.nix stylixWallpaperImage)
          path = "${stylixWallpaperImage}";
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
        background-color: rgba(40, 40, 40, 0.86);
        border: 1px solid rgba(215, 153, 33, 0.35);
        border-radius: 12px;
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
        background-color: rgba(40, 40, 40, 0.84);
        border: 1px solid rgba(215, 153, 33, 0.45);
        border-radius: 12px;
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
        background-color: rgba(40, 40, 40, 0.80);
        border-bottom: 1px solid rgba(215, 153, 33, 0.30);
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
          background: alpha(@base, 0.82);
          padding: 20px;
          border: 1px solid alpha(@border, 0.55);
          border-radius: 12px;
        }

        .search-container {
          background: alpha(@base, 0.55);
          border-radius: 8px;
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

  systemd.user.services.walker.Service = {
    Environment = [
      "GDK_BACKEND=wayland"
      "GSK_RENDERER=ngl"
    ];
    # Propagate graphical session into the walker process so .desktop Exec (e.g. hyprlock) matches keybinds.
    PassEnvironment = [
      "WAYLAND_DISPLAY"
      "XDG_RUNTIME_DIR"
      "NIRI_SOCKET"
      "XDG_SESSION_ID"
      "XDG_SESSION_TYPE"
      "XDG_CURRENT_DESKTOP"
      "DISPLAY"
      "DBUS_SESSION_BUS_ADDRESS"
    ];
  };

  # ===================
  # Terminal: Ghostty (theming/fonts handled by Stylix)
  # ===================
  programs.ghostty = {
    enable = true;
    settings = {
      command = "nu"; # Launch nushell directly
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
    solaar
    brightness-control

    # Development
    lazygit
    gh
    jq
    yq
    opencode-desktop
    nodejs # `node` on PATH: TS/Svelte language servers, opencode-cursor-oauth h2-bridge child, npm globals

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
  home.pointerCursor.enable = true;

  gtk = {
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # ===================
  # XDG
  # ===================
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
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
      "info.cemu.Cemu" = {
        name = "Cemu";
        genericName = "Wii U Emulator";
        comment = "Wii U emulator";
        exec = "${pkgs.coreutils}/bin/env GDK_BACKEND=x11 SDL_VIDEODRIVER=x11 /run/current-system/sw/bin/Cemu";
        icon = "info.cemu.Cemu";
        terminal = false;
        categories = [
          "Game"
          "Emulator"
        ];
      };
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
        # Same as niri keybinds (6d40301): direct lock-now; PassEnvironment on walker.service supplies Wayland.
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
        exec = "/run/wrappers/bin/sudo -n ${pkgs.systemd}/bin/systemctl reboot";
        icon = "system-reboot";
        comment = "Restart the system";
        terminal = false;
        categories = [ "System" ];
      };
      shutdown = {
        name = "Shutdown";
        exec = "/run/wrappers/bin/sudo -n ${pkgs.systemd}/bin/systemctl poweroff";
        icon = "system-shutdown";
        comment = "Power off the system";
        terminal = false;
        categories = [ "System" ];
      };
    };
  };
}
