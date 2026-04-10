import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "hub.sidebarCollapsed"

// Persists collapsed state in localStorage; sets data-collapsed on the nav for CSS hooks.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.collapsed = window.localStorage.getItem(STORAGE_KEY) === "1"
    this._sync()
  }

  toggle() {
    this.collapsed = !this.collapsed
    window.localStorage.setItem(STORAGE_KEY, this.collapsed ? "1" : "0")
    this._sync()
  }

  _sync() {
    this.panelTarget.dataset.collapsed = this.collapsed ? "true" : "false"
    const btn = this.panelTarget.querySelector(".sidebar-toggle")
    if (btn) {
      btn.setAttribute("aria-expanded", this.collapsed ? "false" : "true")
      btn.setAttribute(
        "title",
        this.collapsed ? "Expand sidebar" : "Collapse sidebar"
      )
    }
  }
}
