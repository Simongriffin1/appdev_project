class UpdateEntryAnalysesForDabbleSchema < ActiveRecord::Migration[8.0]
  def up
    # Add new JSON fields
    add_column :entry_analyses, :tags, :jsonb
    add_column :entry_analyses, :key_themes, :jsonb

    # Migrate existing keywords to tags (convert comma-separated string to JSON array)
    execute <<-SQL
      UPDATE entry_analyses
      SET tags = (
        SELECT jsonb_agg(TRIM(tag))
        FROM unnest(string_to_array(keywords, ',')) AS tag
        WHERE keywords IS NOT NULL AND keywords != ''
      )
      WHERE keywords IS NOT NULL AND keywords != ''
    SQL

    # Set empty array for entries without keywords
    execute <<-SQL
      UPDATE entry_analyses
      SET tags = '[]'::jsonb
      WHERE tags IS NULL
    SQL

    # Initialize key_themes as empty array (can be populated later)
    execute <<-SQL
      UPDATE entry_analyses
      SET key_themes = '[]'::jsonb
      WHERE key_themes IS NULL
    SQL

    # Add index on tags for efficient queries
    add_index :entry_analyses, :tags, using: :gin, name: "index_entry_analyses_on_tags"
  end

  def down
    remove_index :entry_analyses, name: "index_entry_analyses_on_tags"
    
    # Convert tags back to keywords (comma-separated string)
    execute <<-SQL
      UPDATE entry_analyses
      SET keywords = (
        SELECT string_agg(value::text, ', ')
        FROM jsonb_array_elements_text(tags) AS value
        WHERE tags IS NOT NULL
      )
      WHERE tags IS NOT NULL
    SQL

    remove_column :entry_analyses, :tags
    remove_column :entry_analyses, :key_themes
  end
end
