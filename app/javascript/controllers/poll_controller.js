import { Controller } from "@hotwired/stimulus"

// While background work is pending, re-fetches the page and swaps in only the
// surrounding <turbo-frame>, so the rest of the page (and any form being
// typed in) is left alone. Frames carry no src until polling starts, so
// nothing is fetched when nothing is pending.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 1500 } }

  connect() {
    this.timer = setTimeout(() => {
      const frame = this.element.closest("turbo-frame")
      if (!frame) return
      if (frame.getAttribute("src")) frame.reload()
      else frame.src = this.urlValue
    }, this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
