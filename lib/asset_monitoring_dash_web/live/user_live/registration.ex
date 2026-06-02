defmodule AssetMonitoringDashWeb.UserLive.Registration do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.Accounts
  alias AssetMonitoringDash.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section
        id="registration-page"
        class="grid min-h-[calc(100vh-4rem)] place-items-center px-4 py-10 sm:px-6 lg:px-8"
      >
        <div class="grid w-full max-w-5xl overflow-hidden rounded-app border border-app-border bg-app-surface shadow-app-panel lg:grid-cols-[minmax(0,0.9fr)_minmax(420px,1fr)]">
          <aside class="relative hidden min-h-[560px] overflow-hidden border-r border-app-border bg-app-bg p-10 lg:block">
            <div class="absolute inset-x-0 top-0 h-1 bg-app-accent"></div>
            <div class="absolute inset-0 bg-[linear-gradient(135deg,rgba(97,184,105,0.10),transparent_38%,rgba(20,184,213,0.05))]">
            </div>

            <div class="relative flex h-full flex-col justify-between">
              <div>
                <p class="font-mono text-xs font-semibold uppercase tracking-[0.22em] text-app-muted">
                  Operator workspace
                </p>
                <h1 class="mt-5 font-display text-4xl font-semibold tracking-normal text-app-fg">
                  Register for an account
                </h1>
                <p class="mt-4 max-w-sm text-sm leading-6 text-app-muted">
                  Create a local demo operator profile so the cockpit can keep review actions and session access tied to an authenticated user.
                </p>
              </div>

              <dl class="grid gap-3">
                <div class="rounded-app border border-app-border bg-app-surface/80 p-4">
                  <dt class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
                    Access model
                  </dt>
                  <dd class="mt-2 text-sm font-semibold text-app-fg">
                    Magic link first, optional password after sign-in
                  </dd>
                </div>
                <div class="rounded-app border border-app-border bg-app-surface/80 p-4">
                  <dt class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
                    Demo boundary
                  </dt>
                  <dd class="mt-2 text-sm font-semibold text-app-fg">
                    Public visitors stay outside mutable simulator workflows
                  </dd>
                </div>
              </dl>
            </div>
          </aside>

          <div class="bg-app-surface px-5 py-8 sm:px-8 lg:px-10 lg:py-10">
            <div class="mx-auto max-w-md">
              <div>
                <p class="font-mono text-xs font-semibold uppercase tracking-[0.22em] text-app-muted">
                  Demo access
                </p>
                <h2 class="mt-3 font-display text-3xl font-semibold tracking-normal text-app-fg">
                  Register for an account
                </h2>
                <p class="mt-3 text-sm leading-6 text-app-muted">
                  Already registered?
                  <.link
                    navigate={~p"/users/log-in"}
                    class="font-semibold text-app-accent transition hover:text-app-fg"
                  >
                    Log in
                  </.link>
                  to your account now.
                </p>
              </div>

              <div
                :if={local_mail_adapter?()}
                id="registration-mail-adapter-notice"
                class="mt-6 flex gap-3 rounded-app border border-app-accent-2/25 bg-app-accent-2/10 p-4 text-sm text-app-fg"
              >
                <.icon
                  name="hero-information-circle"
                  class="mt-0.5 size-5 shrink-0 text-app-accent-2"
                />
                <div class="min-w-0">
                  <p class="font-semibold">Confirmation links stay local.</p>
                  <p class="mt-1 text-app-muted">
                    After registration, open
                    <.link
                      href="/dev/mailbox"
                      class="font-semibold text-app-accent-2 hover:text-app-fg"
                    >
                      the mailbox page
                    </.link>
                    to complete the demo sign-in.
                  </p>
                </div>
              </div>

              <.form
                for={@form}
                id="registration_form"
                phx-submit="save"
                phx-change="validate"
                class="mt-8"
              >
                <.input
                  field={@form[:email]}
                  type="email"
                  label="Email"
                  autocomplete="username"
                  spellcheck="false"
                  required
                  phx-mounted={JS.focus()}
                  class={input_class()}
                />

                <.button
                  phx-disable-with="Creating account..."
                  class="mt-4 inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-app border border-app-primary-bg bg-app-primary-bg px-4 text-sm font-semibold text-app-primary-fg transition hover:brightness-110 focus:outline-none focus:ring-2 focus:ring-app-accent/30 disabled:cursor-not-allowed disabled:opacity-60"
                >
                  Create an account <span aria-hidden="true">→</span>
                </.button>
              </.form>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: AssetMonitoringDashWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)

    {:ok, assign_form(socket, changeset), temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "An email was sent to #{user.email}, please access it to confirm your account."
         )
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end

  defp local_mail_adapter? do
    Application.get_env(:asset_monitoring_dash, AssetMonitoringDash.Mailer)[:adapter] ==
      Swoosh.Adapters.Local
  end

  defp input_class do
    "h-12 w-full rounded-app border border-app-border bg-app-bg px-3 text-sm font-semibold text-app-fg outline-none transition placeholder:text-app-muted focus:border-app-accent focus:ring-2 focus:ring-app-accent/20 disabled:cursor-not-allowed disabled:opacity-60"
  end
end
