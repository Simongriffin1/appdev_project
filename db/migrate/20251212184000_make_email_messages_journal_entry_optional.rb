class MakeEmailMessagesJournalEntryOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :email_messages, :journal_entry_id, true
  end
end
