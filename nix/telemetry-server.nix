{ config, lib, pkgs, ... }:

let
  cfg = config.services.ai-setup-telemetry;

  otlpEndpoint = "${cfg.address}:${toString cfg.otlpPort}";

  secretPatterns = lib.concatStringsSep "|" [
    "sk-[A-Za-z0-9_-]{20,}"
    "gh[pousr]_[A-Za-z0-9]{36,}"
    "github_pat_[A-Za-z0-9_]{20,}"
    "xox[abprs]-[A-Za-z0-9-]{10,}"
    "AKIA[0-9A-Z]{16}"
    "eyJ[A-Za-z0-9_-]{10,}[.][A-Za-z0-9_-]{10,}[.][A-Za-z0-9_-]{10,}"
  ];

  redact = target: "replace_all_patterns(${target}, \"value\", \"${secretPatterns}\", \"[REDACTED]\")";

  pipeline = extra: {
    receivers = [ "otlp" ];
    processors = [ "memory_limiter" ] ++ extra ++ [ "batch" ];
    exporters = [ "clickhouse" ];
  };
in
{
  options.services.ai-setup-telemetry = {
    enable = lib.mkEnableOption "the fleet telemetry store: an OTLP collector writing to ClickHouse";

    address = lib.mkOption {
      type = lib.types.str;
      example = "100.64.0.1";
      description = "Tailnet address to bind. Nothing listens on any other non-loopback address.";
    };

    otlpPort = lib.mkOption {
      type = lib.types.port;
      default = 4318;
      description = "OTLP/HTTP ingest port.";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "ClickHouse HTTP port that agents query.";
    };

    nativePort = lib.mkOption {
      type = lib.types.port;
      default = 19000;
      description = "ClickHouse native port, loopback use only in practice.";
    };

    dashboardPort = lib.mkOption {
      type = lib.types.port;
      default = 8125;
      description = "Port of the web dashboard. It listens on all interfaces; the firewall opens it on the tailnet only.";
    };

    readers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "100.64.0.2" ];
      description = "Addresses allowed to log in as the read-only `agent` user.";
    };

    retentionDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 365;
      description = "Days of raw telemetry to keep. Applied when the tables are first created.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      cfg.otlpPort
      cfg.httpPort
      cfg.dashboardPort
    ];

    services.clickhouse = {
      enable = true;
      serverConfig = {
        listen_host = [ "127.0.0.1" cfg.address ];
        http_port = cfg.httpPort;
        tcp_port = cfg.nativePort;
        mysql_port."@remove" = "1";
        postgresql_port."@remove" = "1";
        interserver_http_port."@remove" = "1";
      };
      usersConfig = {
        profiles.agent = {
          readonly = 2;
          max_execution_time = 60;
          max_result_rows = 5000;
          result_overflow_mode = "break";
        };
        users = {
          default.networks = {
            "@replace" = "replace";
            ip = [ "127.0.0.1" "::1" ];
          };
          agent = {
            password = "";
            profile = "agent";
            quota = "default";
            networks.ip = [ "127.0.0.1" ] ++ cfg.readers;
            grants.query = [
              "GRANT SELECT ON ai.*"
              "GRANT SELECT ON otel.*"
            ];
          };
        };
      };
    };

    systemd.services.clickhouse = {
      after = [ "tailscaled.service" ];
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    services.opentelemetry-collector = {
      enable = true;
      package = pkgs.opentelemetry-collector-contrib;
      settings = {
        receivers.otlp.protocols.http.endpoint = otlpEndpoint;

        processors = {
          memory_limiter = {
            check_interval = "5s";
            limit_mib = 1024;
          };
          batch.timeout = "5s";
          filter = {
            traces.span = [
              "IsMatch(name, \"^(fs[.]|append_items|persist_rollout_items|receiving|handle_responses)\")"
              "resource.attributes[\"service.name\"] == \"t3code-server\""
            ];
          };
          transform = {
            log_statements = [ (redact "log.attributes") ];
            trace_statements = [
              {
                context = "span";
                statements = [ (redact "span.attributes") ];
              }
              {
                context = "spanevent";
                statements = [ (redact "spanevent.attributes") ];
              }
            ];
          };
        };

        exporters.clickhouse = {
          endpoint = "http://127.0.0.1:${toString cfg.httpPort}";
          database = "otel";
          create_schema = true;
          ttl = "${toString (cfg.retentionDays * 24)}h";
          retry_on_failure = {
            enabled = true;
            max_elapsed_time = "1h";
          };
        };

        service = {
          telemetry.metrics.level = "none";
          pipelines = {
            logs = pipeline [ "transform" ];
            metrics = pipeline [ ];
            traces = pipeline [ "filter" "transform" ];
          };
        };
      };
    };

    systemd.services.opentelemetry-collector = {
      after = [ "clickhouse.service" "tailscaled.service" ];
      requires = [ "clickhouse.service" ];
      serviceConfig.RestartSec = 5;
    };

    systemd.services.ai-setup-telemetry-dashboard = {
      description = "Fleet agent dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [ "clickhouse.service" "tailscaled.service" ];
      environment = {
        DASHBOARD_ADDRESSES = "0.0.0.0";
        DASHBOARD_PORT = toString cfg.dashboardPort;
        DASHBOARD_CLICKHOUSE_URL = "http://127.0.0.1:${toString cfg.httpPort}";
      };
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${../telemetry}/dashboard.py";
        DynamicUser = true;
        Restart = "always";
        RestartSec = 5;
      };
    };

    systemd.services.ai-setup-telemetry-schema = {
      description = "Create the ai.* analysis views over the raw telemetry";
      wantedBy = [ "multi-user.target" ];
      after = [ "opentelemetry-collector.service" ];
      requires = [ "clickhouse.service" ];
      script = ''
        client="${config.services.clickhouse.package}/bin/clickhouse-client --host=127.0.0.1 --port=${toString cfg.nativePort}"
        until [ "$($client --query 'EXISTS TABLE otel.otel_logs' 2>/dev/null)" = 1 ]; do
          sleep 1
        done
        $client --multiquery --queries-file=${../telemetry/schema.sql}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        DynamicUser = true;
        TimeoutStartSec = 300;
      };
    };
  };
}
