class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  SIX_DIGITS = /\A\d{6}\z/
  SIX_DIGITS_FORMAT = { with: SIX_DIGITS, message: :six_digits, allow_blank: true }.freeze
  PLAIN_TEXT_FORMAT = { without: /[[:cntrl:]]/, message: :plain_text }.freeze
  NORMALIZE_TEXT = ->(text) { text.strip }
end
