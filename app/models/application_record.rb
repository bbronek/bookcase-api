class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  SIX_DIGITS = /\A\d{6}\z/
  SIX_DIGITS_FORMAT = { with: SIX_DIGITS, message: :six_digits, allow_blank: true }.freeze
  SURROUNDING_WHITESPACE = /\A[[:space:]]+|[[:space:]]+\z/
  VISIBLE_TEXT = /\A[^[:cntrl:]]*[\p{L}\p{N}\p{P}\p{S}][^[:cntrl:]]*\z/
  PLAIN_TEXT_FORMAT = { with: VISIBLE_TEXT, message: :plain_text, allow_blank: true }.freeze
end
