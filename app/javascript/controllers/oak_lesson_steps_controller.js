import { Controller } from "@hotwired/stimulus"

// Swaps between Oak-style "lesson overview" (4-step cards) and each step's content.
export default class extends Controller {
  static targets = ["overview", "panel", "scrollRoot"]

  connect() {
    this.showOverview()
  }

  showOverview(event) {
    event?.preventDefault()
    this.overviewTarget.classList.remove("hidden")
    this.panelTargets.forEach((el) => el.classList.add("hidden"))
    this.#scrollTop()
  }

  open(event) {
    const el = event.currentTarget
    const step = el.dataset.step
    if (!step || el.getAttribute("aria-disabled") === "true") return

    const hasPanel = this.panelTargets.some((panel) => panel.dataset.step === step)
    if (!hasPanel) return

    this.overviewTarget.classList.add("hidden")
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.step !== step)
    })
    this.#scrollTop()
  }

  #scrollTop() {
    const node = this.hasScrollRootTarget ? this.scrollRootTarget : this.element
    node.scrollTop = 0
  }
}
