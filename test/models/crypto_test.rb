require "test_helper"

class CryptoTest < ActiveSupport::TestCase
  setup do
    @family = families(:dylan_family)
    @crypto = @family.accounts.create!(
      name: "Bitcoin Wallet",
      balance: 1000,
      currency: "USD",
      accountable: Crypto.new(symbol: "BTC")
    )
  end

  test "crypto has symbol" do
    assert_equal "BTC", @crypto.accountable.symbol
  end

  test "crypto validates symbol presence when provided" do
    crypto = Crypto.new
    assert crypto.valid? # symbol is optional

    crypto.symbol = ""
    assert_not crypto.valid?
    assert_includes crypto.errors[:symbol], "can't be blank"
  end

  test "current_spot_price_money returns money object when price is set" do
    @crypto.accountable.update!(
      spot_price_cents: 6734021, # $67,340.21
      spot_price_currency: "USD"
    )

    price = @crypto.accountable.current_spot_price_money
    assert_instance_of Money, price
    assert_equal 6734021, price.amount.to_i
    assert_equal "USD", price.currency.iso_code
  end

  test "current_spot_price_money returns nil when no price is set" do
    assert_nil @crypto.accountable.current_spot_price_money
  end

  test "refresh_spot_price is called after create" do
    CryptoPrice.expects(:current_price).with(symbol: "ETH", currency: "USD").returns(
      Provider::Concepts::CryptoPrice::Price.new(
        symbol: "ETH",
        price: 3500.0,
        currency: "USD",
        timestamp: Time.current.iso8601
      )
    ).once

    crypto_account = @family.accounts.create!(
      name: "Ethereum Wallet",
      balance: 1000,
      currency: "USD",
      accountable: Crypto.new(symbol: "ETH")
    )

    # Check that the price was set
    crypto_account.accountable.reload
    assert_equal 350000, crypto_account.accountable.spot_price_cents
    assert_equal "USD", crypto_account.accountable.spot_price_currency
  end

  test "refresh_spot_price handles provider errors gracefully" do
    CryptoPrice.expects(:current_price).raises(Provider::Error.new("API Error"))
    Rails.logger.expects(:error).with(regexp_matches(/crypto price error/))

    # Should not raise an exception
    assert_nothing_raised do
      @family.accounts.create!(
        name: "Dogecoin Wallet",
        balance: 1000,
        currency: "USD",
        accountable: Crypto.new(symbol: "DOGE")
      )
    end
  end

  test "refreshes spot price with Alpha Vantage" do
    VCR.use_cassette("alpha_vantage_eth_usd") do
      # Mock the provider to return Alpha Vantage
      alpha_vantage_provider = Provider::AlphaVantage.new("test_key")
      Provider::Registry.any_instance.stubs(:get_provider).with(:alpha_vantage).returns(alpha_vantage_provider)
      
      crypto_account = @family.accounts.create!(
        name: "Ethereum Test Wallet",
        balance: 1000,
        currency: "USD",
        accountable: Crypto.new(symbol: "ETH")
      )
      
      crypto_account.accountable.reload
      assert_not_nil crypto_account.accountable.spot_price_cents
      assert_equal "USD", crypto_account.accountable.spot_price_currency
      # ETH price from VCR cassette: 3256.78
      assert_equal 325678, crypto_account.accountable.spot_price_cents
    end
  end
end 