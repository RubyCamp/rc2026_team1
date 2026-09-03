import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { threshold: Number }

  connect() {
    this.handleScroll = this.toggle.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
    this.toggle()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  toggle() {
    this.element.classList.toggle(
      "is-visible",
      window.scrollY >= this.thresholdValue
    )
  }

  scrollToTop() {
    window.scrollTo({ top: 0, behavior: "smooth" })
  }
}
