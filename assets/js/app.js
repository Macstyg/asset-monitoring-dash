// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/asset_monitoring_dash"
import topbar from "../vendor/topbar"

const FilterDropdown = {
  mounted() {
    this.wasOpen = false

    this.handleToggle = () => {
      if (this.el.open) {
        this.closeOtherDropdowns()
      }
    }

    this.handleDocumentClick = event => {
      if (this.el.open && !this.el.contains(event.target)) {
        this.el.open = false
      }
    }

    this.handleKeyDown = event => {
      if (event.key === "Escape" && this.el.open) {
        event.preventDefault()
        this.el.open = false
        this.el.querySelector("summary")?.focus()
      }

      if (event.target.closest("[data-filter-dropdown-search]")) {
        event.stopPropagation()
      }
    }

    this.el.addEventListener("toggle", this.handleToggle)
    this.el.addEventListener("keydown", this.handleKeyDown)
    document.addEventListener("click", this.handleDocumentClick)
  },

  beforeUpdate() {
    this.wasOpen = this.el.open || this.el.contains(document.activeElement)
  },

  updated() {
    if (this.wasOpen) {
      this.el.open = true
      this.closeOtherDropdowns()
    }
  },

  destroyed() {
    this.el.removeEventListener("toggle", this.handleToggle)
    this.el.removeEventListener("keydown", this.handleKeyDown)
    document.removeEventListener("click", this.handleDocumentClick)
  },

  closeOtherDropdowns() {
    document.querySelectorAll("[data-filter-dropdown][open]").forEach(dropdown => {
      if (dropdown !== this.el) {
        dropdown.open = false
      }
    })
  },
}

const ScrollableLoadMore = {
  mounted() {
    this.pending = false
    this.thresholdPx = 160

    this.handleScroll = () => {
      if (this.pending) {
        return
      }

      const loadMoreEvent = this.el.dataset.loadMoreEvent

      if (!loadMoreEvent || this.distanceFromBottom() > this.thresholdPx) {
        return
      }

      this.pending = true
      this.pushEvent(loadMoreEvent, {})

      setTimeout(() => {
        this.pending = false
      }, 500)
    }

    this.el.addEventListener("scroll", this.handleScroll, {passive: true})
    requestAnimationFrame(this.handleScroll)
  },

  updated() {
    this.pending = false
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.handleScroll)
  },

  distanceFromBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, FilterDropdown, ScrollableLoadMore},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
