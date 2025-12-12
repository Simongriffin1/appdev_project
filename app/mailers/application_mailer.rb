class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "noreply@inboxjournal.com")
  layout "mailer"
end
