defmodule AssetMonitoringDashWeb.UserLive.Settings do
  use AssetMonitoringDashWeb, :live_view

  on_mount {AssetMonitoringDashWeb.UserAuth, :require_sudo_mode}

  alias AssetMonitoringDash.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section
        id="account-settings-page"
        class="mx-auto flex min-h-[calc(100vh-4rem)] w-full max-w-6xl flex-col gap-8 px-4 py-8 sm:px-6 lg:px-8"
      >
        <div class="flex flex-col gap-4 border-b border-app-border pb-6 lg:flex-row lg:items-end lg:justify-between">
          <div class="max-w-3xl">
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.22em] text-app-muted">
              Operator profile
            </p>
            <h1 class="mt-3 font-display text-3xl font-semibold tracking-normal text-app-fg sm:text-4xl">
              Account Settings
            </h1>
            <p class="mt-3 max-w-2xl text-sm leading-6 text-app-muted">
              Manage your account email address and password settings for private demo access.
            </p>
          </div>

          <div
            id="settings-current-user"
            class="rounded-app border border-app-border bg-app-surface px-4 py-3 text-sm shadow-app-panel"
          >
            <p class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
              Signed in as
            </p>
            <p class="mt-1 max-w-sm truncate font-semibold text-app-fg">
              {@current_email}
            </p>
          </div>
        </div>

        <div class="grid gap-5 lg:grid-cols-2">
          <section class="rounded-app border border-app-border bg-app-surface p-5 shadow-app-panel sm:p-6">
            <div class="mb-6">
              <h2 class="font-display text-xl font-semibold tracking-normal text-app-fg">
                Change Email
              </h2>
              <p class="mt-2 text-sm leading-6 text-app-muted">
                We will send a confirmation link before replacing the current address.
              </p>
            </div>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                spellcheck="false"
                required
                class={input_class()}
              />
              <.button phx-disable-with="Changing..." class={primary_button_class()}>
                Change Email
              </.button>
            </.form>
          </section>

          <section class="rounded-app border border-app-border bg-app-surface p-5 shadow-app-panel sm:p-6">
            <div class="mb-6">
              <h2 class="font-display text-xl font-semibold tracking-normal text-app-fg">
                Save Password
              </h2>
              <p class="mt-2 text-sm leading-6 text-app-muted">
                Add or update a password for reauthentication and local demo access.
              </p>
            </div>

            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                spellcheck="false"
                value={@current_email}
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label="New password"
                autocomplete="new-password"
                spellcheck="false"
                required
                class={input_class()}
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
                autocomplete="new-password"
                spellcheck="false"
                class={input_class()}
              />
              <.button phx-disable-with="Saving..." class={primary_button_class()}>
                Save Password
              </.button>
            </.form>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  defp input_class do
    "h-12 w-full rounded-app border border-app-border bg-app-bg px-3 text-sm font-semibold text-app-fg outline-none transition placeholder:text-app-muted focus:border-app-accent focus:ring-2 focus:ring-app-accent/20 disabled:cursor-not-allowed disabled:opacity-60"
  end

  defp primary_button_class do
    "mt-4 inline-flex min-h-11 items-center justify-center gap-2 rounded-app border border-app-primary-bg bg-app-primary-bg px-4 text-sm font-semibold text-app-primary-fg transition hover:brightness-110 focus:outline-none focus:ring-2 focus:ring-app-accent/30 disabled:cursor-not-allowed disabled:opacity-60"
  end
end
