class ReminderMailer < ApplicationMailer
  before_action do
    @borrowing = params.fetch(:borrowing)
    @book = @borrowing.book
    @reader = @borrowing.reader
  end

  def due_soon
    due_on = I18n.l(@borrowing.due_on, format: :long)
    mail to: @reader.email, subject: default_i18n_subject(title: @book.title, due_on:)
  end

  def due_today
    mail to: @reader.email, subject: default_i18n_subject(title: @book.title)
  end
end
