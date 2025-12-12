Rails.application.routes.draw do
  # Routes for the Email message resource:

  # CREATE
  post("/insert_email_message", { :controller => "email_messages", :action => "create" })

  # READ
  get("/email_messages", { :controller => "email_messages", :action => "index" })

  get("/email_messages/:path_id", { :controller => "email_messages", :action => "show" })

  # UPDATE

  post("/modify_email_message/:path_id", { :controller => "email_messages", :action => "update" })

  # DELETE
  get("/delete_email_message/:path_id", { :controller => "email_messages", :action => "destroy" })

  #------------------------------

  # Routes for the Entry analysis resource:

  # CREATE
  post("/insert_entry_analysis", { :controller => "entry_analyses", :action => "create" })

  # READ
  get("/entry_analyses", { :controller => "entry_analyses", :action => "index" })

  get("/entry_analyses/:path_id", { :controller => "entry_analyses", :action => "show" })

  # UPDATE

  post("/modify_entry_analysis/:path_id", { :controller => "entry_analyses", :action => "update" })

  # DELETE
  get("/delete_entry_analysis/:path_id", { :controller => "entry_analyses", :action => "destroy" })

  #------------------------------

  # Routes for the Entry topic resource:

  # CREATE
  post("/insert_entry_topic", { :controller => "entry_topics", :action => "create" })

  # READ
  get("/entry_topics", { :controller => "entry_topics", :action => "index" })

  get("/entry_topics/:path_id", { :controller => "entry_topics", :action => "show" })

  # UPDATE

  post("/modify_entry_topic/:path_id", { :controller => "entry_topics", :action => "update" })

  # DELETE
  get("/delete_entry_topic/:path_id", { :controller => "entry_topics", :action => "destroy" })

  #------------------------------

  # Routes for the Topic resource:

  # CREATE
  post("/insert_topic", { :controller => "topics", :action => "create" })

  # READ
  get("/topics", { :controller => "topics", :action => "index" })

  get("/topics/:path_id", { :controller => "topics", :action => "show" })

  # UPDATE

  post("/modify_topic/:path_id", { :controller => "topics", :action => "update" })

  # DELETE
  get("/delete_topic/:path_id", { :controller => "topics", :action => "destroy" })

  #------------------------------

  # Routes for the Journal entry resource:

  # CREATE
  post("/insert_journal_entry", { :controller => "journal_entries", :action => "create" })

  # READ
  get("/journal_entries", { :controller => "journal_entries", :action => "index" })

  get("/journal_entries/:path_id", { :controller => "journal_entries", :action => "show" })

  # UPDATE

  post("/modify_journal_entry/:path_id", { :controller => "journal_entries", :action => "update" })

  # DELETE
  get("/delete_journal_entry/:path_id", { :controller => "journal_entries", :action => "destroy" })

  #------------------------------

  # Routes for the Prompt resource:

  # CREATE
  post("/insert_prompt", { :controller => "prompts", :action => "create" })

  # READ
  get("/prompts", { :controller => "prompts", :action => "index" })

  get("/prompts/:path_id", { :controller => "prompts", :action => "show" })

  # UPDATE

  post("/modify_prompt/:path_id", { :controller => "prompts", :action => "update" })

  # DELETE
  get("/delete_prompt/:path_id", { :controller => "prompts", :action => "destroy" })

  #------------------------------

  # Routes for the User resource:

  # CREATE
  post("/insert_user", { :controller => "users", :action => "create" })

  # READ
  get("/users", { :controller => "users", :action => "index" })

  get("/users/:path_id", { :controller => "users", :action => "show" })

  # UPDATE

  post("/modify_user/:path_id", { :controller => "users", :action => "update" })

  # DELETE
  get("/delete_user/:path_id", { :controller => "users", :action => "destroy" })

  #------------------------------

  # This is a blank app! Pick your first screen, build out the RCAV, and go from there. E.g.:
  # get("/your_first_screen", { :controller => "pages", :action => "first" })
end
