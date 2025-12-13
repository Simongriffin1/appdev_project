# == Schema Information
#
# Table name: entry_analyses
#
#  id               :bigint           not null, primary key
#  emotion          :string
#  keywords         :text
#  sentiment        :string
#  summary          :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_entry_id :bigint           not null
#
# Indexes
#
#  index_entry_analyses_on_journal_entry_id  (journal_entry_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_entry_id => journal_entries.id)
#
class EntryAnalysis < ApplicationRecord
  belongs_to :journal_entry

  # If you want an easy shortcut to user:
  has_one :user, through: :journal_entry
end

