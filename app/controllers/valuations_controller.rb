class ValuationsController < ApplicationController
  include EntryableResource, StreamExtensions

  def confirm_create
    @account = Current.family.accounts.find(params.dig(:entry, :account_id))
    @entry = @account.entries.build(entry_params.merge(currency: @account.currency))

    @reconciliation_dry_run = @entry.account.create_reconciliation(
      balance: entry_params[:amount],
      date: entry_params[:date],
      dry_run: true
    )

    render :confirm_create
  end

  def confirm_update
    @entry = Current.family.entries.find(params[:id])
    @account = @entry.account
    @entry.assign_attributes(entry_params.merge(currency: @account.currency))

    @reconciliation_dry_run = @entry.account.update_reconciliation(
      @entry,
      balance: entry_params[:amount],
      date: entry_params[:date],
      dry_run: true
    )

    render :confirm_update
  end

  def create
    account = Current.family.accounts.find(params.dig(:entry, :account_id))
    if (account.crypto? || account.stock?)
      type = account.crypto? ? :crypto : :stock
      # Interpret amount as quantity to add for Crypto/Stock accounts
      qty_to_add = entry_params[:amount].to_d
      account = account.accountable
      new_qty = (type.quantity || 0).to_d + qty_to_add
      type.update!(quantity: new_qty)

      # Recalculate balance = quantity * spot price (if available)
      if type.spot_price_cents.present?
        new_balance = new_qty * (type.spot_price_cents.to_d / 100)
        account.set_current_balance(new_balance)
      end
      result = OpenStruct.new(success?: true)
    else
      result = account.create_reconciliation(
        balance: entry_params[:amount],
        date: entry_params[:date],
      )
    end

    if result.success?
      respond_to do |format|
        format.html { redirect_back_or_to account_path(account), notice: "Account updated" }
        format.turbo_stream { stream_redirect_back_or_to(account_path(account), notice: "Account updated") }
      end
    else
      @error_message = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Notes updating is independent of reconciliation, just a simple CRUD operation
    @entry.update!(notes: entry_params[:notes]) if entry_params[:notes].present?

    if entry_params[:date].present? && entry_params[:amount].present?
      if (@entry.account.crypto? || @entry.account.stock?)
        type = @entry.account.crypto? ? :crypto : :stock
        qty_to_add = entry_params[:amount].to_d
        type = @entry.account.accountable
        new_qty = (type.quantity || 0).to_d + qty_to_add
        type.update!(quantity: new_qty)
        if type.spot_price_cents.present?
          new_balance = new_qty * (type.spot_price_cents.to_d / 100)
          result = @entry.account.set_current_balance(new_balance)
        else
          result = OpenStruct.new(success?: true)
        end
      else
        result = @entry.account.update_reconciliation(
          @entry,
          balance: entry_params[:amount],
          date: entry_params[:date],
        )
      end
    end

    if result.nil? || result.success?
      @entry.reload

      respond_to do |format|
        format.html { redirect_back_or_to account_path(@entry.account), notice: "Entry updated" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@entry, :header),
              partial: "valuations/header",
              locals: { entry: @entry }
            ),
            turbo_stream.replace(@entry)
          ]
        end
      end
    else
      @error_message = result.error_message
      render :show, status: :unprocessable_entity
    end
  end

  private
    def entry_params
      params.require(:entry).permit(:date, :amount, :notes)
    end
end
