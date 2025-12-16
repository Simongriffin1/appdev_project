class UpdateUsersForDabbleSchema < ActiveRecord::Migration[8.0]
  def up
    # Add new fields
    add_column :users, :onboarding_complete, :boolean, default: false, null: false
    add_column :users, :schedule_frequency, :string
    add_column :users, :schedule_time, :time
    add_column :users, :last_prompt_sent_at, :datetime
    add_column :users, :streak_count, :integer, default: 0, null: false
    add_column :users, :last_entry_at, :datetime

    # Migrate existing data: copy prompt_frequency to schedule_frequency
    execute <<-SQL
      UPDATE users
      SET schedule_frequency = prompt_frequency
      WHERE prompt_frequency IS NOT NULL
    SQL

    # Migrate send_times to schedule_time (take first time if multiple)
    execute <<-SQL
      UPDATE users
      SET schedule_time = (
        SELECT TIME(
          '2000-01-01 ' ||
          TRIM(SPLIT_PART(send_times, ',', 1)) ||
          ':00'
        )
      )
      WHERE send_times IS NOT NULL AND send_times != ''
    SQL

    # Set onboarding_complete based on existing logic
    execute <<-SQL
      UPDATE users
      SET onboarding_complete = (
        time_zone IS NOT NULL AND
        prompt_frequency IS NOT NULL AND
        send_times IS NOT NULL
      )
    SQL

    # Calculate initial streak_count from existing entries
    execute <<-SQL
      UPDATE users
      SET streak_count = (
        SELECT COUNT(DISTINCT DATE(received_at))
        FROM journal_entries
        WHERE journal_entries.user_id = users.id
          AND received_at >= CURRENT_DATE - INTERVAL '30 days'
          AND received_at IS NOT NULL
      )
    SQL

    # Set last_entry_at from most recent entry
    execute <<-SQL
      UPDATE users
      SET last_entry_at = (
        SELECT MAX(received_at)
        FROM journal_entries
        WHERE journal_entries.user_id = users.id
      )
    SQL
  end

  def down
    remove_column :users, :onboarding_complete
    remove_column :users, :schedule_frequency
    remove_column :users, :schedule_time
    remove_column :users, :last_prompt_sent_at
    remove_column :users, :streak_count
    remove_column :users, :last_entry_at
  end
end
