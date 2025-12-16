class UpdateJournalEntriesForDabbleSchema < ActiveRecord::Migration[8.0]
  def up
    # Add new fields
    add_column :journal_entries, :word_count, :integer
    add_column :journal_entries, :cleaned_body, :text

    # Calculate word_count from existing body
    execute <<-SQL
      UPDATE journal_entries
      SET word_count = (
        SELECT array_length(string_to_array(TRIM(body), ' '), 1)
        WHERE body IS NOT NULL AND body != ''
      )
    SQL

    # Set cleaned_body to body initially (will be updated by EmailSanitizer going forward)
    execute <<-SQL
      UPDATE journal_entries
      SET cleaned_body = body
      WHERE body IS NOT NULL
    SQL

    # Add index on [user_id, received_at] for efficient queries
    add_index :journal_entries, [:user_id, :received_at], name: "index_journal_entries_on_user_id_and_received_at"
  end

  def down
    remove_index :journal_entries, name: "index_journal_entries_on_user_id_and_received_at"
    remove_column :journal_entries, :word_count
    remove_column :journal_entries, :cleaned_body
  end
end
