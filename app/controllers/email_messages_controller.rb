class EmailMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_email_message, only: %i[show edit update destroy]

  # GET /email_messages
  def index
    @email_messages = current_user.email_messages.order(sent_or_received_at: :desc)
  end

  # GET /email_messages/:id
  def show
  end

  # GET /email_messages/new
  def new
    @email_message = current_user.email_messages.new
  end

  # POST /email_messages
  def create
    @email_message = current_user.email_messages.new(email_message_params)

    if @email_message.save
      redirect_to @email_message, notice: "Email message created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /email_messages/:id/edit
  def edit
  end

  # PATCH/PUT /email_messages/:id
  def update
    if @email_message.update(email_message_params)
      redirect_to @email_message, notice: "Email message updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /email_messages/:id
  def destroy
    @email_message.destroy
    redirect_to email_messages_path, notice: "Email message deleted."
  end

  private

  def set_email_message
    @email_message = current_user.email_messages.find(params[:id])
  end

  def email_message_params
    params.require(:email_message).permit(
      :direction,
      :prompt_id,
      :journal_entry_id,
      :subject,
      :body,
      :sent_or_received_at
    )
  end
end
