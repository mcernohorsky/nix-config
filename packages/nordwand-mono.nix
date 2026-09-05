{
  lib,
  nerd-font-patcher,
  python3,
  stdenvNoCC,
  src,
}:
let
  # Upstream no longer ships built Nordwand fonts; generate them from source.
  generator = python3.withPackages (
    ps: with ps; [
      booleanoperations
      fonttools
      numpy
      skia-pathops
      ttfautohint-py
      ufolib2
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "nordwand-mono";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [
    generator
    nerd-font-patcher
  ];

  buildPhase = ''
    runHook preBuild
    PYTHONPATH="$PWD/src" python3 -m generate_font --ttf
    mkdir patched
    for font in fonts/ttf/*.ttf; do
      [ -e "$font" ] || {
        echo "no TTFs generated" >&2
        exit 1
      }
      nerd-font-patcher --complete --mono --careful --outputdir patched "$font"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 patched/*.ttf -t $out/share/fonts/truetype
    runHook postInstall
  '';

  meta = {
    description = "Compact monospace neo-grotesque font patched with Nerd Font glyphs";
    homepage = "https://github.com/tywr/Nordwand-Mono";
    license = lib.licenses.ofl;
    platforms = lib.platforms.all;
  };
}
