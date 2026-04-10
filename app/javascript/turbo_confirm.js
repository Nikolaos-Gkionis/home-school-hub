// Replace window.confirm for data-turbo-confirm with the themed <dialog> in the layout.
export function installTurboConfirm() {
  const Turbo = window.Turbo
  if (!Turbo || typeof Turbo.setConfirmMethod !== "function") return

  Turbo.setConfirmMethod((message) => {
    const dialog = document.getElementById("hub-confirm-dialog")
    const msgEl = dialog?.querySelector("[data-hub-confirm-message]")
    const btnCancel = dialog?.querySelector("[data-hub-confirm-cancel]")
    const btnOk = dialog?.querySelector("[data-hub-confirm-ok]")
    if (!dialog || !msgEl || !btnCancel || !btnOk) {
      return Promise.resolve(window.confirm(message))
    }

    return new Promise((resolve) => {
      msgEl.textContent = message

      let settled = false
      const finish = (ok) => {
        if (settled) return
        settled = true
        if (dialog.open) dialog.close()
        resolve(ok)
      }

      const onOk = () => finish(true)
      const onCancel = () => finish(false)
      const onEscape = (e) => {
        e.preventDefault()
        finish(false)
      }

      btnOk.addEventListener("click", onOk, { once: true })
      btnCancel.addEventListener("click", onCancel, { once: true })
      dialog.addEventListener("cancel", onEscape, { once: true })

      dialog.showModal()
    })
  })
}
