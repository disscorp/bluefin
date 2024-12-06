module bluefin::evaluator {
    struct MinOrderPriceUpdateEvent has copy, drop {
        id: sui::object::ID,
        price: u128,
    }
    
    struct MaxOrderPriceUpdateEvent has copy, drop {
        id: sui::object::ID,
        price: u128,
    }
    
    struct StepSizeUpdateEvent has copy, drop {
        id: sui::object::ID,
        size: u128,
    }
    
    struct TickSizeUpdateEvent has copy, drop {
        id: sui::object::ID,
        size: u128,
    }
    
    struct MtbLongUpdateEvent has copy, drop {
        id: sui::object::ID,
        mtb: u128,
    }
    
    struct MtbShortUpdateEvent has copy, drop {
        id: sui::object::ID,
        mtb: u128,
    }
    
    struct MaxQtyLimitUpdateEvent has copy, drop {
        id: sui::object::ID,
        qty: u128,
    }
    
    struct MaxQtyMarketUpdateEvent has copy, drop {
        id: sui::object::ID,
        qty: u128,
    }
    
    struct MinQtyUpdateEvent has copy, drop {
        id: sui::object::ID,
        qty: u128,
    }
    
    struct MaxAllowedOIOpenUpdateEvent has copy, drop {
        id: sui::object::ID,
        maxAllowedOIOpen: vector<u128>,
    }
    
    struct TradeChecks has copy, drop, store {
        minPrice: u128,
        maxPrice: u128,
        tickSize: u128,
        minQty: u128,
        maxQtyLimit: u128,
        maxQtyMarket: u128,
        stepSize: u128,
        mtbLong: u128,
        mtbShort: u128,
        maxAllowedOIOpen: vector<u128>,
    }
    
    public(friend) fun initialize(arg0: u128, arg1: u128, arg2: u128, arg3: u128, arg4: u128, arg5: u128, arg6: u128, arg7: u128, arg8: u128, arg9: vector<u128>) : TradeChecks {
        let v0 = std::vector::empty<u128>();
        std::vector::push_back<u128>(&mut v0, 0);
        std::vector::append<u128>(&mut v0, arg9);
        let v1 = TradeChecks{
            minPrice         : arg0, 
            maxPrice         : arg1, 
            tickSize         : arg2, 
            minQty           : arg3, 
            maxQtyLimit      : arg4, 
            maxQtyMarket     : arg5, 
            stepSize         : arg6, 
            mtbLong          : arg7, 
            mtbShort         : arg8, 
            maxAllowedOIOpen : v0,
        };
        verify_pre_init_checks(v1);
        v1
    }
    
    public(friend) fun set_max_oi_open(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: vector<u128>) {
        let v0 = std::vector::empty<u128>();
        std::vector::push_back<u128>(&mut v0, 0);
        std::vector::append<u128>(&mut v0, arg2);
        arg1.maxAllowedOIOpen = v0;
        let v1 = MaxAllowedOIOpenUpdateEvent{
            id               : arg0, 
            maxAllowedOIOpen : v0,
        };
        sui::event::emit<MaxAllowedOIOpenUpdateEvent>(v1);
    }
    
    public(friend) fun set_max_price(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > arg1.minPrice, bluefin::error::max_price_greater_than_min_price());
        arg1.maxPrice = arg2;
        let v0 = MaxOrderPriceUpdateEvent{
            id    : arg0, 
            price : arg2,
        };
        sui::event::emit<MaxOrderPriceUpdateEvent>(v0);
    }
    
    public(friend) fun set_max_qty_limit(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > arg1.minQty, bluefin::error::max_limit_qty_greater_than_min_qty());
        arg1.maxQtyLimit = arg2;
        let v0 = MaxQtyLimitUpdateEvent{
            id  : arg0, 
            qty : arg2,
        };
        sui::event::emit<MaxQtyLimitUpdateEvent>(v0);
    }
    
    public(friend) fun set_max_qty_market(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > arg1.minQty, bluefin::error::max_market_qty_less_than_min_qty());
        arg1.maxQtyMarket = arg2;
        let v0 = MaxQtyMarketUpdateEvent{
            id  : arg0, 
            qty : arg2,
        };
        sui::event::emit<MaxQtyMarketUpdateEvent>(v0);
    }
    
    public(friend) fun set_min_price(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > 0, bluefin::error::min_price_greater_than_zero());
        assert!(arg2 < arg1.maxPrice, bluefin::error::min_price_less_than_max_price());
        arg1.minPrice = arg2;
        let v0 = MinOrderPriceUpdateEvent{
            id    : arg0, 
            price : arg2,
        };
        sui::event::emit<MinOrderPriceUpdateEvent>(v0);
    }
    
    public(friend) fun set_min_qty(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 < arg1.maxQtyLimit && arg2 < arg1.maxQtyMarket, bluefin::error::min_qty_less_than_max_qty());
        assert!(arg2 > 0, bluefin::error::min_qty_greater_than_zero());
        arg1.minQty = arg2;
        let v0 = MinQtyUpdateEvent{
            id  : arg0, 
            qty : arg2,
        };
        sui::event::emit<MinQtyUpdateEvent>(v0);
    }
    
    public(friend) fun set_mtb_long(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > 0, bluefin::error::mtb_long_greater_than_zero());
        arg1.mtbLong = arg2;
        let v0 = MtbLongUpdateEvent{
            id  : arg0, 
            mtb : arg2,
        };
        sui::event::emit<MtbLongUpdateEvent>(v0);
    }
    
    public(friend) fun set_mtb_short(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > 0, 13);
        assert!(arg2 < bluefin::library::base_uint(), 14);
        arg1.mtbShort = arg2;
        let v0 = MtbShortUpdateEvent{
            id  : arg0, 
            mtb : arg2,
        };
        sui::event::emit<MtbShortUpdateEvent>(v0);
    }
    
    public(friend) fun set_step_size(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > 0, bluefin::error::step_size_greater_than_zero());
        arg1.stepSize = arg2;
        let v0 = StepSizeUpdateEvent{
            id   : arg0, 
            size : arg2,
        };
        sui::event::emit<StepSizeUpdateEvent>(v0);
    }
    
    public(friend) fun set_tick_size(arg0: sui::object::ID, arg1: &mut TradeChecks, arg2: u128) {
        assert!(arg2 > 0, bluefin::error::tick_size_greater_than_zero());
        arg1.tickSize = arg2;
        let v0 = TickSizeUpdateEvent{
            id   : arg0, 
            size : arg2,
        };
        sui::event::emit<TickSizeUpdateEvent>(v0);
    }
    
    public fun tickSize(arg0: TradeChecks) : u128 {
        arg0.tickSize
    }
    
    public fun verify_market_take_bound_checks(arg0: TradeChecks, arg1: u128, arg2: u128, arg3: bool) {
        if (arg3) {
            assert!(arg1 <= arg2 + bluefin::library::base_mul(arg2, arg0.mtbLong), bluefin::error::trade_price_greater_than_mtb_long());
        } else {
            assert!(arg1 >= arg2 - bluefin::library::base_mul(arg2, arg0.mtbShort), bluefin::error::trade_price_greater_than_mtb_short());
        };
    }
    
    public fun verify_min_max_price(arg0: TradeChecks, arg1: u128) {
        assert!(arg1 >= arg0.minPrice, bluefin::error::trade_price_less_than_min_price());
        assert!(arg1 <= arg0.maxPrice, bluefin::error::trade_price_greater_than_max_price());
    }
    
    public fun verify_min_max_qty_checks(arg0: TradeChecks, arg1: u128) {
        assert!(arg1 >= arg0.minQty, bluefin::error::trade_qty_less_than_min_qty());
        assert!(arg1 <= arg0.maxQtyLimit, bluefin::error::trade_qty_greater_than_limit_qty());
        assert!(arg1 <= arg0.maxQtyMarket, bluefin::error::trade_qty_greater_than_market_qty());
    }
    
    public fun verify_oi_open_for_account(arg0: TradeChecks, arg1: u128, arg2: u128, arg3: u64) {
        let v0 = bluefin::library::base_div(bluefin::library::base_uint(), arg1);
        let v1 = if (v0 % bluefin::library::base_uint() > bluefin::library::half_base_uint()) {
            bluefin::library::ceil(v0, bluefin::library::base_uint())
        } else {
            v0 / bluefin::library::base_uint() * bluefin::library::base_uint()
        };
        let v2 = v1 / bluefin::library::base_uint();
        if ((v2 as u64) > std::vector::length<u128>(&arg0.maxAllowedOIOpen)) {
            return
        };
        assert!(arg2 <= *std::vector::borrow<u128>(&arg0.maxAllowedOIOpen, (v2 as u64)), bluefin::error::oi_open_greater_than_max_allowed(arg3));
    }
    
    fun verify_pre_init_checks(arg0: TradeChecks) {
        assert!(arg0.minPrice > 0, bluefin::error::min_price_greater_than_zero());
        assert!(arg0.minPrice < arg0.maxPrice, bluefin::error::min_price_less_than_max_price());
        assert!(arg0.stepSize > 0, bluefin::error::step_size_greater_than_zero());
        assert!(arg0.tickSize > 0, bluefin::error::tick_size_greater_than_zero());
        assert!(arg0.mtbLong > 0, bluefin::error::mtb_long_greater_than_zero());
        assert!(arg0.mtbShort > 0, bluefin::error::mtb_short_greater_than_zero());
        assert!(arg0.mtbShort < bluefin::library::base_uint(), bluefin::error::mtb_short_less_than_hundred_percent());
        assert!(arg0.maxQtyLimit > arg0.minQty, bluefin::error::max_limit_qty_greater_than_min_qty());
        assert!(arg0.maxQtyMarket > arg0.minQty, bluefin::error::max_market_qty_less_than_min_qty());
        assert!(arg0.minQty < arg0.maxQtyLimit && arg0.minQty < arg0.maxQtyMarket, bluefin::error::min_qty_less_than_max_qty());
        assert!(arg0.minQty > 0, bluefin::error::min_qty_greater_than_zero());
    }
    
    public fun verify_price_checks(arg0: TradeChecks, arg1: u128) {
        verify_min_max_price(arg0, arg1);
        verify_tick_size(arg0, arg1);
    }
    
    public fun verify_qty_checks(arg0: TradeChecks, arg1: u128) {
        verify_min_max_qty_checks(arg0, arg1);
        verify_step_size(arg0, arg1);
    }
    
    public fun verify_step_size(arg0: TradeChecks, arg1: u128) {
        assert!(arg1 % arg0.stepSize == 0, bluefin::error::trade_qty_step_size_not_allowed());
    }
    
    public fun verify_tick_size(arg0: TradeChecks, arg1: u128) {
        assert!(arg1 % arg0.tickSize == 0, bluefin::error::trade_price_tick_size_not_allowed());
    }
    
    // decompiled from Move bytecode v6
}

