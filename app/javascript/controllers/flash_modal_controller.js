import { Controller } from "@hotwired/stimulus"

// Dismissible overlay for flash notice / alert (replaces fixed corner toasts).
export default class extends Controller {
  connect() {
    this._onEscape = (e) => {
      if (e.key === "Escape") this.dismiss()
    }
    document.addEventListener("keydown", this._onEscape)
    queueMicrotask(() => {
      this.element.querySelector("[data-flash-modal-primary]")?.focus()
    })
  }

  disconnect() {
    document.removeEventListener("keydown", this._onEscape)
  }

  closeOnBackdrop(event) {
    if (event.target === this.element) this.dismiss()
  }

  dismiss() {
    this.element.remove()
  }
}
