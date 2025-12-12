class UpdateJournalEntriesSourceDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :journal_entries, :source, "email"
  end
end
