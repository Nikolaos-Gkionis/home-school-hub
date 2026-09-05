import { Controller } from "@hotwired/stimulus"

// HTML5 drag-and-drop for lesson blocks on the weekly calendar.
// Breaks and lunch are not drop targets — only teaching slots swap.
export default class extends Controller {
  static values = {
    swapUrl: String,
    month: Number,
    week: String,
    childId: String
  }

  dragstart(event) {
    const block = event.currentTarget
    if (!block.dataset.date || !block.dataset.period) return

    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", `${block.dataset.date}|${block.dataset.period}`)
    block.classList.add("is-dragging")
    this._source = block
  }

  dragend(event) {
    event.currentTarget.classList.remove("is-dragging")
    this.element.querySelectorAll(".is-drop-target").forEach((el) => el.classList.remove("is-drop-target"))
    this._source = null
  }

  dragover(event) {
    const slot = this.droppableSlot(event.currentTarget)
    if (!slot || slot === this._source) return

    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    slot.classList.add("is-drop-target")
  }

  dragleave(event) {
    event.currentTarget.classList.remove("is-drop-target")
  }

  async drop(event) {
    event.preventDefault()
    const slot = this.droppableSlot(event.currentTarget)
    this.element.querySelectorAll(".is-drop-target").forEach((el) => el.classList.remove("is-drop-target"))
    if (!slot || !this._source) return

    const fromDate = this._source.dataset.date
    const fromPeriod = this._source.dataset.period
    const toDate = slot.dataset.date
    const toPeriod = slot.dataset.period
    if (!toDate || !toPeriod) return
    if (fromDate === toDate && fromPeriod === toPeriod) return

    const body = new URLSearchParams({
      from_date: fromDate,
      from_period: fromPeriod,
      to_date: toDate,
      to_period: toPeriod,
      month: String(this.monthValue),
      week: this.weekValue
    })
    if (this.hasChildIdValue && this.childIdValue) body.append("child_id", this.childIdValue)

    const token = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    const response = await fetch(this.swapUrlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token,
        Accept: "text/html",
        "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"
      },
      body,
      redirect: "follow"
    })

    if (response.redirected) {
      window.Turbo.visit(response.url)
    } else if (response.ok) {
      window.location.reload()
    }
  }

  droppableSlot(element) {
    if (element.dataset.droppable === "true") return element
    return null
  }

  print(event) {
    event.preventDefault()
    window.print()
  }
}
