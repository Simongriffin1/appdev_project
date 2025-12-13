# == Schema Information
#
# Table name: prompts
#
#  id               :bigint           not null, primary key
#  body             :text
#  question_1       :text
#  question_2       :text
#  sent_at          :datetime
#  source           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  parent_prompt_id :integer
#  user_id          :bigint           not null
#
# Indexes
#
#  index_prompts_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Prompt < ApplicationRecord
  belongs_to :user, optional: true

  belongs_to :parent_prompt,
             class_name: "Prompt",
             foreign_key: "parent_prompt_id",
             optional: true

  has_many :child_prompts,
           class_name: "Prompt",
           foreign_key: "parent_prompt_id",
           dependent: :nullify

  has_many :journal_entries, dependent: :nullify
  has_many :email_messages, dependent: :nullify
end

