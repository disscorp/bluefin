module bluefin::roles {
    // Event structures for tracking role changes and operations
    struct ExchangeAdminUpdateEvent has copy, drop {
        account: address,
    }

    struct ExchangeGuardianUpdateEvent has copy, drop {
        id: sui::object::ID,
        account: address,
    }

    struct SettlementOperatorCreationEvent has copy, drop {
        id: sui::object::ID,
        account: address,
    }

    struct SettlementOperatorRemovalEvent has copy, drop {
        id: sui::object::ID,
    }

    struct DelevergingOperatorUpdate has copy, drop {
        id: sui::object::ID,
        account: address,
    }

    struct FundingRateOperatorUpdate has copy, drop {
        id: sui::object::ID,
        account: address,
    }

    struct SubAccountUpdateEvent has copy, drop {
        account: address,
        subAccount: address,
        status: bool,
    }

    struct SequencerCreationEvent has copy, drop {
        id: sui::object::ID,
    }

    // Capability structures for role-based access control
    struct ExchangeAdminCap has key {
        id: sui::object::UID,
    }

    struct ExchangeGuardianCap has key {
        id: sui::object::UID,
    }

    struct SettlementCap has key {
        id: sui::object::UID,
    }

    struct DeleveragingCap has key {
        id: sui::object::UID,
    }

    struct FundingRateCap has key {
        id: sui::object::UID,
    }

    // Main storage structures
    struct CapabilitiesSafe has key {
        id: sui::object::UID,
        guardian: sui::object::ID,
        deleveraging: sui::object::ID,
        fundingRateOperator: sui::object::ID,
        publicSettlementCap: sui::object::ID,
        settlementOperators: sui::vec_set::VecSet<sui::object::ID>,
    }

    struct SubAccounts has key {
        id: sui::object::UID,
        map: sui::table::Table<address, sui::vec_set::VecSet<address>>,
    }

    struct CapabilitiesSafeV2 has key {
        id: sui::object::UID,
        version: u64,
        guardian: sui::object::ID,
        deleveraging: sui::object::ID,
        fundingRateOperator: sui::object::ID,
        publicSettlementCap: sui::object::ID,
        settlementOperators: sui::vec_set::VecSet<sui::object::ID>,
    }

    struct SubAccountsV2 has key {
        id: sui::object::UID,
        version: u64,
        map: sui::table::Table<address, sui::vec_set::VecSet<address>>,
    }

    struct Sequencer has key {
        id: sui::object::UID,
        version: u64,
        counter: u128,
        map: sui::table::Table<vector<u8>, bool>,
    }

    public fun check_delevearging_operator_validity(safe: &CapabilitiesSafe, cap: &DeleveragingCap) {
        abort bluefin::error::method_depricated()
    }

    // Operator validation functions
    public fun check_delevearging_operator_validity_v2(safe: &CapabilitiesSafeV2, cap: &DeleveragingCap) {
        assert!(safe.deleveraging == sui::object::uid_to_inner(&cap.id), bluefin::error::invalid_deleveraging_operator());
    }

    public fun check_funding_rate_operator_validity(safe: &CapabilitiesSafe, cap: &FundingRateCap) {
        abort bluefin::error::method_depricated()
    }

    public fun check_funding_rate_operator_validity_v2(safe: &CapabilitiesSafeV2, cap: &FundingRateCap) {
        assert!(safe.fundingRateOperator == sui::object::uid_to_inner(&cap.id), bluefin::error::invalid_funding_rate_operator());
    }

    public fun check_guardian_validity(safe: &CapabilitiesSafe, cap: &ExchangeGuardianCap) {
        abort bluefin::error::method_depricated()
    }

    public fun check_guardian_validity_v2(safe: &CapabilitiesSafeV2, cap: &ExchangeGuardianCap) {
        assert!(safe.guardian == sui::object::uid_to_inner(&cap.id), bluefin::error::invalid_guardian());
    }

    public fun check_public_settlement_cap_validity(safe: &CapabilitiesSafe, cap: &SettlementCap) {
        abort bluefin::error::method_depricated()
    }

    public fun check_public_settlement_cap_validity_v2(safe: &CapabilitiesSafeV2, cap: &SettlementCap) {
        assert!(safe.publicSettlementCap == sui::object::uid_to_inner(&cap.id), bluefin::error::not_a_public_settlement_cap());
    }

    public fun check_settlement_operator_validity(safe: &CapabilitiesSafe, cap: &SettlementCap) {
        abort bluefin::error::method_depricated()
    }

    public fun check_settlement_operator_validity_v2(safe: &CapabilitiesSafeV2, cap: &SettlementCap) {
        let operator_id = sui::object::id<SettlementCap>(cap);
        assert!(sui::vec_set::contains<sui::object::ID>(&safe.settlementOperators, &operator_id), bluefin::error::invalid_settlement_operator());
    }

    // Creation functions
    fun create_deleveraging_operator(operator_addr: address, ctx: &mut sui::tx_context::TxContext) : sui::object::ID {
        let new_id = sui::object::new(ctx);
        let inner_id = sui::object::uid_to_inner(&new_id);
        let cap = DeleveragingCap{id: new_id};
        sui::transfer::transfer<DeleveragingCap>(cap, operator_addr);
        
        let update_event = DelevergingOperatorUpdate{
            id: inner_id,
            account: operator_addr,
        };
        sui::event::emit<DelevergingOperatorUpdate>(update_event);
        inner_id
    }

    fun create_exchange_admin(ctx: &mut sui::tx_context::TxContext) {
        let cap = ExchangeAdminCap{id: sui::object::new(ctx)};
        let sender = sui::tx_context::sender(ctx);
        sui::transfer::transfer<ExchangeAdminCap>(cap, sender);
        
        let update_event = ExchangeAdminUpdateEvent{account: sender};
        sui::event::emit<ExchangeAdminUpdateEvent>(update_event);
    }

    fun create_exchange_guardian(guardian_addr: address, ctx: &mut sui::tx_context::TxContext) : sui::object::ID {
        let new_id = sui::object::new(ctx);
        let inner_id = sui::object::uid_to_inner(&new_id);
        let guardian_cap = ExchangeGuardianCap{id: new_id};
        sui::transfer::transfer<ExchangeGuardianCap>(guardian_cap, guardian_addr);
        
        let update_event = ExchangeGuardianUpdateEvent{
            id: inner_id,
            account: guardian_addr,
        };
        sui::event::emit<ExchangeGuardianUpdateEvent>(update_event);
        inner_id
    }

    fun create_funding_rate_operator(operator_addr: address, ctx: &mut sui::tx_context::TxContext) : sui::object::ID {
        let new_id = sui::object::new(ctx);
        let inner_id = sui::object::uid_to_inner(&new_id);
        let cap = FundingRateCap{id: new_id};
        sui::transfer::transfer<FundingRateCap>(cap, operator_addr);
        
        let update_event = FundingRateOperatorUpdate{
            id: inner_id,
            account: operator_addr,
        };
        sui::event::emit<FundingRateOperatorUpdate>(update_event);
        inner_id
    }

    entry fun create_sequencer(admin_cap: &ExchangeAdminCap, ctx: &mut sui::tx_context::TxContext) {
        let sequencer = Sequencer{
            id: sui::object::new(ctx),
            version: get_version(),
            counter: 0,
            map: sui::table::new<vector<u8>, bool>(ctx),
        };
        let creation_event = SequencerCreationEvent{id: sui::object::uid_to_inner(&sequencer.id)};
        sui::event::emit<SequencerCreationEvent>(creation_event);
        sui::transfer::share_object<Sequencer>(sequencer);
    }

    entry fun create_settlement_operator(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        operator_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        validate_safe_version(capabilities_safe);
        let settlement_cap = SettlementCap{id: sui::object::new(ctx)};
        let creation_event = SettlementOperatorCreationEvent{
            id: sui::object::uid_to_inner(&settlement_cap.id),
            account: operator_addr,
        };
        sui::event::emit<SettlementOperatorCreationEvent>(creation_event);
        sui::vec_set::insert<sui::object::ID>(&mut capabilities_safe.settlementOperators, sui::object::uid_to_inner(&settlement_cap.id));
        sui::transfer::transfer<SettlementCap>(settlement_cap, operator_addr);
    }

    public fun get_version() : u64 {
        4
    }

    entry fun increment_safe_version(admin_cap: &ExchangeAdminCap, safe: &mut CapabilitiesSafeV2) {
        safe.version = safe.version + 1;
    }

    entry fun increment_sequencer_version(admin_cap: &ExchangeAdminCap, sequencer: &mut Sequencer) {
        sequencer.version = sequencer.version + 1;
    }

    entry fun increment_sub_account_version(admin_cap: &ExchangeAdminCap, sub_accounts: &mut SubAccountsV2) {
        sub_accounts.version = sub_accounts.version + 1;
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        create_exchange_admin(ctx);
        
        let settlement_id = sui::object::new(ctx);
        let public_settlement_cap = SettlementCap{id: settlement_id};
        sui::transfer::share_object<SettlementCap>(public_settlement_cap);

        let sender = sui::tx_context::sender(ctx);
        let capabilities_safe = CapabilitiesSafeV2{
            id: sui::object::new(ctx),
            version: get_version(),
            guardian: create_exchange_guardian(sender, ctx),
            deleveraging: create_deleveraging_operator(sender, ctx),
            fundingRateOperator: create_funding_rate_operator(sender, ctx),
            publicSettlementCap: sui::object::uid_to_inner(&settlement_id),
            settlementOperators: sui::vec_set::empty<sui::object::ID>(),
        };
        sui::transfer::share_object<CapabilitiesSafeV2>(capabilities_safe);

        let sub_accounts = SubAccountsV2{
            id: sui::object::new(ctx),
            version: get_version(),
            map: sui::table::new<address, sui::vec_set::VecSet<address>>(ctx),
        };
        sui::transfer::share_object<SubAccountsV2>(sub_accounts);

        let sequencer = Sequencer{
            id: sui::object::new(ctx),
            version: get_version(),
            counter: 0,
            map: sui::table::new<vector<u8>, bool>(ctx),
        };
        sui::transfer::share_object<Sequencer>(sequencer);
    }

    public fun is_sub_account(sub_accounts: &SubAccounts, main_account: address, sub_account: address) : bool {
        abort bluefin::error::method_depricated()
    }

    public fun is_sub_account_v2(sub_accounts: &SubAccountsV2, main_account: address, sub_account: address) : bool {
        let accounts_map = &sub_accounts.map;
        if (!sui::table::contains<address, sui::vec_set::VecSet<address>>(accounts_map, main_account)) {
            return false
        };
        sui::vec_set::contains<address>(
            sui::table::borrow<address, sui::vec_set::VecSet<address>>(accounts_map, main_account),
            &sub_account
        )
    }

    entry fun remove_settlement_operator(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        operator_id: sui::object::ID
    ) {
        validate_safe_version(capabilities_safe);
        assert!(sui::vec_set::contains<sui::object::ID>(&capabilities_safe.settlementOperators, &operator_id), 
               bluefin::error::operator_already_removed());
        sui::vec_set::remove<sui::object::ID>(&mut capabilities_safe.settlementOperators, &operator_id);
        sui::event::emit<SettlementOperatorRemovalEvent>(SettlementOperatorRemovalEvent{id: operator_id});
    }

    public entry fun set_deleveraging_operator(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafe,
        operator_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        abort bluefin::error::method_depricated()
    }

    public entry fun set_deleveraging_operator_v2(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        operator_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        validate_safe_version(capabilities_safe);
        capabilities_safe.deleveraging = create_deleveraging_operator(operator_addr, ctx);
    }

    entry fun set_exchange_admin(
        admin_cap: ExchangeAdminCap,
        new_admin: address,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(new_admin != sui::tx_context::sender(ctx), 
               bluefin::error::new_address_can_not_be_same_as_current_one());
        sui::transfer::transfer<ExchangeAdminCap>(admin_cap, new_admin);
        sui::event::emit<ExchangeAdminUpdateEvent>(ExchangeAdminUpdateEvent{account: new_admin});
    }

    entry fun set_exchange_guardian(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        guardian_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        validate_safe_version(capabilities_safe);
        capabilities_safe.guardian = create_exchange_guardian(guardian_addr, ctx);
    }

    public entry fun set_funding_rate_operator(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        operator_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        abort bluefin::error::method_depricated()
    }

    public entry fun set_funding_rate_operator_v2(
        admin_cap: &ExchangeAdminCap,
        capabilities_safe: &mut CapabilitiesSafeV2,
        operator_addr: address,
        ctx: &mut sui::tx_context::TxContext
    ) {
        validate_safe_version(capabilities_safe);
        capabilities_safe.fundingRateOperator = create_funding_rate_operator(operator_addr, ctx);
    }

    public entry fun set_sub_account(
        sub_accounts: &mut SubAccountsV2,
        sub_account: address,
        status: bool,
        ctx: &mut sui::tx_context::TxContext
    ) {
        validate_sub_accounts_version(sub_accounts);
        let sender = sui::tx_context::sender(ctx);
        let accounts_map = &mut sub_accounts.map;
        
        if (!sui::table::contains<address, sui::vec_set::VecSet<address>>(accounts_map, sender)) {
            sui::table::add<address, sui::vec_set::VecSet<address>>(accounts_map, sender, sui::vec_set::empty<address>());
        };
        
        let sub_accounts_set = sui::table::borrow_mut<address, sui::vec_set::VecSet<address>>(accounts_map, sender);
        if (status) {
            if (!sui::vec_set::contains<address>(sub_accounts_set, &sub_account)) {
                sui::vec_set::insert<address>(sub_accounts_set, sub_account);
            };
        } else {
            if (sui::vec_set::contains<address>(sub_accounts_set, &sub_account)) {
                sui::vec_set::remove<address>(sub_accounts_set, &sub_account);
            };
        };
        
        sui::event::emit<SubAccountUpdateEvent>(SubAccountUpdateEvent{
            account: sender,
            subAccount: sub_account,
            status: status,
        });
    }

    public(friend) fun set_vault_sub_account(
        sub_accounts: &mut SubAccountsV2,
        vault_account: address,
        sub_account: address,
        status: bool
    ) {
        validate_sub_accounts_version(sub_accounts);
        let accounts_map = &mut sub_accounts.map;
        
        if (!sui::table::contains<address, sui::vec_set::VecSet<address>>(accounts_map, vault_account)) {
            sui::table::add<address, sui::vec_set::VecSet<address>>(accounts_map, vault_account, sui::vec_set::empty<address>());
        };
        
        let sub_accounts_set = sui::table::borrow_mut<address, sui::vec_set::VecSet<address>>(accounts_map, vault_account);
        if (status) {
            if (!sui::vec_set::contains<address>(sub_accounts_set, &sub_account)) {
                sui::vec_set::insert<address>(sub_accounts_set, sub_account);
            };
        } else {
            if (sui::vec_set::contains<address>(sub_accounts_set, &sub_account)) {
                sui::vec_set::remove<address>(sub_accounts_set, &sub_account);
            };
        };
        
        sui::event::emit<SubAccountUpdateEvent>(SubAccountUpdateEvent{
            account: vault_account,
            subAccount: sub_account,
            status: status,
        });
    }
    
    // Version validation functions
    public fun validate_safe_version(safe: &CapabilitiesSafeV2) {
        assert!(safe.version == get_version(), bluefin::error::object_version_mismatch());
    }

    public fun validate_sequencer_version(sequencer: &Sequencer) {
        assert!(sequencer.version == get_version(), bluefin::error::object_version_mismatch());
    }

    public fun validate_sub_accounts_version(sub_accounts: &SubAccountsV2) {
        assert!(sub_accounts.version == get_version(), bluefin::error::object_version_mismatch());
    }

    public fun validate_unique_tx(sequencer: &mut Sequencer, tx_bytes: vector<u8>) : u128 { 
        abort bluefin::error::method_depricated() 
    }

    public(friend) fun validate_unique_tx_v2(sequencer: &mut Sequencer, tx_bytes: vector<u8>) : u128 {
        validate_sequencer_version(sequencer);
        assert!(!sui::table::contains<vector<u8>, bool>(&sequencer.map, tx_bytes), bluefin::error::transaction_replay());
        sui::table::add<vector<u8>, bool>(&mut sequencer.map, tx_bytes, true);
        sequencer.counter = sequencer.counter + 1;
        sequencer.counter
    }
}