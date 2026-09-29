# SSH public keys shared by host configs and secrets/secrets.nix.
{
  # matt's personal key: user identity and agenix editing key.
  matt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+m8GdqyC7+Zya3fNjQcyJsYgLHtIOGQEH8a0BMmJJP matt@cernohorsky.ca";

  # Host keys (agenix decryption on the NixOS targets).
  matt-desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACF1GTzZ7Im6JEByiOPam0BMwJtqMP4ud3ni1pmiNeV";
  oracle-0 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBfUg/nBbInHvjCLoo0CX0Wvh/VW8TxBOc8ve587ba/Y";
}
