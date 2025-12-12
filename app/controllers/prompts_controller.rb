class PromptsController < ApplicationController
  def index
    matching_prompts = Prompt.all

    @list_of_prompts = matching_prompts.order({ :created_at => :desc })

    render({ :template => "prompt_templates/index" })
  end

  def show
    the_id = params.fetch("path_id")

    matching_prompts = Prompt.where({ :id => the_id })

    @the_prompt = matching_prompts.at(0)

    render({ :template => "prompt_templates/show" })
  end

  def create
    the_prompt = Prompt.new
    the_prompt.body = params.fetch("query_body")
    the_prompt.parent_prompt_id = params.fetch("query_parent_prompt_id")
    the_prompt.user_id = params.fetch("query_user_id")
    the_prompt.source = params.fetch("query_source")

    if the_prompt.valid?
      the_prompt.save
      redirect_to("/prompts", { :notice => "Prompt created successfully." })
    else
      redirect_to("/prompts", { :alert => the_prompt.errors.full_messages.to_sentence })
    end
  end

  def update
    the_id = params.fetch("path_id")
    the_prompt = Prompt.where({ :id => the_id }).at(0)

    the_prompt.body = params.fetch("query_body")
    the_prompt.parent_prompt_id = params.fetch("query_parent_prompt_id")
    the_prompt.user_id = params.fetch("query_user_id")
    the_prompt.source = params.fetch("query_source")

    if the_prompt.valid?
      the_prompt.save
      redirect_to("/prompts/#{the_prompt.id}", { :notice => "Prompt updated successfully." } )
    else
      redirect_to("/prompts/#{the_prompt.id}", { :alert => the_prompt.errors.full_messages.to_sentence })
    end
  end

  def destroy
    the_id = params.fetch("path_id")
    the_prompt = Prompt.where({ :id => the_id }).at(0)

    the_prompt.destroy

    redirect_to("/prompts", { :notice => "Prompt deleted successfully." } )
  end
end
