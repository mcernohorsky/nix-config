{
  config,
  pkgs,
  inputs,
  lib,
  osConfig,
  ...
}:

let
  mono = import ../../lib/mono-font.nix { inherit pkgs; };

  # NASA Artemis II Earthset, original 5568x3712 image from NASA's Flickr.
  wallpaper = pkgs.fetchurl {
    name = "artemis-ii-earthset.jpg";
    url = "https://www.flickr.com/photo_download.gne?id=55192132107&secret=00dc598014&size=o&source=photoPageEngagement";
    hash = "sha256-nsaMkJZmtPQjmkQcWbpZ0DNZvGSzUKzw/1LxhFwGScM=";
  };

  # COSMIC's RON-style tagged values.
  mkEnum = variant: {
    __type = "enum";
    inherit variant;
  };
  mkOptional = value: {
    __type = "optional";
    inherit value;
  };
  mkTuple = value: {
    __type = "tuple";
    inherit value;
  };
  mkRadii = v: mkTuple (lib.replicate 4 v);
  mkFont = family: {
    inherit family;
    weight = mkEnum "Normal";
    stretch = mkEnum "Normal";
    style = mkEnum "Normal";
  };
  mkPanel = entries: {
    version = 1;
    entries = {
      anchor_gap = false;
      autohide_behavior = {
        wait_time = 1000;
        transition_time = 200;
        handle_size = 4;
        unhide_delay = 200;
      };
      background = mkEnum "ThemeDefault";
      margin = 0;
      output = mkEnum "All";
      spacing = 0;
    }
    // entries;
  };

  # Jellyfin Desktop crashes under native Wayland and the COSMIC Qt theme.
  jellyfin = pkgs.writeShellScript "jellyfin-desktop" ''
    export QT_QPA_PLATFORM=xcb QT_STYLE_OVERRIDE=Fusion
    unset QT_QPA_PLATFORMTHEME
    exec ${lib.getExe pkgs.jellyfin-desktop} "$@"
  '';

  mimeDefaults = app: types: lib.genAttrs types (_: "${app}.desktop");
in
{
  # Only these keys are managed; other COSMIC Settings changes stay writable.
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
      header_size = mkEnum "Standard";
      icon_theme = "Colloid-Dark";
      interface_density = mkEnum "Standard";
      interface_font = mkFont "Open Sans";
      monospace_font = mkFont mono.family;
    };

    compositor = {
      active_hint = true;
      autotile = true;
      autotile_behavior = mkEnum "PerWorkspace";
      edge_snap_threshold = 0;
      input_default = {
        state = mkEnum "Enabled";
        scroll_config = mkOptional {
          method = mkOptional null;
          natural_scroll = mkOptional true;
          scroll_button = mkOptional null;
          scroll_factor = mkOptional null;
        };
      };
      xkb_config = {
        layout = "us";
        model = "pc104";
        options = mkOptional "terminate:ctrl_alt_bksp,caps:escape";
        repeat_delay = 600;
        repeat_rate = 25;
        rules = "";
        variant = "";
      };
      workspaces = {
        workspace_mode = mkEnum "OutputBound";
        workspace_layout = mkEnum "Vertical";
        workspace_wraparound = true;
      };
    };

    # cosmic-manager's typed panel and theme modules predate COSMIC 1.5's
    # autohide enum and the v2 theme builder, so use the generic interface.
    configFile."com.system76.CosmicPanel" = {
      version = 1;
      entries.entries = [
        "Panel"
        "Dock"
      ];
    };
    configFile."com.system76.CosmicPanel.Panel" = mkPanel {
      anchor = mkEnum "Top";
      autohide = mkEnum "Never";
      border_radius = 0;
      exclusive_zone = true;
      expand_to_edges = true;
      padding = 0;
      size = mkEnum "XS";
    };
    configFile."com.system76.CosmicPanel.Dock" = mkPanel {
      anchor = mkEnum "Bottom";
      autohide = mkEnum "OnOverlap";
      border_radius = 8;
      exclusive_zone = false;
      expand_to_edges = false;
      padding = 4;
      size = mkEnum "L";
    };

    configFile."com.system76.CosmicFiles" = {
      version = 1;
      entries.favorites =
        map mkEnum [
          "Home"
          "Documents"
          "Downloads"
          "Music"
          "Pictures"
          "Videos"
        ]
        ++ [ (mkEnum "Path" // { value = [ "/mnt/hdd" ]; }) ];
    };

    configFile."com.system76.CosmicTheme.Dark.Builder" = {
      version = 2;
      entries = {
        accent = mkOptional "#FFAD00FF";
        active_hint = 1;
        gaps = mkTuple [
          0
          6
        ];
        corner_radii = {
          radius_0 = mkRadii 0.0;
          radius_xs = mkRadii 2.0;
          radius_s = mkRadii 8.0;
          radius_m = mkRadii 8.0;
          radius_l = mkRadii 8.0;
          radius_xl = mkRadii 8.0;
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
        source = mkEnum "Path" // {
          value = [ "${wallpaper}" ];
        };
        filter_by_theme = true;
        rotation_frequency = 3600;
        filter_method = mkEnum "Lanczos";
        scaling_mode = mkEnum "Zoom";
        sampling_method = mkEnum "Alphanumeric";
      }
    ];
  };

  # Private half of matt's key for desktop-to-Mac SSH, kept out of the store.
  home.activation.installSshUserKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -D -m 0600 ${osConfig.age.secrets.ssh-user-key.path} "$HOME/.ssh/id_ed25519"
  '';

  # HEX voice dictation (Linux beta; COSMIC is outside its supported targets).
  # Run `hex model install` once, then `hex app` for Settings.
  programs.hex = {
    enable = true;
    autostart = true;
  };

  # Determinate manages Nix itself; Home Manager must not install a competing
  # nix package or daemon profile on this host.
  nix.package = lib.mkForce null;

  home.stateVersion = "25.05";

  programs.ghostty = {
    enable = true;
    settings = {
      font-size = 13;
      background-opacity = 0.9;
      window-padding-x = 10;
      window-padding-y = 10;
      cursor-style = "block";
      cursor-style-blink = false;
      copy-on-select = true;
      confirm-close-surface = false;
    };
  };

  programs.yazi.settings = {
    mgr = {
      sort_by = "natural";
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

  home.shellAliases = {
    ga = "git add";
    gc = "git commit";
    gp = "git push";
    gl = "git pull";
  };

  programs.nushell = {
    shellAliases = {
      ls = "eza --icons";
      ll = "ls -l";
      la = "ls -la";
      lt = "eza --tree --icons";
      cat = "bat";
      grep = "rg";
      find = "fd";
      nrs = "sudo nixos-rebuild switch --flake ~/.config/nix-config#matt-desktop";
      nrt = "sudo nixos-rebuild test --flake ~/.config/nix-config#matt-desktop";
    };
    settings = {
      buffer_editor = "hx";
      history = {
        max_size = 10000;
        sync_on_enter = true;
        file_format = "sqlite";
      };
      completions = {
        case_sensitive = false;
        quick = true;
        partial = true;
        algorithm = "fuzzy";
      };
      table = {
        mode = "rounded";
        index_mode = "auto";
        show_empty = true;
        padding = {
          left = 1;
          right = 1;
        };
        trim = {
          methodology = "wrapping";
          wrapping_try_keep_words = true;
        };
        header_on_separator = false;
      };
    };
  };

  programs.carapace.enable = true;

  programs.starship = {
    enable = true;
    enableNushellIntegration = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$nix_shell$character";
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

  programs.git.settings = {
    pull.rebase = true;
    push.autoSetupRemote = true;
    merge.conflictstyle = "diff3";
    diff.colorMoved = "default";
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

  programs.eza.enable = true;
  programs.fd.enable = true;

  programs.btop = {
    enable = true;
    settings = {
      theme_background = false;
      vim_keys = true;
    };
  };

  home.packages = with pkgs; [
    inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default
    solaar
    jq
    yq
    fastfetch
    cpufetch
    colloid-icon-theme
    papirus-icon-theme # Fallback for artwork Colloid doesn't cover
    celluloid
    loupe
    unrar
  ];

  gtk = {
    enable = true;
    # COSMIC's complete symbolic set, so native controls (e.g. Ghostty) keep working.
    iconTheme = {
      name = "Cosmic";
      package = pkgs.cosmic-icons;
    };
  };

  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
    };
    mimeApps = {
      enable = true;
      defaultApplications = lib.mergeAttrsList [
        (mimeDefaults "helium" [
          "text/html"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
        ])
        (mimeDefaults "Helix" [ "text/plain" ])
        (mimeDefaults "org.gnome.Loupe" [
          "image/png"
          "image/jpeg"
          "image/webp"
          "image/gif"
        ])
        (mimeDefaults "io.github.celluloid_player.Celluloid" [
          "video/mp4"
          "video/x-matroska"
          "video/webm"
          "audio/mpeg"
          "audio/ogg"
        ])
        (mimeDefaults "com.system76.CosmicReader" [ "application/pdf" ])
        (mimeDefaults "com.system76.CosmicFiles" [ "inode/directory" ])
      ];
    };
    terminal-exec = {
      enable = true;
      settings.default = [ "com.mitchellh.ghostty.desktop" ];
    };
    desktopEntries = {
      "ai.opencode" = {
        name = "OpenCode";
        genericName = "AI Coding Agent";
        comment = "Official OpenCode v2 desktop app";
        exec = "${config.home.homeDirectory}/.local/opt/opencode/OpenCode.AppImage %U";
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
        exec = "${jellyfin}";
        icon = "jellyfin";
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
        terminal = false;
        categories = [
          "Network"
          "Settings"
        ];
      };
    };
  };
}
