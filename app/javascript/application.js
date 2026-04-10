// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { installTurboConfirm } from "turbo_confirm"
import "controllers"

installTurboConfirm()
document.addEventListener("turbo:load", installTurboConfirm)
