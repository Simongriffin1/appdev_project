class AddSchedulePausedToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :schedule_paused, :boolean, default: false, null: false
  end
end
