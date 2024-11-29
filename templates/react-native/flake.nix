{
  description = "React Native development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, android }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        sdk = (import android { inherit pkgs; }).sdk (sdkPkgs: with sdkPkgs; [
          build-tools-33-0-0
          cmdline-tools-latest
          platform-tools
          platforms-android-33
          emulator
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core tools
            bun
            
            # React Native tools
            watchman
            cocoapods
            
            # Android tools
            android-studio
            jdk17
            gradle
            
            # Development tools
            typescript
            nodePackages.typescript-language-server
            
            # Common tools
            git
          ];

          shellHook = ''
            echo "📱 React Native development environment activated!"
            echo "Available tools:"
            echo "  - bun: $(bun --version)"
            echo "  - typescript: $(tsc --version)"
            echo "  - gradle: $(gradle --version | head -n1)"
            echo "  - java: $(java --version | head -n1)"
            echo ""
            echo "Quick start:"
            echo "  bun create react-native    # Create new project"
            echo "  cd my-app"
            echo "  bun install                # Install dependencies"
            echo "  bun ios                    # Run on iOS simulator"
            echo "  bun android                # Run on Android emulator"
            echo ""
            echo "Note: For iOS development, you'll need Xcode installed"

            # Set up Android environment
            export ANDROID_HOME="${sdk}/share/android-sdk"
            export ANDROID_SDK_ROOT="${sdk}/share/android-sdk"
            export JAVA_HOME="${pkgs.jdk17}/lib/openjdk"
            export PATH="$ANDROID_HOME/platform-tools:$PATH"
          '';
        };
      });
}
