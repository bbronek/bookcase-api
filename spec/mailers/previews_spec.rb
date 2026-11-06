require "rails_helper"

RSpec.describe "Mailer previews" do
  it "preview every reminder email in text and HTML" do
    preview = ReminderMailerPreview

    expect(preview.emails).to match_array(ReminderMailer.action_methods.to_a)
    expect(preview.emails.map { preview.call(it) }).to all(satisfy { it.text_part.decoded.present? && it.html_part.decoded.present? })
  end
end
