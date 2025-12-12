class MakeJournalEntriesPromptNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :journal_entries, :prompt_id, true
  end
end
