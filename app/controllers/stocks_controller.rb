class StocksController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :ticker

  def create
    ticker   = stock_params[:ticker]&.upcase
    quantity = stock_params[:quantity]&.to_d

    if ticker.blank? || quantity.blank? || quantity <= 0
      @error_message = "El ticker y la cantidad son requeridos y la cantidad debe ser mayor que 0"
      @account = Current.family.accounts.build(currency: Current.family.currency, accountable: Stock.new(ticker: ticker))
      render :new, status: :unprocessable_entity and return
    end

    currency   = Current.family.currency || "EUR"
    price_data = StockPrice.current_price(symbol: ticker, currency: currency)
    unless price_data
      @error_message = "No se pudo obtener el precio actual para #{ticker}. Verifica el ticker."
      @account = Current.family.accounts.build(currency: Current.family.currency, accountable: Stock.new(ticker: ticker))
      render :new, status: :unprocessable_entity and return
    end

    total_balance = quantity * price_data.price

    existing_account = Current.family.accounts
      .where(accountable_type: "Stock")
      .joins("INNER JOIN stocks ON stocks.id = accounts.accountable_id")
      .where("UPPER(stocks.ticker) = ?", ticker)
      .first

    if existing_account
      stock = existing_account.accountable
      new_qty = (stock.quantity || 0).to_d + quantity
      stock.update!(
        spot_price_cents: (price_data.price * 100).to_i,
        spot_price_currency: price_data.currency,
        quantity: new_qty
      )
      existing_account.set_current_balance(new_qty * price_data.price)
      redirect_to params[:return_to].presence || existing_account, notice: "Actualizado #{ticker}: precio y cantidad" and return
    end

    @account = Current.family.accounts.create_and_sync(
      name: "#{ticker} Portfolio",
      balance: total_balance,
      currency: currency,
      accountable_type: "Stock",
      accountable_attributes: { ticker: ticker, quantity: quantity }
    )
    @account.lock_saved_attributes!

    if @account.persisted?
      redirect_to params[:return_to].presence || @account, notice: "Cuenta de #{ticker} creada"
    else
      @error_message = @account.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  private
    def stock_params
      params.require(:stock).permit(:ticker, :quantity, :return_to)
    end
end


