{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  cmake,
  imagemagick,
  copyDesktopItems,
  makeDesktopItem,
  # System libraries gpui's platform backends link against (mirrors the
  # Linux packages in upstream's CI job).
  fontconfig,
  libxkbcommon,
  wayland,
  libxcb,
  libx11,
  libGL,
  vulkan-loader,
  lld,
  libicns,
}:

let
  # Upstream has cut no releases yet; pin main and note the date so a
  # future `version` bump has something to anchor to.
  version = "0.1.0-unstable-2026-09-07";
  src = fetchFromGitHub {
    owner = "eliheuer";
    repo = "runebender-gpui";
    rev = "edc7023b25f704c3e9dcc04a3a6dc3461691da68";
    hash = "sha256-E9FZD+zSCXmZf8BUH4up3NRC5YtJJ04PcXHtAkznHv0=";
  };
  # Test fixtures: two tests compile feature code against Virtua Grotesk,
  # from a sibling checkout or $RUNEBENDER_TEST_FONTS (see src/tests.rs).
  testFonts = fetchFromGitHub {
    owner = "eliheuer";
    repo = "virtua-grotesk";
    rev = "0c66c5c1dec632c710f703c838698538d1a53868";
    hash = "sha256-sPJrYZ0B4RUzoX7VRKNsc+D0jImR+0blQ6SRfnzYKYc=";
  };
  # Upstream logo for the macOS bundle and Linux desktop icon, from the
  # runebender.org site repo (the editor repo ships no icon).
  appIcon = fetchurl {
    url = "https://raw.githubusercontent.com/eliheuer/runebender-dot-org/main/public/assets/runebender-app-icon.png";
    hash = "sha256-0jYfF0yOaAT10xai10wxfjgUl1C60jIZp2peLdsgxbY=";
  };
in
rustPlatform.buildRustPackage {
  pname = "runebender-gpui";
  inherit version src;

  cargoHash = "sha256-1r/R1cOs7QhE0mWxEm5dF1mNe53bwuuzZBOG6//4IPY=";

  nativeBuildInputs = [
    pkg-config
    cmake
    imagemagick
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    copyDesktopItems
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    lld
    libicns
    rustPlatform.bindgenHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    fontconfig
    libxkbcommon
    wayland
    libxcb
    libx11
    libGL
    vulkan-loader
  ];

  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    # nixpkgs' classic ld64 fails to insert ARM64 branch thunks for large
    # GUI binaries; same workaround as nixpkgs' zed-editor.
    NIX_CFLAGS_LINK = "-fuse-ld=lld";
  }
  // {
    RUNEBENDER_TEST_FONTS = "${testFonts}/sources";
  };

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "runebender";
      exec = "runebender-gpui %F";
      icon = "runebender";
      desktopName = "Runebender";
      comment = "Font editor built on GPUI";
      categories = [ "Graphics" ];
      mimeTypes = [ "application/x-designspace" ];
    })
  ];

  postInstall =
    lib.optionalString stdenv.hostPlatform.isLinux ''
      mkdir -p $out/share/icons/hicolor/512x512/apps
      magick ${appIcon} -resize 512x512 \
        $out/share/icons/hicolor/512x512/apps/runebender.png
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      bundle=$out/Applications/Runebender.app/Contents
      mkdir -p $bundle/MacOS $bundle/Resources
      ln -s $out/bin/runebender-gpui $bundle/MacOS/runebender-gpui
      for size in 16 32 64 128 256 512 1024; do
        magick ${appIcon} -resize ''${size}x''${size} icon_$size.png
      done
      png2icns $bundle/Resources/Runebender.icns icon_*.png
      cat > $bundle/Info.plist <<'EOF'
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>runebender-gpui</string>
        <key>CFBundleIdentifier</key>
        <string>org.runebender.runebender-gpui</string>
        <key>CFBundleName</key>
        <string>Runebender</string>
        <key>CFBundleDisplayName</key>
        <string>Runebender</string>
        <key>CFBundleVersion</key>
        <string>${version}</string>
        <key>CFBundleShortVersionString</key>
        <string>${version}</string>
        <key>CFBundleIconFile</key>
        <string>Runebender</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>NSHighResolutionCapable</key>
        <true/>
      </dict>
      </plist>
      EOF
    '';

  meta = {
    description = "Free and open-source font editor built on GPUI";
    homepage = "https://runebender.org";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "runebender-gpui";
    # Built and smoke-tested here on aarch64-darwin and x86_64-linux.
    platforms = [
      "aarch64-darwin"
      "x86_64-linux"
    ];
  };
}
