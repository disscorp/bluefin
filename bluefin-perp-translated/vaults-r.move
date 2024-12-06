module bluefin::vaults {
    struct VaultStore has key {
        id: sui::object::UID,
        admin: address,
        vaults_bank_manger: address,
        vaults_bank_accounts: sui::vec_set::VecSet<address>,
        version: u64,
    }

    public fun set_vault_sub_account(
        sub_accounts: &mut bluefin::roles::SubAccountsV2,
        vault_store: &mut VaultStore,
        vault_bank_account: address,
        sub_account: address,
        status: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(vault_store.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(vault_store.admin == sui::tx_context::sender(ctx), bluefin::error::unauthorized());
        assert!(sui::vec_set::contains<address>(&vault_store.vaults_bank_accounts, &vault_bank_account), 
               bluefin::error::vault_does_not_belong_to_safe());

        bluefin::roles::set_vault_sub_account(sub_accounts, vault_bank_account, sub_account, status);
        bluefin::events::emit_vault_sub_account_event(
            sui::object::uid_to_inner(&vault_store.id),
            vault_bank_account,
            sub_account,
            status
        );
    }

    public fun create_vault_bank_account<CoinType>(
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sub_accounts: &mut bluefin::roles::SubAccountsV2,
        vault_store: &mut VaultStore,
        sub_account: address,
        ctx: &mut sui::tx_context::TxContext
    ) : address {
        assert!(vault_store.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(vault_store.admin == sui::tx_context::sender(ctx), bluefin::error::unauthorized());

        let new_uid = sui::object::new(ctx);
        let bank_account = sui::object::uid_to_address(&new_uid);
        
        sui::vec_set::insert<address>(&mut vault_store.vaults_bank_accounts, bank_account);
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), bank_account);
        bluefin::roles::set_vault_sub_account(sub_accounts, bank_account, sub_account, true);
        bluefin::events::emit_vault_bank_account_created_event(sui::object::uid_to_inner(&new_uid), bank_account);
        
        sui::object::delete(new_uid);
        bank_account
    }

    public fun create_vault_store(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        admin_address: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let vault_store = VaultStore {
            id: sui::object::new(ctx),
            admin: admin_address,
            vaults_bank_manger: admin_address,
            vaults_bank_accounts: sui::vec_set::empty<address>(),
            version: bluefin::roles::get_version(),
        };
        sui::transfer::share_object<VaultStore>(vault_store);
    }

    entry fun increment_vault_store_version(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        vault_store: &mut VaultStore
    ) {
        vault_store.version = vault_store.version + 1;
    }

    public fun set_admin(
        vault_store: &mut VaultStore,
        new_admin: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(vault_store.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(vault_store.admin == sui::tx_context::sender(ctx), bluefin::error::unauthorized());
        
        vault_store.admin = new_admin;
        bluefin::events::emit_vault_store_admin_udpdate_event(
            *sui::object::uid_as_inner(&vault_store.id),
            new_admin
        );
    }

    public fun set_vaults_bank_manger(
        vault_store: &mut VaultStore,
        new_manager: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(vault_store.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(vault_store.admin == sui::tx_context::sender(ctx), bluefin::error::unauthorized());
        
        vault_store.vaults_bank_manger = new_manager;
        bluefin::events::emit_vault_bank_manager_udpdate_event(
            *sui::object::uid_as_inner(&vault_store.id),
            new_manager
        );
    }

    public fun withdraw_coins_from_vault<CoinType>(
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        vault_store: &VaultStore,
        tx_bytes: vector<u8>,
        vault_account: address,
        amount: u128,
        ctx: &mut sui::tx_context::TxContext
    ) : sui::coin::Coin<CoinType> {
        assert!(vault_store.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(sui::vec_set::contains<address>(&vault_store.vaults_bank_accounts, &vault_account),
               bluefin::error::vault_does_not_belong_to_safe());
        assert!(vault_store.vaults_bank_manger == sui::tx_context::sender(ctx), bluefin::error::unauthorized());
        
        bluefin::margin_bank::withdraw_coins_from_bank_for_vault<CoinType>(
            bank,
            sequencer,
            tx_bytes,
            vault_account,
            amount,
            ctx
        )
    }
}