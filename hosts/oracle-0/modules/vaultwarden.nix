{
  config,
  ...
}:
{
  # Vaultwarden secrets
  age.secrets = {
    vaultwarden-admin-token = {
      file = ../../../secrets/vaultwarden-admin-token.age;
      owner = "vaultwarden";
      group = "vaultwarden";
    };
  };

  # Vaultwarden service
  services.vaultwarden = {
    enable = true;
    environmentFile = config.age.secrets.vaultwarden-admin-token.path;
    config = {
      DOMAIN = "https://vault.cernohorsky.ca";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      SIGNUPS_ALLOWED = false;
      WEBSOCKET_ENABLED = true;
    };
  };
}
