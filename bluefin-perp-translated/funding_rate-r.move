module bluefin::funding_rate {
    struct MaxAllowedFRUpdateEvent has copy, drop {
        id: sui::object::ID,
        value: u128,
    }
    
    struct GlobalIndexUpdate has copy, drop {
        id: sui::object::ID,
        index: FundingIndex,
    }
    
    struct FundingRateUpdateEvent has copy, drop {
        id: sui::object::ID,
        rate: bluefin::signed_number::Number,
        window: u64,
        minApplicationTime: u64,
    }
    
    struct FundingIndex has copy, drop, store {
        value: bluefin::signed_number::Number,
        timestamp: u64,
    }
    
    struct FundingRate has copy, drop, store {
        startTime: u64,
        maxFunding: u128,
        window: u64,
        rate: bluefin::signed_number::Number,
        index: FundingIndex,
    }
    
    public fun are_indexes_equal(index1: FundingIndex, index2: FundingIndex) : bool {
        index1.timestamp == index2.timestamp
    }
    
    public fun compute_new_global_index(clock: &sui::clock::Clock, funding_rate: FundingRate, base_precision: u128) : FundingIndex {
        let current_timestamp = sui::clock::timestamp_ms(clock);
        let time_diff = if (current_timestamp > funding_rate.index.timestamp) {
            ((current_timestamp - funding_rate.index.timestamp) as u128)
        } else {
            0
        };
        if (time_diff > 0) {
            let hours_passed = if (time_diff < (3600000 as u128)) {
                1
            } else {
                time_diff / (3600000 as u128)
            };
            funding_rate.index.value = bluefin::signed_number::add(
                funding_rate.index.value, 
                bluefin::signed_number::from(
                    bluefin::library::base_mul(bluefin::signed_number::value(funding_rate.rate) * hours_passed, base_precision),
                    bluefin::signed_number::sign(funding_rate.rate)
                )
            );
            funding_rate.index.timestamp = current_timestamp;
        };
        funding_rate.index
    }
    
    fun expected_funding_window(funding_rate: FundingRate, current_time: u64) : u64 {
        if (current_time < funding_rate.startTime) {
            0
        } else {
            (current_time - funding_rate.startTime) / 3600000 + 1
        }
    }
    
    public fun index(funding_rate: FundingRate) : FundingIndex {
        funding_rate.index
    }
    
    public fun index_timestamp(index: FundingIndex) : u64 {
        index.timestamp
    }
    
    public fun index_value(index: FundingIndex) : bluefin::signed_number::Number {
        index.value
    }
    
    public(friend) fun initialize(start_time: u64, max_funding: u128) : FundingRate {
        FundingRate{
            startTime  : start_time, 
            maxFunding : max_funding, 
            window     : 0, 
            rate       : bluefin::signed_number::new(), 
            index      : initialize_index(start_time),
        }
    }
    
    public fun initialize_index(timestamp: u64) : FundingIndex {
        FundingIndex{
            value     : bluefin::signed_number::new(), 
            timestamp : timestamp,
        }
    }
    
    public fun rate(funding_rate: FundingRate) : bluefin::signed_number::Number {
        funding_rate.rate
    }
    
    public(friend) fun set_funding_rate(
        capabilities: &bluefin::roles::CapabilitiesSafeV2,
        funding_rate_cap: &bluefin::roles::FundingRateCap,
        funding_rate: &mut FundingRate,
        new_rate: u128,
        is_positive: bool,
        current_time: u64,
        perp_id: sui::object::ID
    ) {
        bluefin::roles::check_funding_rate_operator_validity_v2(capabilities, funding_rate_cap);
        let expected_window = expected_funding_window(*funding_rate, current_time);
        assert!(expected_window > 1, bluefin::error::funding_rate_can_not_be_set_for_zeroth_window());
        assert!(funding_rate.window < expected_window - 1, bluefin::error::funding_rate_for_window_already_set());
        assert!(new_rate <= funding_rate.maxFunding, bluefin::error::greater_than_max_allowed_funding());
        funding_rate.rate = bluefin::signed_number::from(new_rate, is_positive);
        funding_rate.window = expected_window - 1;
        let event = FundingRateUpdateEvent{
            id                 : perp_id, 
            rate               : funding_rate.rate, 
            window             : funding_rate.window, 
            minApplicationTime : expected_window * 3600000 + funding_rate.startTime - current_time,
        };
        sui::event::emit<FundingRateUpdateEvent>(event);
    }
    
    public(friend) fun set_global_index(funding_rate: &mut FundingRate, new_index: FundingIndex, perp_id: sui::object::ID) {
        if (funding_rate.index.timestamp != new_index.timestamp) {
            funding_rate.index = new_index;
            let event = GlobalIndexUpdate{
                id    : perp_id, 
                index : new_index,
            };
            sui::event::emit<GlobalIndexUpdate>(event);
        };
    }
    
    public(friend) fun set_max_allowed_funding_rate(funding_rate: &mut FundingRate, new_max_funding: u128, perp_id: sui::object::ID) {
        assert!(new_max_funding <= bluefin::library::base_uint(), bluefin::error::can_not_be_greater_than_hundred_percent());
        funding_rate.maxFunding = new_max_funding;
        let event = MaxAllowedFRUpdateEvent{
            id    : perp_id, 
            value : new_max_funding,
        };
        sui::event::emit<MaxAllowedFRUpdateEvent>(event);
    }
}
