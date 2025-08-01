require "test_helper"

class CryptoPriceTest < ActiveSupport::TestCase
  test "provider returns synth provider when available" do
    provider = mock
    registry = mock
    registry.expects(:get_provider).with(:synth).returns(provider)
    Provider::Registry.expects(:for_concept).with(:crypto_prices).returns(registry)

    assert_equal provider, CryptoPrice.provider
  end

  test "current_price returns cached price data" do
    price_data = Provider::Concepts::CryptoPrice::Price.new(
      symbol: "BTC",
      price: 67340.21,
      currency: "USD",
      timestamp: Time.current.iso8601
    )

    provider = mock
    response = mock
    response.expects(:success?).returns(true)
    response.expects(:data).returns(price_data)
    provider.expects(:fetch_crypto_price).with(symbol: "BTC", currency: "USD").returns(response)

    CryptoPrice.expects(:provider).returns(provider)

    # First call should fetch from provider
    result = CryptoPrice.current_price(symbol: "BTC", currency: "USD")
    assert_equal price_data, result

    # Second call should return cached result (provider won't be called again)
    CryptoPrice.expects(:provider).returns(provider)
    result2 = CryptoPrice.current_price(symbol: "BTC", currency: "USD")
    assert_equal price_data, result2
  end

  test "current_price returns nil when no provider available" do
    CryptoPrice.expects(:provider).returns(nil)

    result = CryptoPrice.current_price(symbol: "BTC", currency: "USD")
    assert_nil result
  end

  test "current_price handles provider errors gracefully" do
    provider = mock
    response = mock
    response.expects(:success?).returns(false)
    response.expects(:error).returns(Provider::Error.new("API Error"))
    provider.expects(:fetch_crypto_price).with(symbol: "BTC", currency: "USD").returns(response)

    CryptoPrice.expects(:provider).returns(provider)
    Rails.logger.expects(:warn).with(regexp_matches(/Failed to fetch crypto price/))

    result = CryptoPrice.current_price(symbol: "BTC", currency: "USD")
    assert_nil result
  end
end 