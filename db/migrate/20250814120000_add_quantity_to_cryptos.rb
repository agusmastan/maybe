class AddQuantityToCryptos < ActiveRecord::Migration[7.2]
  def change
    add_column :cryptos, :quantity, :decimal, precision: 19, scale: 8, default: 0, null: false
    add_index :cryptos, :quantity
  end
end


