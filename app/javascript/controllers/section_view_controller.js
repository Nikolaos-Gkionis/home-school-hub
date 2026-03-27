import { Controller } from "@hotwired/stimulus"

// Records that a learner reached a lesson section (first-party progress for Oak hub lessons).
export default class extends Controller {
  static values = { url: String }

  connect() {
    if (this.done) return
    this.done = true

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": token || "",
        Accept: "application/json"
      },
      credentials: "same-origin"
    }).catch(() => {})
  }
}
