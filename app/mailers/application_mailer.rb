class ApplicationMailer < ActionMailer::Base
  # Lazy: MAILER_FROM should match a verified sender (Brevo) or SMTP account.
  default from: -> { ENV["MAILER_FROM"].to_s.strip.presence || "elefsinian@gmail.com" }
  layout "mailer"
end
