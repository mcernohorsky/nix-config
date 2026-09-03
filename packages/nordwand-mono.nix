{
  lib,
  nerd-font-patcher,
  stdenvNoCC,
  src,
}:

stdenvNoCC.mkDerivation {
  pname = "nordwand-mono";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [ nerd-font-patcher ];

  buildPhase = ''
    runHook preBuild
    mkdir patched
    for font in fonts/ttf/*.ttf; do
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
