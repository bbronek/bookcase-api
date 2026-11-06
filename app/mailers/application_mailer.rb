require "net/smtp"

class ApplicationMailer < ActionMailer::Base
  TEMPORARY_FAILURES = [
    Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy,
    Errno::ECONNREFUSED, Errno::ECONNRESET, IOError, SocketError
  ].freeze
  UNKNOWN_RECIPIENT_REPLY = /\A5\d\d[ -]5\.1\.(?:1|2|3|6|10)\b/

  layout "mailer"

  def self.unknown_recipient?(error) = error.is_a?(Net::SMTPFatalError) && error.message.match?(UNKNOWN_RECIPIENT_REPLY)
end
