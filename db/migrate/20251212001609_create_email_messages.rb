class CreateEmailMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :email_messages do |t| 
      t.references :user, null: false, foreign_key: true
      t.string :direction
      t.references :prompt, null: false, foreign_key: true
      t.references :journal_entry, null: false, foreign_key: true 
      t.string :subject 
      t.text :body 
      t.datetime :sent_or_received_at

      t.timestamps
    end
  end
end
