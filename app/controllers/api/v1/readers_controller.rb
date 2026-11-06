module Api
  module V1
    class ReadersController < BaseController
      include KeysetPagination

      def index
        page = Membership::ReadersQuery.call(**page_params)
        render_page page, with: ReaderSerializer
      end

      def show
        reader = Reader.find_by!(card_number: path_parameter(:card_number))
        render_resource reader, with: ReaderSerializer
      end

      def create
        reader = Membership::RegisterReader.call(**body_attributes(:card_number, :full_name, :email))
        render_created_or_existing reader, with: ReaderSerializer, location: api_v1_reader_path(reader)
      end
    end
  end
end
