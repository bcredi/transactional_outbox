import Config

config :transactional_outbox, ecto_repos: [TransactionalOutbox.Repo]

config :transactional_outbox, TransactionalOutbox.Repo,
  username: System.get_env("PG_USERNAME") || "mauriciogirardello",
  password: System.get_env("PG_PASSWORD") || "postgres",
  hostname: System.get_env("PG_HOST") || "localhost",
  port: System.get_env("PG_PORT") || 5433,
  database: System.get_env("PG_DATABASE") || "transactional_outbox_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support/"
