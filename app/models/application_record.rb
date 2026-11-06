class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  SIX_DIGITS = /\A\d{6}\z/
  SIX_DIGITS_FORMAT = { with: SIX_DIGITS, message: :six_digits, allow_blank: true }.freeze
  INVISIBLE_OR_SPOOFING = /[[:cntrl:]\u200B\u2060\uFEFF\u202A-\u202E\u2066-\u2069]/
  PLAIN_TEXT_FORMAT = { without: INVISIBLE_OR_SPOOFING, message: :plain_text }.freeze
  NORMALIZE_TEXT = ->(text) { text.unicode_normalize(:nfc).squish }
end
