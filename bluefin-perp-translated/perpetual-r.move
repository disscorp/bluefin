module bluefin::perpetual {
    struct PerpetualCreationEvent has copy, drop {
        id: sui::object::ID,
        name: std::string::String,
        imr: u128,
        mmr: u128,
        maker_fee: u128,
        taker_fee: u128,
        insurance_pool_ratio: u128,
        insurance_pool: address,
        fee_pool: address,
        checks: bluefin::evaluator::TradeChecks,
        funding: bluefin::funding_rate::FundingRate,
    }
    
    struct InsurancePoolRatioUpdateEvent has copy, drop {
        id: sui::object::ID,
        ratio: u128,
    }
    
    struct InsurancePoolAccountUpdateEvent has copy, drop {
        id: sui::object::ID,
        account: address,
    }
    
    struct FeePoolAccountUpdateEvent has copy, drop {
        id: sui::object::ID,
        account: address,
    }
    
    struct DelistEvent has copy, drop {
        id: sui::object::ID,
        delistingPrice: u128,
    }
    
    struct TradingPermissionStatusUpdate has copy, drop {
        status: bool,
    }
    
    struct MMRUpdateEvent has copy, drop {
        id: sui::object::ID,
        mmr: u128,
    }
    
    struct IMRUpdateEvent has copy, drop {
        id: sui::object::ID,
        imr: u128,
    }
    
    struct SpecialFeeEvent has copy, drop {
        perp: sui::object::ID,
        account: address,
        status: bool,
        makerFee: u128,
        takerFee: u128,
    }
    
    struct PriceOracleIdentifierUpdateEvent has copy, drop {
        perp: sui::object::ID,
        identifier: vector<u8>,
    }
    
    struct MakerFeeUpdateEvent has copy, drop {
        perp: sui::object::ID,
        makerFee: u128,
    }
    
    struct TakerFeeUpdateEvent has copy, drop {
        perp: sui::object::ID,
        takerFee: u128,
    }
    
    struct PriceFeedUpdateEvent has copy, drop {
        perp: sui::object::ID,
        price_feed: vector<u8>,
    }
    
    struct PerpetualNameUpdateEvent has copy, drop {
        perp: sui::object::ID,
        name: std::string::String,
    }
    
    struct Perpetual has store, key {
        id: sui::object::UID,
        name: std::string::String,
        imr: u128,
        mmr: u128,
        makerFee: u128,
        takerFee: u128,
        insurancePoolRatio: u128,
        insurancePool: address,
        feePool: address,
        delisted: bool,
        delistingPrice: u128,
        isTradingPermitted: bool,
        startTime: u64,
        checks: bluefin::evaluator::TradeChecks,
        positions: sui::table::Table<address, bluefin::position::UserPosition>,
        specialFee: sui::table::Table<address, SpecialFee>,
        priceOracle: u128,
        funding: bluefin::funding_rate::FundingRate,
        priceIdentifierId: vector<u8>,
    }
    
    struct PerpetualV2 has key {
        id: sui::object::UID,
        version: u64,
        name: std::string::String,
        imr: u128, // Initial Margin Requirement
        mmr: u128, // Maintenance Margin Requirement
        maker_fee: u128,
        taker_fee: u128,
        insurance_pool_ratio: u128,
        insurance_pool: address,
        fee_pool: address,
        delisted: bool,
        delisting_price: u128,
        is_trading_permitted: bool,
        start_time: u64,
        checks: bluefin::evaluator::TradeChecks,
        positions: sui::table::Table<address, bluefin::position::UserPosition>,
        special_fee: sui::table::Table<address, SpecialFee>,
        price_oracle: u128,
        funding: bluefin::funding_rate::FundingRate,
        price_identifier_id: vector<u8>,
    }
    
    struct SpecialFee has copy, drop, store {
        status: bool,
        makerFee: u128,
        takerFee: u128,
    }
    
    public(friend) fun initialize(
        name: vector<u8>,
        initial_margin_ratio: u128,
        maintenance_margin_ratio: u128,
        maker_fee: u128,
        taker_fee: u128,
        insurance_ratio: u128,
        insurance_addr: address,
        fee_addr: address,
        min_price: u128,
        max_price: u128,
        tick_size: u128,
        min_qty: u128,
        max_qty_limit: u128,
        max_qty_market: u128,
        step_size: u128,
        mtb_long: u128,
        mtb_short: u128,
        start_timestamp: u64,
        max_oi_open: vector<u128>,
        price_feed_id: vector<u8>,
        ctx: &mut sui::tx_context::TxContext
    ) : sui::object::ID {
        let perp_uid = sui::object::new(ctx);
        let perp_id = sui::object::uid_to_inner(&perp_uid);
        
        let trade_checks = bluefin::evaluator::initialize(
            min_price, max_price, tick_size, min_qty, 
            max_qty_limit, max_qty_market, step_size,
            mtb_long, mtb_short, max_oi_open
        );
        
        let funding_rate = bluefin::funding_rate::initialize(start_timestamp, mtb_short);
        
        assert!(maintenance_margin_ratio > 0, bluefin::error::maintenance_margin_must_be_greater_than_zero());
        assert!(maintenance_margin_ratio <= initial_margin_ratio, 
            bluefin::error::maintenance_margin_must_be_less_than_or_equal_to_imr());

        let perpetual = PerpetualV2{
            id: perp_uid,
            version: bluefin::roles::get_version(),
            name: std::string::utf8(name),
            imr: initial_margin_ratio,
            mmr: maintenance_margin_ratio,
            maker_fee,
            taker_fee,
            insurance_pool_ratio: insurance_ratio,
            insurance_pool: insurance_addr,
            fee_pool: fee_addr,
            delisted: false,
            delisting_price: 0,
            is_trading_permitted: true,
            start_time: start_timestamp,
            checks: trade_checks,
            positions: sui::table::new<address, bluefin::position::UserPosition>(ctx),
            special_fee: sui::table::new<address, SpecialFee>(ctx),
            price_oracle: 0,
            funding: funding_rate,
            price_identifier_id: price_feed_id,
        };

        let creation_event = PerpetualCreationEvent{
            id: perp_id,
            name: perpetual.name,
            imr: initial_margin_ratio,
            mmr: maintenance_margin_ratio,
            maker_fee,
            taker_fee,
            insurance_pool_ratio: insurance_ratio,
            insurance_pool: insurance_addr,
            fee_pool: fee_addr,
            checks: trade_checks,
            funding: funding_rate,
        };

        sui::event::emit<PerpetualCreationEvent>(creation_event);
        sui::transfer::share_object<PerpetualV2>(perpetual);
        perp_id
    }
    
    public entry fun set_max_oi_open(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: vector<u128>) {
    }
    
    public entry fun set_max_price(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_max_qty_limit(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_max_qty_market(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_min_price(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_min_qty(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_mtb_long(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_mtb_short(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_step_size(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_tick_size(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_funding_rate(arg0: &sui::clock::Clock, arg1: &bluefin::roles::CapabilitiesSafe, arg2: &bluefin::roles::FundingRateCap, arg3: &mut Perpetual, arg4: u128, arg5: bool, arg6: &pyth_network::price_info::PriceInfoObject) {
    }
    
    public entry fun set_max_allowed_funding_rate(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    entry fun remove_empty_positions(
        safe_cap: &bluefin::roles::CapabilitiesSafeV2,
        guardian_cap: &bluefin::roles::ExchangeGuardianCap,
        clock: &sui::clock::Clock,
        perp: &mut PerpetualV2,
        accounts: vector<address>
    ) {
        bluefin::roles::validate_safe_version(safe_cap);
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::check_guardian_validity_v2(safe_cap, guardian_cap);
        bluefin::position::remove_empty_positions(positions(perp), accounts, sui::clock::timestamp_ms(clock));
    }

    public fun get_version(perp: &PerpetualV2) : u64 {
        perp.version
    }

    public fun checks(perp: &Perpetual) : bluefin::evaluator::TradeChecks {
        perp.checks
    }

    public fun checks_v2(perp: &PerpetualV2) : bluefin::evaluator::TradeChecks {
        perp.checks
    }
    
    public entry fun delist_perpetual(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun delist_perpetual_v2(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut PerpetualV2, arg2: u128) {
        assert!(arg1.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let v0 = arg2 / bluefin::library::base_uint();
        assert!(!arg1.delisted, bluefin::error::perpetual_has_been_already_de_listed());
        bluefin::evaluator::verify_price_checks(arg1.checks, v0);
        arg1.delisted = true;
        arg1.delistingPrice = v0;
        let v1 = DelistEvent{
            id             : sui::object::uid_to_inner(id_v2(arg1)), 
            delistingPrice : v0,
        };
        sui::event::emit<DelistEvent>(v1);
    }
    
    public fun delisted(perp: &Perpetual) : bool {
        perp.delisted
    }

    public fun delisted_v2(perp: &PerpetualV2) : bool {
        perp.delisted
    }

    public fun delistingPrice(perp: &Perpetual) : u128 {
        perp.delistingPrice
    }

    public fun delistingPrice_v2(perp: &PerpetualV2) : u128 {
        perp.delistingPrice
    }

    public fun feePool(perp: &Perpetual) : address {
        perp.feePool
    }

    public fun feePool_v2(perp: &PerpetualV2) : address {
        perp.feePool
    }

    public fun fundingRate(perp: &Perpetual) : bluefin::funding_rate::FundingRate {
        perp.funding
    }

    public fun fundingRate_v2(perp: &PerpetualV2) : bluefin::funding_rate::FundingRate {
        perp.funding
    }

    public fun get_fee(trader: address, perp: &Perpetual, is_maker: bool) : u128 {
        0
    }
    
    public fun get_fee_v2(trader: address, perp: &PerpetualV2, is_maker: bool) : u128 {
        let base_fee = if (is_maker) { perp.maker_fee } else { perp.taker_fee };
        let final_fee = base_fee;

        if (sui::table::contains<address, SpecialFee>(&perp.special_fee, trader)) {
            let special_fee = sui::table::borrow<address, SpecialFee>(&perp.special_fee, trader);
            if (special_fee.status == true) {
                let fee = if (is_maker) { special_fee.maker_fee } else { special_fee.taker_fee };
                final_fee = fee;
            };
        };
        final_fee
    }
    
    public fun get_user_position(perp: &PerpetualV2, trader: address) : bluefin::position::UserPosition {
        if (sui::table::contains<address, bluefin::position::UserPosition>(&perp.positions, trader)) {
            return *sui::table::borrow<address, bluefin::position::UserPosition>(&perp.positions, trader)
        };
        bluefin::position::initialize(sui::object::uid_to_inner(&perp.id), trader)
    }
    
    public fun globalIndex(arg0: &Perpetual) : bluefin::funding_rate::FundingIndex {
        bluefin::funding_rate::index(arg0.funding)
    }
    
    public fun globalIndex_v2(arg0: &PerpetualV2) : bluefin::funding_rate::FundingIndex {
        bluefin::funding_rate::index(arg0.funding)
    }
    
    public fun id(perp: &Perpetual) : &sui::object::UID {
        &perp.id
    }

    public fun id_v2(perp: &PerpetualV2) : &sui::object::UID {
        &perp.id
    }

    public fun imr(perp: &Perpetual) : u128 {
        perp.imr
    }

    public fun imr_v2(perp: &PerpetualV2) : u128 {
        perp.imr
    }
    
    entry fun increment_perpetual_version(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2
    ) {
        perp.version = perp.version + 1;
    }
    
    public fun insurancePool(perp: &Perpetual) : address {
        perp.insurancePool
    }

    public fun insurancePool_v2(perp: &PerpetualV2) : address {
        perp.insurancePool
    }

    public fun is_trading_permitted(perp: &mut Perpetual) : bool {
        perp.isTradingPermitted
    }

    public fun is_trading_permitted_v2(perp: &mut PerpetualV2) : bool {
        perp.isTradingPermitted
    }

    public fun is_whitelisted_for_special_fee(perp: &PerpetualV2, trader: address) : bool {
        sui::table::contains<address, SpecialFee>(&perp.specialFee, trader)
    }

    public fun makerFee(perp: &Perpetual) : u128 {
        perp.makerFee
    }

    public fun makerFee_v2(perp: &PerpetualV2) : u128 {
        perp.makerFee
    }

    public fun mmr(perp: &Perpetual) : u128 {
        perp.mmr
    }

    public fun mmr_v2(perp: &PerpetualV2) : u128 {
        perp.mmr
    }

    public fun name(perp: &Perpetual) : &std::string::String {
        &perp.name
    }

    public fun name_v2(perp: &PerpetualV2) : &std::string::String {
        &perp.name
    }

    public fun poolPercentage(perp: &Perpetual) : u128 {
        perp.insurancePoolRatio
    }

    public fun poolPercentage_v2(perp: &PerpetualV2) : u128 {
        perp.insurancePoolRatio
    }

    public(friend) fun positions(perp: &mut PerpetualV2) : &mut sui::table::Table<address, bluefin::position::UserPosition> {
        &mut perp.positions
    }

    public fun priceIdenfitier(perp: &Perpetual) : vector<u8> {
        perp.priceIdentifierId
    }

    public fun priceIdenfitier_v2(perp: &PerpetualV2) : vector<u8> {
        perp.priceIdentifierId
    }

    public fun priceOracle(perp: &Perpetual) : u128 {
        perp.priceOracle
    }

    public fun priceOracle_v2(perp: &PerpetualV2) : u128 {
        perp.priceOracle
    }

    public entry fun set_fee_pool_address(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut Perpetual,
        new_address: address
    ) {
    }
    
    public entry fun set_fee_pool_address_v2<CoinType>(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        perp: &mut PerpetualV2,
        new_fee_pool: address
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(new_fee_pool != @0x0, bluefin::error::address_cannot_be_zero());
        
        perp.fee_pool = new_fee_pool;
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), perp.fee_pool);
        
        let event = FeePoolAccountUpdateEvent{
            id: sui::object::uid_to_inner(id_v2(perp)),
            account: new_fee_pool,
        };
        sui::event::emit<FeePoolAccountUpdateEvent>(event);
    }

    public entry fun set_funding_rate_v2(
        clock: &sui::clock::Clock,
        safe_cap: &bluefin::roles::CapabilitiesSafeV2,
        funding_cap: &bluefin::roles::FundingRateCap,
        perp: &mut PerpetualV2,
        new_rate: u128,
        is_positive: bool,
        price_info: &pyth_network::price_info::PriceInfoObject
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_safe_version(safe_cap);
        update_oracle_price(perp, price_info, clock);
        
        let perp_id = sui::object::uid_to_inner(&perp.id);
        bluefin::funding_rate::set_global_index(
            &mut perp.funding,
            bluefin::funding_rate::compute_new_global_index(clock, perp.funding, priceOracle_v2(perp)),
            perp_id
        );
        
        bluefin::funding_rate::set_funding_rate(
            safe_cap,
            funding_cap,
            &mut perp.funding,
            new_rate / bluefin::library::base_uint(),
            is_positive,
            sui::clock::timestamp_ms(clock),
            perp_id
        );
    }
    
    public entry fun set_initial_margin_required(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_initial_margin_required_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_imr: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let normalized_imr = new_imr / bluefin::library::base_uint();
        assert!(normalized_imr >= perp.mmr, bluefin::error::initial_margin_must_be_greater_than_or_equal_to_mmr());
        perp.imr = normalized_imr;
        
        let event = IMRUpdateEvent{
            id: sui::object::uid_to_inner(id_v2(perp)),
            imr: normalized_imr,
        };
        sui::event::emit<IMRUpdateEvent>(event);
    }
    
    public entry fun set_insurance_pool_address(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: address) {
    }
    
    public entry fun set_insurance_pool_address_v2<CoinType>(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        perp: &mut PerpetualV2,
        new_insurance_pool: address
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(new_insurance_pool != @0x0, bluefin::error::address_cannot_be_zero());
        
        perp.insurance_pool = new_insurance_pool;
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), perp.insurance_pool);
        
        let event = InsurancePoolAccountUpdateEvent{
            id: sui::object::uid_to_inner(id_v2(perp)),
            account: new_insurance_pool,
        };
        sui::event::emit<InsurancePoolAccountUpdateEvent>(event);
    }
    
    public entry fun set_insurance_pool_percentage(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_insurance_pool_percentage_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_ratio: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let normalized_ratio = new_ratio / bluefin::library::base_uint();
        assert!(normalized_ratio <= bluefin::library::base_uint(), bluefin::error::can_not_be_greater_than_hundred_percent());
        perp.insurance_pool_ratio = normalized_ratio;
        
        let event = InsurancePoolRatioUpdateEvent{
            id: sui::object::uid_to_inner(id_v2(perp)),
            ratio: normalized_ratio,
        };
        sui::event::emit<InsurancePoolRatioUpdateEvent>(event);
    }
    
    public entry fun set_maintenance_margin_required(arg0: &bluefin::roles::ExchangeAdminCap, arg1: &mut Perpetual, arg2: u128) {
    }
    
    public entry fun set_maintenance_margin_required_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_mmr: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        let normalized_mmr = new_mmr / bluefin::library::base_uint();
        assert!(normalized_mmr > 0, bluefin::error::maintenance_margin_must_be_greater_than_zero());
        assert!(normalized_mmr <= perp.imr, bluefin::error::maintenance_margin_must_be_less_than_or_equal_to_imr());
        perp.mmr = normalized_mmr;
        
        let event = MMRUpdateEvent{
            id: sui::object::uid_to_inner(id_v2(perp)),
            mmr: normalized_mmr,
        };
        sui::event::emit<MMRUpdateEvent>(event);
    }
    
    entry fun set_maker_fee(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_fee: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        perp.maker_fee = new_fee / bluefin::library::base_uint();
        
        let event = MakerFeeUpdateEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            maker_fee: perp.maker_fee,
        };
        sui::event::emit<MakerFeeUpdateEvent>(event);
    }
    
    public entry fun set_max_allowed_funding_rate_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_rate: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::funding_rate::set_max_allowed_funding_rate(
            &mut perp.funding,
            new_rate / bluefin::library::base_uint(),
            sui::object::uid_to_inner(id_v2(perp))
        );
    }

    public entry fun set_max_oi_open_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        max_oi_limits: vector<u128>
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_max_oi_open(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            bluefin::library::to_1x9_vec(max_oi_limits)
        );
    }

    public entry fun set_max_price_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        max_price: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_max_price(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            max_price / bluefin::library::base_uint()
        );
    }

    public entry fun set_max_qty_limit_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        max_qty: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_max_qty_limit(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            max_qty / bluefin::library::base_uint()
        );
    }

    public entry fun set_max_qty_market_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        max_qty: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_max_qty_market(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            max_qty / bluefin::library::base_uint()
        );
    }

    public entry fun set_min_price_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        min_price: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_min_price(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            min_price / bluefin::library::base_uint()
        );
    }

    public entry fun set_min_qty_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        min_qty: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_min_qty(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            min_qty / bluefin::library::base_uint()
        );
    }

    public entry fun set_mtb_long_V2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        mtb_long: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_mtb_long(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            mtb_long / bluefin::library::base_uint()
        );
    }

    public entry fun set_mtb_short_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        mtb_short: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_mtb_short(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            mtb_short / bluefin::library::base_uint()
        );
    }
    
    entry fun set_perpetual_name(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_name: vector<u8>
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        perp.name = std::string::utf8(new_name);
        
        let event = PerpetualNameUpdateEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            name: perp.name,
        };
        sui::event::emit<PerpetualNameUpdateEvent>(event);
    }

    entry fun set_price_feed(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_price_feed: vector<u8>
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        perp.price_identifier_id = new_price_feed;
        
        let event = PriceFeedUpdateEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            price_feed: new_price_feed,
        };
        sui::event::emit<PriceFeedUpdateEvent>(event);
    }
    
    public entry fun set_price_oracle_identifier(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut Perpetual,
        new_identifier: vector<u8>
    ) {
    }

    public entry fun set_price_oracle_identifier_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_identifier: vector<u8>
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        perp.priceIdentifierId = new_identifier;
        let event = PriceOracleIdentifierUpdateEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            identifier: new_identifier,
        };
        sui::event::emit<PriceOracleIdentifierUpdateEvent>(event);
    }

    public entry fun set_special_fee(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut Perpetual,
        trader: address,
        status: bool,
        maker_fee: u128,
        taker_fee: u128
    ) {
    }
    
    public entry fun set_special_fee_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        trader: address,
        status: bool,
        maker_fee: u128,
        taker_fee: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        
        let special_fee = SpecialFee{
            status,
            maker_fee: maker_fee / bluefin::library::base_uint(),
            taker_fee: taker_fee / bluefin::library::base_uint(),
        };
        
        if (sui::table::contains<address, SpecialFee>(&perp.special_fee, trader)) {
            *sui::table::borrow_mut<address, SpecialFee>(&mut perp.special_fee, trader) = special_fee;
        } else {
            sui::table::add<address, SpecialFee>(&mut perp.special_fee, trader, special_fee);
        };
        
        let event = SpecialFeeEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            account: trader,
            status,
            maker_fee: special_fee.maker_fee,
            taker_fee: special_fee.taker_fee,
        };
        sui::event::emit<SpecialFeeEvent>(event);
    }

    entry fun set_taker_fee(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_fee: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        perp.taker_fee = new_fee / bluefin::library::base_uint();
        
        let event = TakerFeeUpdateEvent{
            perp: sui::object::uid_to_inner(id_v2(perp)),
            taker_fee: perp.taker_fee,
        };
        sui::event::emit<TakerFeeUpdateEvent>(event);
    }
    
    public entry fun set_tick_size_v2(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        perp: &mut PerpetualV2,
        new_tick_size: u128
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::evaluator::set_tick_size(
            sui::object::uid_to_inner(&perp.id),
            &mut perp.checks,
            new_tick_size / bluefin::library::base_uint()
        );
    }

    public entry fun set_trading_permit(
        capabilities_safe: &bluefin::roles::CapabilitiesSafe,
        guardian_cap: &bluefin::roles::ExchangeGuardianCap,
        perp: &mut Perpetual,
        is_permitted: bool
    ) {
    }
    
    public entry fun set_trading_permit_v2(
        safe_cap: &bluefin::roles::CapabilitiesSafeV2,
        guardian_cap: &bluefin::roles::ExchangeGuardianCap,
        perp: &mut PerpetualV2,
        is_permitted: bool
    ) {
        bluefin::roles::validate_safe_version(safe_cap);
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::check_guardian_validity_v2(safe_cap, guardian_cap);
        
        perp.is_trading_permitted = is_permitted;
        let event = TradingPermissionStatusUpdate{status: is_permitted};
        sui::event::emit<TradingPermissionStatusUpdate>(event);
    }
    
    public fun startTime(perp: &Perpetual) : u64 {
        perp.startTime
    }

    public fun startTime_v2(perp: &PerpetualV2) : u64 {
        perp.startTime
    }

    public fun takerFee(perp: &Perpetual) : u128 {
        perp.takerFee
    }

    public fun takerFee_v2(perp: &PerpetualV2) : u128 {
        perp.takerFee
    }

    public(friend) fun update_oracle_price(
        perp: &mut PerpetualV2,
        price_info: &pyth_network::price_info::PriceInfoObject,
        clock: &sui::clock::Clock
    ) {
        assert!(
            bluefin::library::get_price_identifier(price_info) == perp.price_identifier_id,
            bluefin::error::wrong_price_identifier()
        );
        
        perp.price_oracle = bluefin::library::base_div(
            bluefin::library::get_oracle_price_v2(price_info, clock),
            (sui::math::pow(10, (bluefin::library::get_oracle_base_v2(price_info, clock) as u8)) as u128)
        );
    }
}

