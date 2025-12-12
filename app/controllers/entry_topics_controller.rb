class EntryTopicsController < ApplicationController
  def index
    matching_entry_topics = EntryTopic.all

    @list_of_entry_topics = matching_entry_topics.order({ :created_at => :desc })

    render({ :template => "entry_topic_templates/index" })
  end

  def show
    the_id = params.fetch("path_id")

    matching_entry_topics = EntryTopic.where({ :id => the_id })

    @the_entry_topic = matching_entry_topics.at(0)

    render({ :template => "entry_topic_templates/show" })
  end

  def create
    the_entry_topic = EntryTopic.new
    the_entry_topic.  = params.fetch("query_ ")
    the_entry_topic.journal_entry_id = params.fetch("query_journal_entry_id")
    the_entry_topic.  = params.fetch("query_ ")
    the_entry_topic.topic_id = params.fetch("query_topic_id")

    if the_entry_topic.valid?
      the_entry_topic.save
      redirect_to("/entry_topics", { :notice => "Entry topic created successfully." })
    else
      redirect_to("/entry_topics", { :alert => the_entry_topic.errors.full_messages.to_sentence })
    end
  end

  def update
    the_id = params.fetch("path_id")
    the_entry_topic = EntryTopic.where({ :id => the_id }).at(0)

    the_entry_topic.  = params.fetch("query_ ")
    the_entry_topic.journal_entry_id = params.fetch("query_journal_entry_id")
    the_entry_topic.  = params.fetch("query_ ")
    the_entry_topic.topic_id = params.fetch("query_topic_id")

    if the_entry_topic.valid?
      the_entry_topic.save
      redirect_to("/entry_topics/#{the_entry_topic.id}", { :notice => "Entry topic updated successfully." } )
    else
      redirect_to("/entry_topics/#{the_entry_topic.id}", { :alert => the_entry_topic.errors.full_messages.to_sentence })
    end
  end

  def destroy
    the_id = params.fetch("path_id")
    the_entry_topic = EntryTopic.where({ :id => the_id }).at(0)

    the_entry_topic.destroy

    redirect_to("/entry_topics", { :notice => "Entry topic deleted successfully." } )
  end
end
