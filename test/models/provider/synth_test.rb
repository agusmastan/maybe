require "test_helper"
require "ostruct"

class Provider::SynthTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest, SecurityProviderInterfaceTest

  setup do
    @subject = @synth = Provider::Synth.new(ENV["SYNTH_API_KEY"])
  end

  test "health check" do
    VCR.use_cassette("synth/health") do
      assert @synth.healthy?
    end
  end

  test "usage info" do
    VCR.use_cassette("synth/usage") do
      usage = @synth.usage.data
      assert usage.used.present?
      assert usage.limit.present?
      assert usage.utilization.present?
      assert usage.plan.present?
    end
  end

  test "fetch_crypto_price returns price data" do
    VCR.use_cassette("synth_provider/fetch_crypto_price") do
      provider = Provider::Synth.new("test_api_key")
      
      response = provider.fetch_crypto_price(symbol: "BTC", currency: "USD")
      
      assert response.success?
      assert_instance_of Provider::Concepts::CryptoPrice::Price, response.data
      assert_equal "BTC", response.data.symbol
      assert response.data.price.present?
      assert_equal "USD", response.data.currency
    end
  end

  test "fetch_crypto_price handles invalid symbol" do
    VCR.use_cassette("synth_provider/fetch_crypto_price_invalid") do
      provider = Provider::Synth.new("test_api_key")
      
      response = provider.fetch_crypto_price(symbol: "INVALID", currency: "USD")
      
      assert_not response.success?
      assert_instance_of Provider::Synth::Error, response.error
    end
  end
end
