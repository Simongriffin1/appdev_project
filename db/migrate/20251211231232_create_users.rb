class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :time_zone
      t.string :prompt_frequency
      t.string :prompt_channel

      t.timestamps
    end
  end
end
