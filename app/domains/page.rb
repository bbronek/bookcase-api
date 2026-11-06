Page = Data.define(:records, :next_cursor) do
  def self.of(scope, ordered_by:, after:, limit:)
    scope = scope.order(ordered_by)
    scope = scope.where(scope.model.arel_table[ordered_by].gt(after)) if after
    rows = scope.limit(limit + 1).to_a
    records = rows.first(limit)
    new(records:, next_cursor: rows.size > limit ? records.last.public_send(ordered_by) : nil)
  end
end
