class ReadersController < ApplicationController
  def index
    @readers = Reader.order(:card_number)
  end

  def create
    @reader = Reader.create!(reader_params)
    render :show, status: :created
  end

  private

  def reader_params
    params.expect(reader: %i[ card_number full_name email ])
  end
end
