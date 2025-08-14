class CryptosController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :symbol

  def create
    symbol   = crypto_params[:symbol]&.upcase
    quantity = crypto_params[:quantity]&.to_f
  
    if symbol.blank? || quantity.blank? || quantity <= 0
      @error_message = "El símbolo y la cantidad son requeridos y la cantidad debe ser mayor que 0"
      @account = Current.family.accounts.build(currency: Current.family.currency, accountable: Crypto.new(symbol: symbol))
      render :new, status: :unprocessable_entity and return
    end
  
    currency   = Current.family.currency
    price_data = CryptoPrice.current_price(symbol: symbol, currency: currency)
    unless price_data
      @error_message = "No se pudo obtener el precio actual para #{symbol}. Verifica el símbolo."
      @account = Current.family.accounts.build(currency: Current.family.currency, accountable: Crypto.new(symbol: symbol))
      render :new, status: :unprocessable_entity and return
    end
  
    total_balance = quantity * price_data.price
  
    # Buscar cuenta Crypto existente por símbolo dentro de la familia
    existing_account = Current.family.accounts
      .where(accountable_type: "Crypto")
      .joins("INNER JOIN cryptos ON cryptos.id = accounts.accountable_id")
      .where("UPPER(cryptos.symbol) = ?", symbol)
      .first
  
    if existing_account
      # Actualizar spot price en DB
      existing_account.accountable.update!(
        spot_price_cents: (price_data.price * 100).to_i,
        spot_price_currency: price_data.currency
      )
  
      # Actualizar balance actual (usa anclaje/valorización correcta)
      existing_account.set_current_balance(total_balance)
  
      redirect_to params[:return_to].presence || existing_account,
        notice: "Actualizado #{symbol}: precio y balance" and return
    end
  
    # Crear nueva cuenta si no existía
    # Buscar cuenta crypto existente por símbolo
    existing_account = Current.family.accounts
      .where(accountable_type: "Crypto")
      .joins("INNER JOIN cryptos ON cryptos.id = accounts.accountable_id")
      .where("UPPER(cryptos.symbol) = ?", symbol)
      .first

    if existing_account
      # Actualizar spot price
      existing_account.accountable.update!(
        spot_price_cents: (price_data.price * 100).to_i,
        spot_price_currency: price_data.currency,
        quantity: quantity
      )

      # Actualizar balance a cantidad * precio
      existing_account.set_current_balance(total_balance)

      redirect_to params[:return_to].presence || existing_account, notice: "Actualizado #{symbol}: precio y cantidad"
      return
    end

    @account = Current.family.accounts.create_and_sync(
      name: "#{symbol}",
      balance: total_balance,
      currency: currency,
      accountable_type: "Crypto",
      accountable_attributes: { symbol: symbol, quantity: quantity }
    )
    @account.lock_saved_attributes!
  
    if @account.persisted?
      redirect_to params[:return_to].presence || @account, notice: "Cuenta de #{symbol} creada"
    else
      @error_message = @account.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def crypto_params
    params.require(:crypto).permit(:symbol, :quantity, :return_to)
  end
end
