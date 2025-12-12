class PromptsController < ApplicationController
  before_action :set_prompt, only: [:show]

  def index
    @prompts = current_user.prompts.order(created_at: :desc)
  end

  def show
    @journal_entry = current_user.journal_entries.new(prompt: @prompt)
  end

  def generate
    prompt = PromptGenerator.new(current_user).generate!
    redirect_to prompt_path(prompt), notice: "New prompt generated."
  end

  private

  def set_prompt
    @prompt = current_user.prompts.find(params[:id])
  end
end
