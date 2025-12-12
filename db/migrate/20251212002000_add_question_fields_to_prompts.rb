class AddQuestionFieldsToPrompts < ActiveRecord::Migration[8.0]
  def change
    add_column :prompts, :question_1, :text
    add_column :prompts, :question_2, :text
    add_column :prompts, :sent_at, :datetime
  end
end
