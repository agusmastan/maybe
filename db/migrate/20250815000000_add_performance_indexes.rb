class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    # 1. entries: composite index for the most common query pattern (account + type + date)
    # Used by: Entry.search, Account#show, Entry.chronological/reverse_chronological
    add_index :entries, [:account_id, :entryable_type, :date],
              name: "idx_entries_account_type_date",
              algorithm: :concurrently,
              if_not_exists: true

    # 2. syncs: composite index for stale sync cleanup and status queries
    # Used by: Sync.clean (WHERE status + created_at), Sync.visible
    add_index :syncs, [:status, :created_at],
              name: "idx_syncs_status_created_at",
              algorithm: :concurrently,
              if_not_exists: true

    # 3. entries: partial index for non-excluded entries (most queries filter excluded=false)
    add_index :entries, [:account_id, :date],
              name: "idx_entries_account_date_not_excluded",
              where: "excluded = false",
              algorithm: :concurrently,
              if_not_exists: true

    # 4. holdings: composite index for current_holdings query (DISTINCT ON security_id, date DESC)
    add_index :holdings, [:account_id, :currency, :security_id, :date],
              name: "idx_holdings_account_currency_security_date",
              order: { date: :desc },
              algorithm: :concurrently,
              if_not_exists: true
  end
end
