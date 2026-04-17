class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM", "no-reply@homeschoolhub.local")
  layout "mailer"
end
