{ config, lib, pkgs, ... }:
let
  grafanaPort = 3010;  # local loopback port
  prometheusPort = 3020;
in
{
  # Remove Netdata
  services.netdata.enable = lib.mkForce false;

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
        static_configs = [{ targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }];
      }
      {
        job_name = "prometheus";
        static_configs = [{ targets = [ "127.0.0.1:${toString prometheusPort}" ]; }];
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

  # Caddy vhost for Grafana
  services.caddy.virtualHosts."metrics.cernohorsky.ca".extraConfig = ''
    reverse_proxy 127.0.0.1:${toString grafanaPort}
    encode gzip
    header {
      Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      X-Content-Type-Options "nosniff"
      X-Frame-Options "DENY"
      Referrer-Policy "strict-origin-when-cross-origin"
    }
  '';
}


