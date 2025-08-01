require "test_helper"

class Provider::AlphaVantageTest < ActiveSupport::TestCase
  setup do
    @provider = Provider::AlphaVantage.new("test_api_key")
  end

  test "fetch_crypto_price returns valid data" do
    VCR.use_cassette("alpha_vantage_btc_usd") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert response.success?
      assert_instance_of Provider::Concepts::CryptoPrice::Price, response.data
      assert_equal "BTC", response.data.symbol
      assert response.data.price > 0
      assert_equal "USD", response.data.currency
      assert_not_nil response.data.timestamp
    end
  end

  test "fetch_crypto_price handles different symbols" do
    VCR.use_cassette("alpha_vantage_eth_usd") do
      response = @provider.fetch_crypto_price(symbol: "ETH", currency: "USD")
      
      assert response.success?
      assert_equal "ETH", response.data.symbol
      assert response.data.price > 0
    end
  end

  test "fetch_crypto_price handles different currencies" do
    VCR.use_cassette("alpha_vantage_btc_eur") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "EUR")
      
      assert response.success?
      assert_equal "BTC", response.data.symbol
      assert_equal "EUR", response.data.currency
      assert response.data.price > 0
    end
  end

  test "handles API error message gracefully" do
    VCR.use_cassette("alpha_vantage_error_message") do
      response = @provider.fetch_crypto_price(symbol: "INVALID", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::AlphaVantage::InvalidCryptoPriceError, response.error
      assert_includes response.error.message, "Alpha Vantage error"
    end
  end

  test "handles rate limit error gracefully" do
    VCR.use_cassette("alpha_vantage_rate_limit") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::AlphaVantage::RateLimitError, response.error
      assert_includes response.error.message, "rate limit exceeded"
    end
  end

  test "handles missing time series data" do
    VCR.use_cassette("alpha_vantage_no_data") do
      response = @provider.fetch_crypto_price(symbol: "UNKNOWN", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::AlphaVantage::InvalidCryptoPriceError, response.error
      assert_includes response.error.message, "No price data found"
    end
  end

  test "handles malformed price data" do
    VCR.use_cassette("alpha_vantage_malformed_data") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::AlphaVantage::InvalidCryptoPriceError, response.error
    end
  end

  test "normalizes symbol and currency to uppercase" do
    VCR.use_cassette("alpha_vantage_btc_usd") do
      response = @provider.fetch_crypto_price(symbol: "btc", currency: "usd")
      
      assert response.success?
      assert_equal "BTC", response.data.symbol
      assert_equal "USD", response.data.currency
    end
  end

  test "healthy? returns true when API is working" do
    VCR.use_cassette("alpha_vantage_btc_usd") do
      response = @provider.healthy?
      
      assert response.success?
      assert_equal true, response.data
    end
  end

  test "healthy? returns false when API is down" do
    VCR.use_cassette("alpha_vantage_error_message") do
      response = @provider.healthy?
      
      assert_not response.success?
    end
  end

  test "parses latest date correctly from time series" do
    # Test that we get the most recent date from the time series
    VCR.use_cassette("alpha_vantage_btc_usd") do
      response = @provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert response.success?
      # The timestamp should be a valid date string
      assert_match(/\d{4}-\d{2}-\d{2}/, response.data.timestamp)
    end
  end
end