class EmailMessage < ApplicationRecord
  belongs_to :user
  belongs_to :prompt, optional: true
  belongs_to :journal_entry, optional: true
end
