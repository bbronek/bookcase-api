module KeysetPagination
  DEFAULT_PAGE_SIZE = 50
  PAGE_SIZES = 1..100
  POSITIVE_INTEGER = /\A[1-9]\d*\z/
  CURSOR_FORMAT = ApplicationRecord::SIX_DIGITS

  private

  def page_params
    after = query_parameter(:after).presence
    raise ActionController::BadRequest, "after is not a valid cursor" if after && !after.match?(CURSOR_FORMAT)

    { after:, limit: page_size }
  end

  def page_size
    size = query_parameter(:limit)
    return DEFAULT_PAGE_SIZE if size.nil?
    return size.to_i if size.match?(POSITIVE_INTEGER) && PAGE_SIZES.cover?(size.to_i)

    raise ActionController::BadRequest, "limit must be an integer between #{PAGE_SIZES.min} and #{PAGE_SIZES.max}"
  end

  def render_page(page, with:)
    if page.next_cursor
      next_page = request.query_parameters.merge("after" => page.next_cursor).to_query
      response.set_header("Link", %(<#{request.path}?#{next_page}>; rel="next"))
    end
    render json: Panko::ArraySerializer.new(page.records, each_serializer: with).to_json
  end
end
