class EntryAnalysis < ApplicationRecord
  belongs_to :journal_entry

  # If you want an easy shortcut to user:
  has_one :user, through: :journal_entry
end

