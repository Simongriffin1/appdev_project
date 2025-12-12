# Journaling App

A Rails 8 web application for personal journaling with AI-generated prompts and automatic entry analysis.

## Features

- User authentication (sign up, sign in, sign out)
- AI-generated journaling prompts based on your recent entries
- Create and manage journal entries
- Automatic AI analysis of entries (summary, sentiment, emotion, topics)
- Browse entries by topic
- Clean, simple interface

## Local Development

### Prerequisites

- Ruby 3.0 or higher
- PostgreSQL
- Bundler

### Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Setup the database:
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   ```

3. (Optional) Set up OpenAI API key for AI features:
   ```bash
   # Create .env file in project root
   echo 'OPENAI_API_KEY=your-api-key-here' > .env
   ```
   The app works without this - it will use fallback prompts and basic analysis.

4. Start the server:
   ```bash
   bin/rails server
   ```

5. Visit `http://localhost:3000`

### OpenAI Integration

The app uses the `dotenv` gem to load environment variables from `.env` file in development. 

- **With API key**: Full AI features (GPT-4o-mini for prompts and analysis)
- **Without API key**: Fallback prompts and basic analysis (app still fully functional)

The `.env` file is git-ignored and will not be committed to the repository.

## Deployment

This app is configured for deployment on Render.

### Render Deployment

1. Connect your repository to Render
2. Create a new Web Service
3. Render will automatically detect the `render.yaml` configuration
4. Ensure `DATABASE_URL` is set (Render will provide this automatically)
5. Add `OPENAI_API_KEY` as an environment variable in Render dashboard:
   - Go to your service → Environment
   - Add new environment variable: `OPENAI_API_KEY`
   - Enter your API key value
   - Save changes

The app uses:
- PostgreSQL (via `DATABASE_URL`)
- Puma web server
- Standard Rails 8 production configuration

## License

MIT License - see [LICENSE.txt](LICENSE.txt)
