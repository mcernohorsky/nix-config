{
  go = {
    path = ./go;
    description = "Go development environment";
  };
  haskell = {
    path = ./haskell;
    description = "Haskell development environment";
  };
  python = {
    path = ./python;
    description = "Python development environment (uv-first)";
  };
  rust = {
    path = ./rust;
    description = "Rust development environment";
  };
  svelte = {
    path = ./svelte;
    description = "Svelte on top of the TypeScript/Bun toolchain (also exposes devShells.typescript)";
  };
  typescript = {
    path = ./typescript;
    description = "TypeScript with Bun (runtime/package manager) and Biome";
  };
  typst = {
    path = ./typst;
    description = "Typst development environment";
  };
  zig = {
    path = ./zig;
    description = "Zig development environment";
  };
}
