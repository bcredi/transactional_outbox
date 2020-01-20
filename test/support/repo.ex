defmodule TransactionalOutbox.Repo do
  use Ecto.Repo,
    otp_app: :transactional_outbox,
    adapter: Ecto.Adapters.Postgres
end
