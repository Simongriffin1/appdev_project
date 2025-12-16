class AddMessageIdHashToJournalEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :journal_entries, :message_id_hash, :string
    add_index :journal_entries, :message_id_hash, unique: true, where: "message_id_hash IS NOT NULL"
  end
end
