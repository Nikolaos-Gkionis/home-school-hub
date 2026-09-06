# Pin npm packages by running ./bin/importmap

pin "application"
pin "pwa"
pin "turbo_confirm", to: "turbo_confirm.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# Self-contained ESM bundle (jspm’s chart.js had broken relative imports in production).
pin "chart.js", to: "chart.bundle.js"
