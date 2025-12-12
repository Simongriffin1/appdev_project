class CreateEntryTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :entry_topics do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true

      t.timestamps
    end

    add_index :entry_topics, [:journal_entry_id, :topic_id], unique: true
  end
end
