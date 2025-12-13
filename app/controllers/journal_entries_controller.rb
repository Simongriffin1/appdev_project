class JournalEntriesController < ApplicationController
  before_action :set_journal_entry, only: [:show]

  def index
    if params[:topic_id].present?
      topic = current_user.topics.find(params[:topic_id].to_i)
      @journal_entries = current_user.journal_entries
        .joins(:entry_topics)
        .where(entry_topics: { topic_id: topic.id })
        .includes(:prompt, :entry_analysis)
        .order(created_at: :desc)
      @filtered_topic = topic
    else
      @journal_entries = current_user.journal_entries
        .includes(:prompt, :entry_analysis)
        .order(created_at: :desc)
    end
  end

  def show
  end

  def new
    @journal_entry = current_user.journal_entries.new
    @journal_entry.prompt_id = params[:prompt_id].to_i if params[:prompt_id].present?
  end

  def create
    @journal_entry = current_user.journal_entries.new(journal_entry_params)

    if @journal_entry.save
      # Trigger AI analysis
      EntryAnalysisGenerator.new(@journal_entry).generate!

      redirect_to @journal_entry, notice: "Journal entry created successfully."
    else
      # If coming from a prompt, set up the prompt context for re-rendering
      if @journal_entry.prompt_id.present?
        @prompt = current_user.prompts.find_by(id: @journal_entry.prompt_id)
        if @prompt.present?
          # Ensure both @prompt and @journal_entry are set for the prompts/show template
          # The template expects both variables to be available
          render "prompts/show", status: :unprocessable_entity
        else
          # Prompt was deleted or invalid, clear prompt_id and fall back to standard form
          @journal_entry.prompt_id = nil
          render :new, status: :unprocessable_entity
        end
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  private

  def set_journal_entry
    @journal_entry = current_user.journal_entries.find(params[:id])
  end

  def journal_entry_params
    params.require(:journal_entry).permit(:prompt_id, :body, :source)
  end
end
