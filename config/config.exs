import Config
config :arena, iniciar_http: config_env() != :test
config :logger, level: :warning
