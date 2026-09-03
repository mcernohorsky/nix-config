# Home Manager configuration for matt
{
  config,
  pkgs,
  inputs,
  lib,
  wallpaperImage,
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

in
{
  # COSMIC's defaults reference Firefox, COSMIC Terminal, and COSMIC Store,
  # none of which are part of this host. Keep the dock useful and icon-backed
  # by declaring the applications that are actually installed and supported.
  # Only these keys are managed; other COSMIC Settings changes remain writable.
  wayland.desktopManager.cosmic = {
    enable = true;
    applets.app-list.settings.favorites = [
      "helium"
      "com.system76.CosmicFiles"
      "com.system76.CosmicEdit"
      "com.mitchellh.ghostty"
      "steam"
      "com.system76.CosmicSettings"
    ];
    applets.time.settings = {
      first_day_of_week = 6; # Sunday
      military_time = false;
    };

    appearance.toolkit = {
      apply_theme_global = true;
      header_size = {
        __type = "enum";
        variant = "Standard";
      };
      # Trial the dark Colloid icon set across COSMIC and GTK. Revert this
      # string/package to Cosmic if the visual fit is worse.
      icon_theme = "Colloid-Dark";
      interface_density = {
        __type = "enum";
        variant = "Standard";
      };
      interface_font = {
        family = "Open Sans";
        weight = {
          __type = "enum";
          variant = "Normal";
        };
        stretch = {
          __type = "enum";
          variant = "Normal";
        };
        style = {
          __type = "enum";
          variant = "Normal";
        };
      };
      monospace_font = {
        family = "NordwandMono Nerd Font Mono";
        weight = {
          __type = "enum";
          variant = "Normal";
        };
        stretch = {
          __type = "enum";
          variant = "Normal";
        };
        style = {
          __type = "enum";
          variant = "Normal";
        };
      };
    };

    compositor = {
      active_hint = true;
      autotile = true;
      autotile_behavior = {
        __type = "enum";
        variant = "PerWorkspace";
      };
      edge_snap_threshold = 0;
      input_default = {
        state = {
          __type = "enum";
          variant = "Enabled";
        };
        scroll_config = {
          __type = "optional";
          value = {
            method = {
              __type = "optional";
              value = null;
            };
            natural_scroll = {
              __type = "optional";
              value = true;
            };
            scroll_button = {
              __type = "optional";
              value = null;
            };
            scroll_factor = {
              __type = "optional";
              value = null;
            };
          };
        };
      };
      xkb_config = {
        layout = "us";
        model = "pc104";
        options = {
          __type = "optional";
          value = "terminate:ctrl_alt_bksp,caps:escape";
        };
        repeat_delay = 600;
        repeat_rate = 25;
        rules = "";
        variant = "";
      };
      workspaces = {
        workspace_mode = {
          __type = "enum";
          variant = "OutputBound";
        };
        workspace_layout = {
          __type = "enum";
          variant = "Vertical";
        };
        workspace_wraparound = true;
      };
    };

    # Keep the deliberate compact top panel and larger floating dock. The
    # generic interface is necessary because cosmic-manager's typed autohide
    # representation predates COSMIC 1.5's Never/OnOverlap enum.
    configFile."com.system76.CosmicPanel" = {
      version = 1;
      entries.entries = [
        "Panel"
        "Dock"
      ];
    };
    configFile."com.system76.CosmicPanel.Panel" = {
      version = 1;
      entries = {
        anchor = {
          __type = "enum";
          variant = "Top";
        };
        anchor_gap = false;
        autohide = {
          __type = "enum";
          variant = "Never";
        };
        autohide_behavior = {
          wait_time = 1000;
          transition_time = 200;
          handle_size = 4;
          unhide_delay = 200;
        };
        background = {
          __type = "enum";
          variant = "ThemeDefault";
        };
        border_radius = 0;
        exclusive_zone = true;
        expand_to_edges = true;
        margin = 0;
        output = {
          __type = "enum";
          variant = "All";
        };
        padding = 0;
        size = {
          __type = "enum";
          variant = "XS";
        };
        spacing = 0;
      };
    };
    configFile."com.system76.CosmicPanel.Dock" = {
      version = 1;
      entries = {
        anchor = {
          __type = "enum";
          variant = "Bottom";
        };
        anchor_gap = false;
        autohide = {
          __type = "enum";
          variant = "OnOverlap";
        };
        autohide_behavior = {
          wait_time = 1000;
          transition_time = 200;
          handle_size = 4;
          unhide_delay = 200;
        };
        background = {
          __type = "enum";
          variant = "ThemeDefault";
        };
        border_radius = 8;
        exclusive_zone = false;
        expand_to_edges = false;
        margin = 0;
        output = {
          __type = "enum";
          variant = "All";
        };
        padding = 4;
        size = {
          __type = "enum";
          variant = "L";
        };
        spacing = 0;
      };
    };

    configFile."com.system76.CosmicFiles" = {
      version = 1;
      entries.favorites = [
        {
          __type = "enum";
          variant = "Home";
        }
        {
          __type = "enum";
          variant = "Documents";
        }
        {
          __type = "enum";
          variant = "Downloads";
        }
        {
          __type = "enum";
          variant = "Music";
        }
        {
          __type = "enum";
          variant = "Pictures";
        }
        {
          __type = "enum";
          variant = "Videos";
        }
        {
          __type = "enum";
          variant = "Path";
          value = [ "/mnt/hdd" ];
        }
      ];
    };

    # COSMIC Initial Setup reset these user-selected values on its first run.
    # Use the current v2 builder schema; cosmic-manager's typed theme module
    # still emits v1, so these entries intentionally use the generic interface.
    configFile."com.system76.CosmicTheme.Dark.Builder" = {
      version = 2;
      entries = {
        accent = {
          __type = "optional";
          value = "#FFAD00FF";
        };
        active_hint = 1;
        gaps = {
          __type = "tuple";
          value = [
            0
            6
          ];
        };
        corner_radii = {
          radius_0 = {
            __type = "tuple";
            value = [
              0.0
              0.0
              0.0
              0.0
            ];
          };
          radius_xs = {
            __type = "tuple";
            value = [
              2.0
              2.0
              2.0
              2.0
            ];
          };
          radius_s = {
            __type = "tuple";
            value = [
              8.0
              8.0
              8.0
              8.0
            ];
          };
          radius_m = {
            __type = "tuple";
            value = [
              8.0
              8.0
              8.0
              8.0
            ];
          };
          radius_l = {
            __type = "tuple";
            value = [
              8.0
              8.0
              8.0
              8.0
            ];
          };
          radius_xl = {
            __type = "tuple";
            value = [
              8.0
              8.0
              8.0
              8.0
            ];
          };
        };
        alpha_map = {
          extremely_low = 0.84;
          extremely_low_2 = 0.81692;
          very_low = 0.79385;
          very_low_2 = 0.77076;
          low = 0.74769;
          low_2 = 0.72461;
          medium = 0.70154;
          medium_2 = 0.67846;
          high = 0.65538;
          high_2 = 0.63231;
          very_high = 0.60023;
          very_high_2 = 0.58615;
          extremely_high = 0.56308;
          extremely_high_2 = 0.54;
        };
      };
    };

    wallpapers = [
      {
        output = "all";
        source = {
          __type = "enum";
          variant = "Path";
          value = [ "${wallpaperImage}" ];
        };
        filter_by_theme = true;
        rotation_frequency = 3600;
        filter_method = {
          __type = "enum";
          variant = "Lanczos";
        };
        scaling_mode = {
          __type = "enum";
          variant = "Zoom";
        };
        sampling_method = {
          __type = "enum";
          variant = "Alphanumeric";
        };
      }
    ];
  };

  imports = [
    ../../modules/home/opencode-v2.nix
    ../../modules/home/dev-templates.nix
    ../../modules/home/uv-python.nix
  ];

  modules.home.opencodeV2.enable = true;
  modules.home.devTemplates.enable = true;
  modules.home.uvPython.enable = true;
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

  # ===================
  # Terminal: Ghostty
  # ===================
  programs.ghostty = {
    enable = true;
    settings = {
      command = "${pkgs.nushell}/bin/nu";
      font-family = [
        "NordwandMono Nerd Font Mono"
        "Noto Color Emoji"
      ];
      font-size = 13;
      theme = "light:Gruvbox Light,dark:Gruvbox Dark Hard";
      background-opacity = 0.9;
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
  # Editor: Helix
  # ===================
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "gruvbox_dark_hard";
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
  # Modern CLI Tools
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

  # Btop system monitor
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

    # Development
    lazygit
    gh
    jq
    yq
    nodejs # `node` on PATH for Node-targeted tools and language servers

    # System info
    fastfetch
    cpufetch

    # COSMIC icon theme plus an installed fallback for apps whose artwork is
    # not covered by Colloid. COSMIC selects Colloid-Dark above; Papirus is
    # intentionally available but not selected globally.
    colloid-icon-theme
    papirus-icon-theme

    # Media
    celluloid
    loupe

    # Archive tools
    unrar

  ];

  # ===================
  # GTK Icon Theme
  # ===================
  gtk = {
    enable = true;
    iconTheme = {
      # Keep GTK/libadwaita on COSMIC's complete symbolic set. Colloid remains
      # the COSMIC icon-theme trial above, without breaking native controls in
      # apps such as Ghostty.
      name = "Cosmic";
      package = pkgs.cosmic-icons;
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
        "text/plain" = "Helix.desktop";
        "image/png" = "org.gnome.Loupe.desktop";
        "image/jpeg" = "org.gnome.Loupe.desktop";
        "image/webp" = "org.gnome.Loupe.desktop";
        "image/gif" = "org.gnome.Loupe.desktop";
        "video/mp4" = "io.github.celluloid_player.Celluloid.desktop";
        "video/x-matroska" = "io.github.celluloid_player.Celluloid.desktop";
        "video/webm" = "io.github.celluloid_player.Celluloid.desktop";
        "audio/mpeg" = "io.github.celluloid_player.Celluloid.desktop";
        "audio/ogg" = "io.github.celluloid_player.Celluloid.desktop";
        "application/pdf" = "com.system76.CosmicReader.desktop";
        "inode/directory" = "com.system76.CosmicFiles.desktop";
      };
    };
    terminal-exec = {
      enable = true;
      settings.default = [ "com.mitchellh.ghostty.desktop" ];
    };
    desktopEntries = {
      "ai.opencode" = {
        name = "OpenCode Beta";
        genericName = "AI Coding Agent";
        comment = "Official OpenCode v2 beta desktop app";
        exec = "/home/matt/.local/opt/opencode-beta/OpenCode.AppImage %U";
        icon = "applications-development";
        terminal = false;
        categories = [ "Development" ];
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
        icon = "org.jellyfin.JellyfinServer";
        comment = "Jellyfin Server Administration";
        terminal = false;
        categories = [
          "Network"
          "Settings"
        ];
      };
    };
  };
}
