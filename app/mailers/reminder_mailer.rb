class ReminderMailer < ApplicationMailer
  def reminder
    @reminder = params[:reminder]
    @borrowing = @reminder.borrowing
    @book = @borrowing.book
    @reader = @borrowing.reader

    mail to: @reader.email, subject: subject
  end

  private

  def subject
    if @reminder.due_today?
      "\"#{@book.title}\" is due back today"
    else
      "\"#{@book.title}\" is due back in #{Reminder::DAYS_BEFORE_DUE['upcoming']} days"
    end
  end
end
