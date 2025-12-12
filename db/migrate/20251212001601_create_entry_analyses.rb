class CreateEntryAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :entry_analyses do |t| 
      t.references :journal_entry, null: false, foreign_key: true
  
      t.text :summary 
      t.string :sentiment 
      t.string :emotion 
      t.text :keywords

      t.timestamps
    end
  end
end
