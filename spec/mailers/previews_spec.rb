require "rails_helper"

RSpec.describe "Mailer previews" do
  ActionMailer::Preview.all.sort_by(&:preview_name).each do |preview|
    describe preview.preview_name do
      it "cover every email of the mailer" do
        mailer = preview.preview_name.camelize.constantize

        expect(preview.emails).to match_array(mailer.action_methods.to_a)
      end

      it "render every email in text and HTML without touching the database" do
        emails = []

        queries = count_queries { emails = preview.emails.map { |email| preview.call(email) } }

        expect(emails).to all(satisfy { it.text_part.decoded.present? && it.html_part.decoded.present? })
        expect(queries).to eq(0)
      end
    end
  end
end
