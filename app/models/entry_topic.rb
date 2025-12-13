# == Schema Information
#
# Table name: entry_topics
#
#  id               :bigint           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_entry_id :bigint           not null
#  topic_id         :bigint           not null
#
# Indexes
#
#  index_entry_topics_on_journal_entry_id               (journal_entry_id)
#  index_entry_topics_on_journal_entry_id_and_topic_id  (journal_entry_id,topic_id) UNIQUE
#  index_entry_topics_on_topic_id                       (topic_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_entry_id => journal_entries.id)
#  fk_rails_...  (topic_id => topics.id)
#
class EntryTopic < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :topic
end

