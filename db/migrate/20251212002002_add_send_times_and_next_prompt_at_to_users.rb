class AddSendTimesAndNextPromptAtToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :send_times, :string
    add_column :users, :next_prompt_at, :datetime
  end
end
