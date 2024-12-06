module bluefin::margin_bank {
    struct BankBalanceUpdate has copy, drop {
        action: u64,
        srcAddress: address,
        destAddress: address,
        amount: u128,
        srcBalance: u128,
        destBalance: u128,
    }
    
    struct BankBalanceUpdateV2 has copy, drop {
        tx_index: u128,
        action: u64,
        srcAddress: address,
        destAddress: address,
        amount: u128,
        srcBalance: u128,
        destBalance: u128,
    }
    
    struct WithdrawalStatusUpdate has copy, drop {
        status: bool,
    }
    
    struct BankAccount has store {
        balance: u128,
        owner: address,
    }
    
    struct Bank<phantom T0> has store, key {
        id: sui::object::UID,
        accounts: sui::table::Table<address, BankAccount>,
        coinBalance: sui::balance::Balance<T0>,
        isWithdrawalAllowed: bool,
        supportedCoin: std::string::String,
    }
    
    struct BankV2<phantom T0> has store, key {
        id: sui::object::UID,
        version: u64,
        accounts: sui::table::Table<address, BankAccount>,
        coinBalance: sui::balance::Balance<T0>,
        isWithdrawalAllowed: bool,
        supportedCoin: std::string::String,
    }
    
    public fun get_version<CoinType>(bank: &BankV2<CoinType>) : u64 {
        bank.version
    }
    
    public entry fun create_bank<CoinType>(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        coin_name: std::string::String,
        ctx: &mut sui::tx_context::TxContext
    ) {
        let bank = BankV2<CoinType>{
            id: sui::object::new(ctx),
            version: bluefin::roles::get_version(),
            accounts: sui::table::new<address, BankAccount>(ctx),
            coin_balance: sui::balance::zero<CoinType>(),
            is_withdrawal_allowed: true,
            supported_coin: coin_name,
        };
        sui::transfer::share_object<BankV2<CoinType>>(bank);
    }
    
    public entry fun deposit_to_bank<CoinType>(
        bank: &mut BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        tx_data: vector<u8>,
        destination: address,
        amount: u64,
        coin: &mut sui::coin::Coin<CoinType>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let sender = sui::tx_context::sender(ctx);
        let accounts = &mut bank.accounts;

        initialize_account(accounts, destination);
        initialize_account(accounts, sender);

        assert!(amount <= sui::coin::value<CoinType>(coin), bluefin::error::coin_does_not_have_enough_amount());
        
        sui::coin::put<CoinType>(&mut bank.coin_balance, sui::coin::take<CoinType>(sui::coin::balance_mut<CoinType>(coin), amount, ctx));
        
        let dest_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, destination).balance;
        let base_amount = bluefin::library::convert_usdc_to_base_decimals((amount as u128));
        *dest_balance = base_amount + *dest_balance;

        let event = BankBalanceUpdateV2{
            tx_index: bluefin::roles::validate_unique_tx_v2(sequencer, tx_data),
            action: 0,
            source_address: sender,
            destination_address: destination,
            amount: base_amount,
            source_balance: sui::table::borrow<address, BankAccount>(accounts, sender).balance,
            destination_balance: sui::table::borrow<address, BankAccount>(accounts, destination).balance,
        };
        sui::event::emit<BankBalanceUpdateV2>(event);
    }
    
    public fun get_balance<CoinType>(bank: &Bank<CoinType>, account: address) : u128 {
        0
    }
    
    public fun get_balance_v2<CoinType>(bank: &BankV2<CoinType>, account: address) : u128 {
        let accounts = &bank.accounts;
        if (!sui::table::contains<address, BankAccount>(accounts, account)) {
            return 0
        };
        sui::table::borrow<address, BankAccount>(accounts, account).balance
    }
    
    public fun get_bank_id<CoinType>(bank: &BankV2<CoinType>) : sui::object::ID {
        sui::object::uid_to_inner(&bank.id)
    }

    entry fun increment_bank_version<CoinType>(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        bank: &mut BankV2<CoinType>
    ) {
        bank.version = bank.version + 1;
    }
    
    public(friend) fun initialize_account(
        accounts: &mut sui::table::Table<address, BankAccount>,
        owner: address
    ) {
        if (!sui::table::contains<address, BankAccount>(accounts, owner)) {
            let account = BankAccount{
                balance: 0,
                owner,
            };
            sui::table::add<address, BankAccount>(accounts, owner, account);
        };
    }

    
    public fun is_withdrawal_allowed<CoinType>(bank: &Bank<CoinType>) : bool {
        false
    }

    public fun is_withdrawal_allowed_v2<CoinType>(bank: &BankV2<CoinType>) : bool {
        bank.isWithdrawalAllowed
    }
    
    public(friend) fun mut_accounts<CoinType>(bank: &mut Bank<CoinType>) : &mut sui::table::Table<address, BankAccount> {
        &mut bank.accounts
    }

    public(friend) fun mut_accounts_v2<CoinType>(bank: &mut BankV2<CoinType>) : &mut sui::table::Table<address, BankAccount> {
        &mut bank.accounts
    }
    
    public entry fun set_withdrawal_status<CoinType>(
        capabilities: &bluefin::roles::CapabilitiesSafe,
        guardian_cap: &bluefin::roles::ExchangeGuardianCap,
        bank: &mut Bank<CoinType>,
        status: bool
    ) {
    }

    public entry fun set_withdrawal_status_v2<CoinType>(
        capabilities: &bluefin::roles::CapabilitiesSafeV2,
        guardian_cap: &bluefin::roles::ExchangeGuardianCap,
        bank: &mut BankV2<CoinType>,
        status: bool
    ) {
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_safe_version(capabilities);
        bluefin::roles::check_guardian_validity_v2(capabilities, guardian_cap);
        bank.isWithdrawalAllowed = status;
        let event = WithdrawalStatusUpdate{status};
        sui::event::emit<WithdrawalStatusUpdate>(event);
    }
    
    fun transfer_based_on_fundsflow<CoinType>(
        bank: &mut BankV2<CoinType>,
        source: address,
        destination: address,
        amount: bluefin::signed_number::Number,
        action_type: u64,
        tx_index: u128
    ) {
        if (bluefin::signed_number::value(amount) == 0) {
            return
        };
        let (transfer_from, action, transfer_to) = if (bluefin::signed_number::gt_uint(amount, 0)) {
            (source, action_type, destination)
        } else {
            (destination, 2, source)
        };
        transfer_margin_to_account_v2<CoinType>(bank, transfer_to, transfer_from, bluefin::signed_number::value(amount), action, tx_index);
    }
    
    public(friend) fun transfer_margin_to_account<CoinType>(
        bank: &mut Bank<CoinType>,
        source: address,
        destination: address,
        amount: u128,
        error_offset: u64
    ) {
        let accounts = &mut bank.accounts;
        let source_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, source).balance;
        assert!(*source_balance >= amount, bluefin::error::not_enough_balance_in_margin_bank(error_offset));
        *source_balance = *source_balance - amount;
        let dest_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, destination).balance;
        *dest_balance = *dest_balance + (amount as u128);
        
        let event = BankBalanceUpdate{
            action: 2,
            srcAddress: source,
            destAddress: destination,
            amount,
            srcBalance: sui::table::borrow<address, BankAccount>(accounts, source).balance,
            destBalance: sui::table::borrow<address, BankAccount>(accounts, destination).balance,
        };
        sui::event::emit<BankBalanceUpdate>(event);
    }
    
    public(friend) fun transfer_margin_to_account_v2<CoinType>(
        bank: &mut BankV2<CoinType>,
        source: address,
        destination: address,
        amount: u128,
        error_offset: u64,
        tx_index: u128
    ) {
        let accounts = &mut bank.accounts;
        let source_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, source).balance;
        assert!(*source_balance >= amount, bluefin::error::not_enough_balance_in_margin_bank(error_offset));
        *source_balance = *source_balance - amount;
        let dest_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, destination).balance;
        *dest_balance = *dest_balance + (amount as u128);
        
        let event = BankBalanceUpdateV2{
            tx_index,
            action: 2,
            srcAddress: source,
            destAddress: destination,
            amount,
            srcBalance: sui::table::borrow<address, BankAccount>(accounts, source).balance,
            destBalance: sui::table::borrow<address, BankAccount>(accounts, destination).balance,
        };
        sui::event::emit<BankBalanceUpdateV2>(event);
    }
    
    public(friend) fun transfer_trade_margin<CoinType>(
        bank: &mut BankV2<CoinType>,
        trader: address,
        maker: address,
        taker: address,
        maker_funds: bluefin::signed_number::Number,
        taker_funds: bluefin::signed_number::Number,
        tx_index: u128
    ) {
        assert!(sui::table::contains<address, BankAccount>(&bank.accounts, maker), bluefin::error::not_enough_balance_in_margin_bank(0));
        assert!(sui::table::contains<address, BankAccount>(&bank.accounts, taker), bluefin::error::not_enough_balance_in_margin_bank(1));
        
        if (bluefin::signed_number::gte_uint(maker_funds, 0)) {
            transfer_based_on_fundsflow<CoinType>(bank, trader, maker, maker_funds, 0, tx_index);
            transfer_based_on_fundsflow<CoinType>(bank, trader, taker, taker_funds, 1, tx_index);
        } else {
            transfer_based_on_fundsflow<CoinType>(bank, trader, taker, taker_funds, 1, tx_index);
            transfer_based_on_fundsflow<CoinType>(bank, trader, maker, maker_funds, 0, tx_index);
        };
    }
    
    public entry fun withdraw_all_margin_from_bank<CoinType>(
        bank: &mut BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        tx_data: vector<u8>,
        recipient: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let sender = sui::tx_context::sender(ctx);
        assert!(bank.isWithdrawalAllowed, bluefin::error::withdrawal_is_not_allowed());
        
        let accounts = &mut bank.accounts;
        assert!(sui::table::contains<address, BankAccount>(accounts, sender), bluefin::error::user_has_no_bank_account());
        
        let user_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, sender).balance;
        if (*user_balance == 0) {
            return
        };
        
        let withdraw_amount = *user_balance / 1000;
        sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
            sui::coin::take<CoinType>(&mut bank.coinBalance, (withdraw_amount as u64), ctx),
            recipient
        );
        *user_balance = 0;

        let event = BankBalanceUpdateV2{
            tx_index: bluefin::roles::validate_unique_tx_v2(sequencer, tx_data),
            action: 1,
            srcAddress: sender,
            destAddress: recipient,
            amount: withdraw_amount * 1000,
            srcBalance: sui::table::borrow<address, BankAccount>(accounts, sender).balance,
            destBalance: sui::table::borrow<address, BankAccount>(accounts, recipient).balance,
        };
        sui::event::emit<BankBalanceUpdateV2>(event);
    }
    
    public(friend) fun withdraw_coins_from_bank_for_vault<CoinType>(
        bank: &mut BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        tx_data: vector<u8>,
        vault_address: address,
        amount: u128,
        ctx: &mut sui::tx_context::TxContext
    ) : sui::coin::Coin<CoinType> {
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bank.isWithdrawalAllowed, bluefin::error::withdrawal_is_not_allowed());
        
        let accounts = &mut bank.accounts;
        let base_amount = bluefin::library::convert_usdc_to_base_decimals(amount);
        let vault_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, vault_address).balance;
        
        assert!(*vault_balance >= base_amount, bluefin::error::not_enough_balance_in_margin_bank(3));
        *vault_balance = *vault_balance - base_amount;

        let event = BankBalanceUpdateV2{
            tx_index: bluefin::roles::validate_unique_tx_v2(sequencer, tx_data),
            action: 1,
            srcAddress: vault_address,
            destAddress: vault_address,
            amount: base_amount,
            srcBalance: sui::table::borrow<address, BankAccount>(accounts, vault_address).balance,
            destBalance: sui::table::borrow<address, BankAccount>(accounts, vault_address).balance,
        };
        sui::event::emit<BankBalanceUpdateV2>(event);
        sui::coin::take<CoinType>(&mut bank.coinBalance, (amount as u64), ctx)
    }
    
    public entry fun withdraw_from_bank<CoinType>(
        bank: &mut BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        tx_data: vector<u8>,
        recipient: address,
        amount: u128,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let sender = sui::tx_context::sender(ctx);
        assert!(bank.isWithdrawalAllowed, bluefin::error::withdrawal_is_not_allowed());
        
        let accounts = &mut bank.accounts;
        assert!(sui::table::contains<address, BankAccount>(accounts, sender), bluefin::error::user_has_no_bank_account());
        
        let base_amount = bluefin::library::convert_usdc_to_base_decimals(amount);
        let user_balance = &mut sui::table::borrow_mut<address, BankAccount>(accounts, sender).balance;
        assert!(*user_balance >= base_amount, bluefin::error::not_enough_balance_in_margin_bank(3));
        *user_balance = *user_balance - base_amount;

        sui::transfer::public_transfer<sui::coin::Coin<CoinType>>(
            sui::coin::take<CoinType>(&mut bank.coinBalance, (amount as u64), ctx),
            recipient
        );

        let event = BankBalanceUpdateV2{
            tx_index: bluefin::roles::validate_unique_tx_v2(sequencer, tx_data),
            action: 1,
            srcAddress: sender,
            destAddress: recipient,
            amount: base_amount,
            srcBalance: sui::table::borrow<address, BankAccount>(accounts, sender).balance,
            destBalance: sui::table::borrow<address, BankAccount>(accounts, recipient).balance,
        };
        sui::event::emit<BankBalanceUpdateV2>(event);
    }
}

