class ApplicationMailer < ActionMailer::Base
  # Lazy: MAILER_FROM must be non-blank in production (Kamal env). Blank would confuse Gmail SMTP.
  default from: -> { ENV["MAILER_FROM"].to_s.strip.presence || "elefsinian@gmail.com" }
  layout "mailer"
end
