class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV["MAIL_FROM"] || "emailjournaler@gmail.com" }
  layout "mailer"
end
