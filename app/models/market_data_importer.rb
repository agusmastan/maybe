class MarketDataImporter
  # By default, our graphs show 1M as the view, so by fetching 31 days,
  # we ensure we can always show an accurate default graph
  SNAPSHOT_DAYS = 31

  InvalidModeError = Class.new(StandardError)

  def initialize(mode: :full, clear_cache: false)
    @mode = set_mode!(mode)
    @clear_cache = clear_cache
  end

  def import_all
    import_security_prices
    import_exchange_rates
  end

  # Syncs CURRENT security prices only (no historical data to save API tokens)
  def import_security_prices
    unless Security.provider
      Rails.logger.warn("No provider configured for MarketDataImporter.import_security_prices, skipping sync")
      return
    end

    Rails.logger.info("🔄 Importing CURRENT prices only (historical disabled to save API tokens)")
    
    # Import all securities that aren't marked as "offline" (i.e. they're available from the provider)
    Security.online.find_each do |security|
      begin
        # Only fetch current price (today) - no historical data
        security.find_or_fetch_price(date: Date.current, cache: true)
        
        # Import basic details (logo, name, etc.)
        security.import_provider_details(clear_cache: clear_cache)
        
        Rails.logger.info("✅ Updated current price for #{security.ticker}")
      rescue => e
        Rails.logger.error("❌ Failed to update #{security.ticker}: #{e.message}")
      end
    end
  end

  def import_exchange_rates
    unless ExchangeRate.provider
      Rails.logger.warn("No provider configured for MarketDataImporter.import_exchange_rates, skipping sync")
      return
    end

    Rails.logger.info("🔄 Importing CURRENT exchange rates only (historical disabled to save API tokens)")
    
    # Only update current USD-EUR rate to save API tokens
    begin
      ExchangeRate.update_usd_to_eur_rate!
      Rails.logger.info("✅ Updated current USD-EUR exchange rate")
    rescue => e
      Rails.logger.error("❌ Failed to update USD-EUR rate: #{e.message}")
    end
  end

  private
    attr_reader :mode, :clear_cache

    def snapshot?
      mode.to_sym == :snapshot
    end

    # Builds a unique list of currency pairs with the earliest date we need
    # exchange rates for.
    #
    # Returns: Array of Hashes – [{ source:, target:, start_date: }, ...]
    def required_exchange_rate_pairs
      pair_dates = {} # { [source, target] => earliest_date }

      # 1. ENTRY-BASED PAIRS – we need rates from the first entry date
      Entry.joins(:account)
           .where.not("entries.currency = accounts.currency")
           .group("entries.currency", "accounts.currency")
           .minimum("entries.date")
           .each do |(source, target), date|
        key = [ source, target ]
        pair_dates[key] = [ pair_dates[key], date ].compact.min
      end

      # 2. ACCOUNT-BASED PAIRS – use the account's oldest entry date
      account_first_entry_dates = Entry.group(:account_id).minimum(:date)

      Account.joins(:family)
             .where.not("families.currency = accounts.currency")
             .select("accounts.id, accounts.currency AS source, families.currency AS target")
             .find_each do |account|
        earliest_entry_date = account_first_entry_dates[account.id]

        chosen_date = [ earliest_entry_date, default_start_date ].compact.min

        key = [ account.source, account.target ]
        pair_dates[key] = [ pair_dates[key], chosen_date ].compact.min
      end

      # Convert to array of hashes for ease of use
      pair_dates.map do |(source, target), date|
        { source: source, target: target, start_date: date }
      end
    end

    def get_first_required_price_date(security)
      return default_start_date if snapshot?

      Trade.with_entry.where(security: security).minimum(:date) || default_start_date
    end

    # An approximation that grabs more than we likely need, but simplifies the logic
    def get_first_required_exchange_rate_date(from_currency:)
      return default_start_date if snapshot?

      Entry.where(currency: from_currency).minimum(:date) || default_start_date
    end

    def default_start_date
      SNAPSHOT_DAYS.days.ago.to_date
    end

    # Since we're querying market data from a US-based API, end date should always be today (EST)
    def end_date
      Date.current.in_time_zone("America/New_York").to_date
    end

    def set_mode!(mode)
      valid_modes = [ :full, :snapshot ]

      unless valid_modes.include?(mode.to_sym)
        raise InvalidModeError, "Invalid mode for MarketDataImporter, can only be :full or :snapshot, but was #{mode}"
      end

      mode.to_sym
    end
end
