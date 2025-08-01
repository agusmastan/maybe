class AddSpotPriceColumnsToCryptos < ActiveRecord::Migration[7.2]
  def change
    add_column :cryptos, :spot_price_cents, :integer
    add_column :cryptos, :spot_price_currency, :string, default: "USD"
    add_column :cryptos, :symbol, :string
    
    add_index :cryptos, :symbol
  end
end 