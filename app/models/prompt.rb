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

