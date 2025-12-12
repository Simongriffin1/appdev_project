class AddReceivedAtToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :journal_entries, :received_at, :datetime
  end
end
