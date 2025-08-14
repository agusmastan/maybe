class AccountsController < ApplicationController
  before_action :set_account, only: %i[sync sparkline toggle_active show destroy]
  include Periodable

  def index
    @manual_accounts = family.accounts.manual.alphabetically
    @plaid_items = family.plaid_items.ordered

    render layout: "settings"
  end

  def sync_all
    family.sync_later
    redirect_to accounts_path, notice: "Syncing accounts..."
  end

  def show
    @chart_view = params[:chart_view] || "balance"
    @tab = params[:tab]
    @q = params.fetch(:q, {}).permit(:search)
    entries = @account.entries.search(@q).reverse_chronological

    @pagy, @entries = pagy(entries, limit: params[:per_page] || "10")

    @activity_feed_data = Account::ActivityFeedData.new(@account, @entries)
  end

  def sync
     # For Crypto accounts, refresh spot price immediately before syncing
    if @account.accountable_type == "Crypto"
      begin
        crypto = @account.accountable
        crypto.refresh_spot_price_now!
        # Invalidate cache used by CryptoPrice.current_price to reflect fresh value on page
        currency = @account.family.currency
        Rails.cache.delete("crypto_price_#{crypto.symbol}_#{currency}")

        # Si hay cantidad guardada, ajustar balance a cantidad * precio
        if crypto.quantity.present? && crypto.spot_price_cents.present?
          new_balance = crypto.quantity.to_d * (crypto.spot_price_cents.to_d / 100)
          @account.set_current_balance(new_balance)
        end
      rescue => e
        Rails.logger.warn("Failed to refresh crypto spot price: #{e.class} - #{e.message}")
      end
    end

    unless @account.syncing?
      @account.sync_later
    end

    redirect_to account_path(@account)
  end

  def sparkline
    etag_key = @account.family.build_cache_key("#{@account.id}_sparkline", invalidate_on_data_updates: true)

    # Short-circuit with 304 Not Modified when the client already has the latest version.
    # We defer the expensive series computation until we know the content is stale.
    if stale?(etag: etag_key, last_modified: @account.family.latest_sync_completed_at)
      @sparkline_series = @account.sparkline_series
      render layout: false
    end
  end

  def toggle_active
    if @account.active?
      @account.disable!
    elsif @account.disabled?
      @account.enable!
    end
    redirect_to accounts_path
  end

  def destroy
    if @account.linked?
      redirect_to account_path(@account), alert: "Cannot delete a linked account"
    else
      @account.destroy_later
      redirect_to accounts_path, notice: "Account scheduled for deletion"
    end
  end

  private
    def family
      Current.family
    end

    def set_account
      @account = family.accounts.find(params[:id])
    end
end
