require "net/smtp"

class ApplicationMailer < ActionMailer::Base
  TEMPORARY_FAILURES = [
    Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy,
    Errno::ECONNREFUSED, Errno::ECONNRESET, IOError, SocketError
  ].freeze

  layout "mailer"
end
