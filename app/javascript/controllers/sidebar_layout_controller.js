import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "hub.sidebarCollapsed"
const MOBILE_MAX = 767

// Desktop: persist collapsed width. Phone: overlay drawer behind a hamburger.
export default class extends Controller {
  static targets = ["panel", "backdrop", "menuButton"]

  connect() {
    this.collapsed = window.localStorage.getItem(STORAGE_KEY) === "1"
    this.mobileOpen = false
    this._sync()
  }

  toggle() {
    this.collapsed = !this.collapsed
    window.localStorage.setItem(STORAGE_KEY, this.collapsed ? "1" : "0")
    this._sync()
  }

  toggleMobile() {
    this.mobileOpen = !this.mobileOpen
    this._sync()
  }

  closeMobile() {
    if (!this.mobileOpen) return
    this.mobileOpen = false
    this._sync()
  }

  closeMobileOnNavigate(event) {
    if (window.innerWidth > MOBILE_MAX) return
    if (event.target.closest("a, button[type=submit]")) {
      this.closeMobile()
    }
  }

  _sync() {
    if (this.hasPanelTarget) {
      this.panelTarget.dataset.collapsed = this.collapsed ? "true" : "false"
      this.panelTarget.dataset.mobileOpen = this.mobileOpen ? "true" : "false"
      const btn = this.panelTarget.querySelector(".sidebar-toggle")
      if (btn) {
        btn.setAttribute("aria-expanded", this.collapsed ? "false" : "true")
        btn.setAttribute(
          "title",
          this.collapsed ? "Expand sidebar" : "Collapse sidebar"
        )
      }
    }

    if (this.hasBackdropTarget) {
      this.backdropTarget.dataset.open = this.mobileOpen ? "true" : "false"
    }

    if (this.hasMenuButtonTarget) {
      this.menuButtonTarget.setAttribute("aria-expanded", this.mobileOpen ? "true" : "false")
    }
  }
}
