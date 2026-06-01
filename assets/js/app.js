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
import * as echarts from "echarts/core"
import {BarChart, LineChart, PieChart} from "echarts/charts"
import {GridComponent, LegendComponent, TooltipComponent} from "echarts/components"
import {CanvasRenderer} from "echarts/renderers"
import topbar from "../vendor/topbar"

echarts.use([
  BarChart,
  LineChart,
  PieChart,
  GridComponent,
  LegendComponent,
  TooltipComponent,
  CanvasRenderer,
])

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
      this.setLoadingMore(true)
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
    this.setLoadingMore(false)
  },

  destroyed() {
    this.el.removeEventListener("scroll", this.handleScroll)
    this.setLoadingMore(false)
  },

  distanceFromBottom() {
    return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight
  },

  setLoadingMore(isLoading) {
    const targetId = this.el.dataset.loadMoreTarget

    if (!targetId) {
      return
    }

    const target = document.getElementById(targetId)

    if (!target) {
      return
    }

    target.classList.toggle("hidden", !isLoading)
    target.setAttribute("aria-hidden", isLoading ? "false" : "true")
    this.el.setAttribute("aria-busy", isLoading ? "true" : "false")
  },
}

const CopyCurrentUrl = {
  mounted() {
    this.label = this.el.querySelector("[data-copy-label]")
    this.defaultLabel = this.label?.textContent || "Copy view link"

    this.handleClick = async () => {
      try {
        await navigator.clipboard.writeText(window.location.href)
        this.setStatus("Copied")
      } catch (_error) {
        this.setStatus("Copy failed")
      }
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
    clearTimeout(this.resetTimer)
  },

  setStatus(label) {
    if (!this.label) {
      return
    }

    this.label.textContent = label
    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.label.textContent = this.defaultLabel
    }, 1800)
  },
}

const EChart = {
  mounted() {
    this.chart = echarts.init(this.el, null, {renderer: "canvas"})
    this.option = null
    this.formatter = params => this.formatTooltip(params)
    this.positioner = (point, params, dom, rect, size) =>
      this.positionTooltip(point, params, dom, rect, size)

    this.resizeObserver = new ResizeObserver(() => {
      this.chart.resize()
    })
    this.resizeObserver.observe(this.el)

    this.themeObserver = new MutationObserver(() => {
      this.applyOption(this.option || this.readOption())
    })
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    })

    this.handleEvent("chart:update", ({id, option}) => {
      if (id === this.el.id) {
        this.applyOption(option)
      }
    })

    this.applyOption(this.readOption())
  },

  updated() {
    this.applyOption(this.readOption())
  },

  destroyed() {
    this.resizeObserver?.disconnect()
    this.themeObserver?.disconnect()
    this.chart?.dispose()
  },

  readOption() {
    const encodedOption = this.el.dataset.chartOption

    if (!encodedOption) {
      return null
    }

    try {
      return JSON.parse(encodedOption)
    } catch (error) {
      console.warn("Invalid EChart option", error)
      return null
    }
  },

  applyOption(option) {
    if (!option) {
      return
    }

    this.option = option
    this.el.dataset.chartSeries = JSON.stringify(option.series || [])
    this.chart.setOption(this.resolveThemeValues(this.withFormatters(option)), {
      lazyUpdate: false,
      notMerge: false,
    })
  },

  withFormatters(option) {
    return {
      ...option,
      tooltip: {
        ...option.tooltip,
        formatter: this.formatter,
        position: this.positioner,
      },
    }
  },

  positionTooltip(point, params, _dom, _rect, size) {
    const offset = 12
    const tooltipWidth = size.contentSize[0]
    const tooltipHeight = size.contentSize[1]
    const viewWidth = size.viewSize[0]
    const viewHeight = size.viewSize[1]
    const dataIndex = this.tooltipDataIndex(params)
    const columnX = this.columnX(dataIndex) || point[0]
    const columnWidth = this.columnWidth() || 0
    const rightEdge = columnX + columnWidth / 2
    const leftEdge = columnX - columnWidth / 2

    const rightX = rightEdge + offset
    const leftX = leftEdge - tooltipWidth - offset
    const x = rightX + tooltipWidth <= viewWidth ? rightX : Math.max(offset, leftX)
    const headerY = this.gridTop() - tooltipHeight - offset
    const centeredY = point[1] - tooltipHeight / 2
    const preferredY = headerY >= offset ? headerY : centeredY
    const y = Math.min(Math.max(offset, preferredY), viewHeight - tooltipHeight - offset)

    return [x, y]
  },

  gridTop() {
    const top = this.option?.grid?.top

    if (typeof top === "number") {
      return top
    }

    if (typeof top === "string") {
      return Number.parseFloat(top)
    }

    return 0
  },

  tooltipDataIndex(params) {
    const point = Array.isArray(params) ? params[0] : params

    return Number.isInteger(point?.dataIndex) ? point.dataIndex : null
  },

  columnX(dataIndex) {
    if (!Number.isInteger(dataIndex) || !this.option?.xAxis?.data) {
      return null
    }

    const point = this.chart.convertToPixel({xAxisIndex: 0}, dataIndex)

    return Array.isArray(point) ? point[0] : point
  },

  columnWidth() {
    const xAxisData = this.option?.xAxis?.data || []

    if (xAxisData.length < 2) {
      return 0
    }

    const first = this.chart.convertToPixel({xAxisIndex: 0}, 0)
    const second = this.chart.convertToPixel({xAxisIndex: 0}, 1)
    const firstX = Array.isArray(first) ? first[0] : first
    const secondX = Array.isArray(second) ? second[0] : second

    return Math.abs(secondX - firstX) * 0.7
  },

  formatTooltip(params) {
    const points = Array.isArray(params) ? params : [params]
    const visiblePoints = points.filter(point => Number(point.value || 0) > 0)

    if (visiblePoints.length === 0) {
      return ""
    }

    const title = points[0]?.axisValueLabel || points[0]?.name || ""
    const rows = visiblePoints
      .map(point => `
        <div style="display:flex;align-items:center;gap:0.5rem;justify-content:space-between;min-width:9rem;">
          <span style="display:inline-flex;align-items:center;gap:0.5rem;">
            <span style="display:inline-block;width:0.55rem;height:0.55rem;border-radius:999px;background:${point.color};"></span>
            <span>${point.seriesName}</span>
          </span>
          <strong style="font-family:var(--amd-font-mono);">${this.tooltipValue(point)}</strong>
        </div>
      `)
      .join("")

    return `
      <div style="font-family:var(--amd-font-body);">
        <div style="margin-bottom:0.45rem;font-family:var(--amd-font-mono);font-size:0.75rem;font-weight:700;color:var(--amd-muted);">${title}</div>
        <div style="display:grid;gap:0.35rem;">${rows}</div>
      </div>
    `
  },

  tooltipValue(point) {
    return point.data?.tooltipValue || point.value
  },

  resolveThemeValues(value) {
    if (Array.isArray(value)) {
      return value.map(item => this.resolveThemeValues(item))
    }

    if (value && typeof value === "object") {
      return Object.fromEntries(
        Object.entries(value).map(([key, nestedValue]) => [
          key,
          this.resolveThemeValues(nestedValue),
        ])
      )
    }

    if (typeof value === "string" && value.startsWith("css:")) {
      return getComputedStyle(document.documentElement)
        .getPropertyValue(value.slice(4))
        .trim()
    }

    return value
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, CopyCurrentUrl, EChart, FilterDropdown, ScrollableLoadMore},
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
