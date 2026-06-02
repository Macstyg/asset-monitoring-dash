defmodule AssetMonitoringDashWeb.UserLive.Confirmation do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section
        id="confirmation-page"
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
                  Magic link
                </p>
                <h1 class="mt-5 font-display text-4xl font-semibold tracking-normal text-app-fg">
                  Confirm operator access
                </h1>
                <p class="mt-4 max-w-sm text-sm leading-6 text-app-muted">
                  Finish this one-time verification step before entering the cockpit and changing demo runtime state.
                </p>
              </div>

              <dl class="grid gap-3">
                <div class="rounded-app border border-app-border bg-app-surface/80 p-4">
                  <dt class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
                    Account
                  </dt>
                  <dd class="mt-2 break-words text-sm font-semibold text-app-fg">
                    {@user.email}
                  </dd>
                </div>
                <div class="rounded-app border border-app-border bg-app-surface/80 p-4">
                  <dt class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
                    Session choice
                  </dt>
                  <dd class="mt-2 text-sm font-semibold text-app-fg">
                    Stay signed in here, or keep this session temporary
                  </dd>
                </div>
              </dl>
            </div>
          </aside>

          <div class="bg-app-surface px-5 py-8 sm:px-8 lg:px-10 lg:py-10">
            <div class="mx-auto max-w-md">
              <div>
                <p class="font-mono text-xs font-semibold uppercase tracking-[0.22em] text-app-muted">
                  Verification
                </p>
                <h2 class="mt-3 font-display text-3xl font-semibold tracking-normal text-app-fg">
                  Confirm your access
                </h2>
                <p class="mt-3 break-words rounded-app border border-app-border bg-app-bg px-3 py-2 font-mono text-xs font-semibold text-app-muted">
                  {@user.email}
                </p>
                <p class="mt-3 text-sm leading-6 text-app-muted">
                  Choose how long this browser should keep access to the demo workspace.
                </p>
              </div>

              <.form
                :if={!@user.confirmed_at}
                for={@form}
                id="confirmation_form"
                phx-mounted={JS.focus_first()}
                phx-submit="submit"
                action={~p"/users/log-in?_action=confirmed"}
                phx-trigger-action={@trigger_submit}
                class="mt-8 grid gap-3"
              >
                <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
                <.button
                  name={@form[:remember_me].name}
                  value="true"
                  phx-disable-with="Confirming..."
                  class={primary_button_class()}
                >
                  Confirm and stay logged in
                </.button>
                <.button phx-disable-with="Confirming..." class={secondary_button_class()}>
                  Confirm and log in only this time
                </.button>
              </.form>

              <.form
                :if={@user.confirmed_at}
                for={@form}
                id="login_form"
                phx-submit="submit"
                phx-mounted={JS.focus_first()}
                action={~p"/users/log-in"}
                phx-trigger-action={@trigger_submit}
                class="mt-8 grid gap-3"
              >
                <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
                <%= if @current_scope do %>
                  <.button phx-disable-with="Logging in..." class={primary_button_class()}>
                    Log in
                  </.button>
                <% else %>
                  <.button
                    name={@form[:remember_me].name}
                    value="true"
                    phx-disable-with="Logging in..."
                    class={primary_button_class()}
                  >
                    Keep me logged in on this device
                  </.button>
                  <.button phx-disable-with="Logging in..." class={secondary_button_class()}>
                    Log me in only this time
                  </.button>
                <% end %>
              </.form>

              <div
                :if={!@user.confirmed_at}
                id="password-tip"
                class="mt-8 rounded-app border border-app-border bg-app-bg p-4 text-sm leading-6 text-app-muted"
              >
                <span class="font-semibold text-app-fg">Tip:</span>
                If you prefer passwords, you can enable them in the user settings.
              </div>
            </div>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end

  defp primary_button_class do
    "inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-app border border-app-primary-bg bg-app-primary-bg px-4 text-sm font-semibold text-app-primary-fg transition hover:brightness-110 focus:outline-none focus:ring-2 focus:ring-app-accent/30 disabled:cursor-not-allowed disabled:opacity-60"
  end

  defp secondary_button_class do
    "inline-flex min-h-11 w-full items-center justify-center rounded-app border border-app-border bg-app-surface-2 px-4 text-sm font-semibold text-app-fg transition hover:border-app-accent/40 hover:bg-app-bg focus:outline-none focus:ring-2 focus:ring-app-accent/20 disabled:cursor-not-allowed disabled:opacity-60"
  end
end
