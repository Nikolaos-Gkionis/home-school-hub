import { Controller } from "@hotwired/stimulus"

// Sends study seconds to the server on an interval while a lesson is open.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 45 } }

  connect() {
    this.boundFlush = () => this.flush(this.intervalValue)
    this.timer = window.setInterval(this.boundFlush, this.intervalValue * 1000)
  }

  disconnect() {
    if (this.timer) window.clearInterval(this.timer)
  }

  flush(seconds) {
    if (!this.urlValue || seconds <= 0) return
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token || ""
      },
      body: new URLSearchParams({ seconds: String(seconds) }),
      credentials: "same-origin"
    }).catch(() => {})
  }
}
