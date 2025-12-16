class UpdatePromptsForDabbleSchema < ActiveRecord::Migration[8.0]
  def up
    # Add new fields
    add_column :prompts, :subject, :string
    add_column :prompts, :status, :string, default: "draft", null: false
    add_column :prompts, :replied_at, :datetime
    add_column :prompts, :follow_up_sent_at, :datetime
    add_column :prompts, :prompt_type, :string
    add_column :prompts, :idempotency_key, :string

    # Migrate existing data: set status based on sent_at
    execute <<-SQL
      UPDATE prompts
      SET status = CASE
        WHEN sent_at IS NOT NULL THEN 'sent'
        ELSE 'draft'
      END
    SQL

    # Set replied_at if there are journal entries for this prompt
    execute <<-SQL
      UPDATE prompts
      SET replied_at = (
        SELECT MIN(received_at)
        FROM journal_entries
        WHERE journal_entries.prompt_id = prompts.id
      )
      WHERE EXISTS (
        SELECT 1
        FROM journal_entries
        WHERE journal_entries.prompt_id = prompts.id
      )
    SQL

    # Update status to 'replied' if replied_at is set
    execute <<-SQL
      UPDATE prompts
      SET status = 'replied'
      WHERE replied_at IS NOT NULL
    SQL

    # Set prompt_type based on parent_prompt_id (follow-ups are adhoc)
    execute <<-SQL
      UPDATE prompts
      SET prompt_type = CASE
        WHEN parent_prompt_id IS NOT NULL THEN 'adhoc'
        WHEN source = 'ai' THEN 'daily'
        ELSE 'daily'
      END
    SQL

    # Generate idempotency_key for existing prompts (based on user_id and sent_at)
    execute <<-SQL
      UPDATE prompts
      SET idempotency_key = MD5(user_id::text || COALESCE(sent_at::text, created_at::text))
      WHERE idempotency_key IS NULL
    SQL

    # Add unique index on [user_id, idempotency_key]
    add_index :prompts, [:user_id, :idempotency_key], unique: true, name: "index_prompts_on_user_id_and_idempotency_key"
  end

  def down
    remove_index :prompts, name: "index_prompts_on_user_id_and_idempotency_key"
    remove_column :prompts, :subject
    remove_column :prompts, :status
    remove_column :prompts, :replied_at
    remove_column :prompts, :follow_up_sent_at
    remove_column :prompts, :prompt_type
    remove_column :prompts, :idempotency_key
  end
end
