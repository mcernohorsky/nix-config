{
  config,
  ...
}:
let
  grafanaPort = 3010;
  prometheusPort = 3020;
in
{
  # Prometheus server
  services.prometheus = {
    enable = true;
    port = prometheusPort;
    globalConfig.scrape_interval = "15s";
    # Exporters
    exporters.node = {
      enable = true;
      port = 3021;
      listenAddress = "127.0.0.1";
      enabledCollectors = [ "systemd" ];
    };
    # Scrape targets
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
        ];
      }
      {
        job_name = "prometheus";
        static_configs = [ { targets = [ "127.0.0.1:${toString prometheusPort}" ]; } ];
      }
    ];
  };

  # Grafana (loopback only; exposed via Caddy)
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "metrics.cernohorsky.ca";
        root_url = "https://metrics.cernohorsky.ca";
        enforce_domain = true;
      };
      analytics = {
        reporting_enabled = false;
      };
      security = {
        allow_embedding = false;
        cookie_secure = true;
        cookie_samesite = "lax";
        secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      };
    };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            access = "proxy";
            url = "http://127.0.0.1:${toString prometheusPort}";
            isDefault = true;
          }
        ];
      };
    };
  };
}
