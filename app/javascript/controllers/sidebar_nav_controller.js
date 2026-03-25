import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { saveUrl: String }

  connect() {
    this._onToggle = () => this.scheduleSave()
    this.element.addEventListener("toggle", this._onToggle, true)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this._onToggle, true)
    clearTimeout(this._timer)
  }

  scheduleSave() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.save(), 280)
  }

  async save() {
    const phases = []
    const years = []
    const subjects = []
    const units = []

    this.element.querySelectorAll("details[data-sidebar-nav-phase]").forEach((el) => {
      if (el.open) phases.push(el.dataset.phaseKey)
    })
    this.element.querySelectorAll("details[data-sidebar-nav-year]").forEach((el) => {
      if (el.open) years.push(el.dataset.yearKey)
    })
    this.element.querySelectorAll("details[data-sidebar-nav-subject]").forEach((el) => {
      if (el.open) subjects.push(el.dataset.subjectKey)
    })
    this.element.querySelectorAll("details[data-sidebar-nav-unit]").forEach((el) => {
      if (el.open) units.push(el.dataset.unitKey)
    })

    const token = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    if (!token) return

    try {
      await fetch(this.saveUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": token
        },
        body: JSON.stringify({ sidebar_expanded: { phases, years, subjects, units } })
      })
    } catch (_) {
      /* ignore */
    }
  }
}
