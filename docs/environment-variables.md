# Environment Variables

This document lists the environment variables that can be configured for the Maybe application.

## API Keys and External Services

### Alpha Vantage (Crypto Prices)
- **`ALPHA_VANTAGE_API_KEY`**: API key for Alpha Vantage to fetch cryptocurrency prices
  - Required for crypto asset functionality
  - Get your free API key at: https://www.alphavantage.co/support/#api-key
  - Free tier: 25 requests per day
  - Can also be configured via Settings UI in self-hosted mode

### Synth Finance (Legacy - Exchange Rates and Securities)
- **`SYNTH_API_KEY`**: API key for Synth Finance (used for exchange rates and securities data)
  - Can also be configured via Settings UI in self-hosted mode

### OpenAI
- **`OPENAI_ACCESS_TOKEN`**: Access token for OpenAI API integration
  - Can also be configured via Settings UI in self-hosted mode

## Database and Security

### Database
- **`POSTGRES_PASSWORD`**: Password for PostgreSQL database (Docker setup)

### Security
- **`SECRET_KEY_BASE`**: Rails secret key base for encryption and signing
  - Generate with: `openssl rand -hex 64`
  - Required for production deployments

### Email Configuration
- **`REQUIRE_EMAIL_CONFIRMATION`**: Whether to require email confirmation for new accounts
  - Default: `"true"`
  - Set to `"false"` to disable email confirmation

## Usage Notes

- Environment variables can be set in a `.env` file for Docker deployments
- Most API keys can also be configured through the Settings UI in self-hosted mode
- The application will fall back to Settings values if environment variables are not set