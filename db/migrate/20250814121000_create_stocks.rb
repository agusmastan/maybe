class CreateStocks < ActiveRecord::Migration[7.2]
  def change
    create_table :stocks, id: :uuid do |t|
      t.string :ticker
      t.decimal :quantity, precision: 19, scale: 8, default: 0, null: false
      t.integer :spot_price_cents
      t.string :spot_price_currency, default: "EUR"
      t.jsonb :locked_attributes, default: {}
      t.timestamps
    end

    add_index :stocks, :ticker
  end
end


