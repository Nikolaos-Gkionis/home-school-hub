import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._onChange = (event) => {
      const target = event.target
      if (target instanceof HTMLInputElement && target.name === "preferred_subjects[]") {
        this.scheduleSave()
      }
    }

    this.element.addEventListener("change", this._onChange)
  }

  disconnect() {
    this.element.removeEventListener("change", this._onChange)
    clearTimeout(this._timer)
  }

  scheduleSave() {
    clearTimeout(this._timer)
    this._timer = setTimeout(() => this.save(), 250)
  }

  async save() {
    const token = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    if (!token) return

    const body = new URLSearchParams(new FormData(this.element))

    try {
      await fetch(this.element.action, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
          "X-CSRF-Token": token
        },
        body: body.toString()
      })
    } catch (_) {
      // Keep UI responsive even if save fails; user can still click the Save button.
    }
  }
}
