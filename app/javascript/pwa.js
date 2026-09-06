// Ask the browser to install our service worker once the page has loaded.
// That is what lets phones show "Add to Home Screen" / "Install app".
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((error) => {
      console.warn("Service worker registration failed", error)
    })
  })
}
