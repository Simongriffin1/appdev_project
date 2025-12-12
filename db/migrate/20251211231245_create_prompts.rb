class CreatePrompts < ActiveRecord::Migration[8.0]
  def change
    create_table :prompts do |t|
      t.text :body
      t.integer :parent_prompt_id
      t.references :user, null: false, foreign_key: true
      t.string :source

      t.timestamps
    end
  end
end
