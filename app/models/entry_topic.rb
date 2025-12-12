class EntryTopic < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :topic
end

