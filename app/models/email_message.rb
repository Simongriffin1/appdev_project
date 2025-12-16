# == Schema Information
#
# Table name: email_messages
#
#  id                  :bigint           not null, primary key
#  body                :text
#  direction           :string
#  sent_or_received_at :datetime
#  subject             :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  journal_entry_id    :bigint
#  prompt_id           :bigint
#  user_id             :bigint           not null
#
# Indexes
#
#  index_email_messages_on_journal_entry_id  (journal_entry_id)
#  index_email_messages_on_prompt_id         (prompt_id)
#  index_email_messages_on_user_id           (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_entry_id => journal_entries.id)
#  fk_rails_...  (prompt_id => prompts.id)
#  fk_rails_...  (user_id => users.id)
#
class EmailMessage < ApplicationRecord
  belongs_to :user
  belongs_to :prompt, optional: true
  belongs_to :journal_entry, optional: true

  # Enums
  enum direction: {
    inbound: "inbound",
    outbound: "outbound"
  }

  # Validations
  validates :direction, presence: true
  validates :subject, presence: true
end
