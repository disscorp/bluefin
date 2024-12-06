module bluefin::tick {
    struct TickManager has store {
        tick_spacing: u32,
        ticks: 0x2::table::Table<math_library::i32::I32, TickInfo>,
        bitmap: 0x2::table::Table<math_library::i32::I32, u256>,
    }

    struct TickInfo has copy, drop, store {
        index: math_library::i32::I32,
        sqrt_price: u128,
        liquidity_gross: u128,
        liquidity_net: math_library::i128::I128,
        fee_growth_outside_a: u128,
        fee_growth_outside_b: u128,
        tick_cumulative_outside: math_library::i64::I64,
        seconds_per_liquidity_outside: u256,
        seconds_outside: u64,
        reward_growths_outside: vector<u128>,
    }

    public(friend) fun update(
        manager: &mut TickManager,
        tick_index: math_library::i32::I32,
        current_tick: math_library::i32::I32,
        liquidity_delta: math_library::i128::I128,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        reward_growths: vector<u128>,
        tick_cumulative: math_library::i64::I64,
        seconds_per_liquidity: u256,
        time: u64,
        upper: bool
    ) : bool {
        let tick = get_mutable_tick_from_table(&mut manager.ticks, tick_index);
        let old_liquidity_gross = tick.liquidity_gross;
        let new_liquidity_gross = bluefin::utils::add_delta(old_liquidity_gross, liquidity_delta);

        if (old_liquidity_gross == 0) {
            if (math_library::i32::lte(tick_index, current_tick)) {
                tick.fee_growth_outside_a = fee_growth_global_a;
                tick.fee_growth_outside_b = fee_growth_global_b;
                tick.seconds_per_liquidity_outside = seconds_per_liquidity;
                tick.tick_cumulative_outside = tick_cumulative;
                tick.seconds_outside = time;
                tick.reward_growths_outside = reward_growths;
            } else {
                let i = 0;
                while (i < vector::length(&reward_growths)) {
                    vector::push_back(&mut tick.reward_growths_outside, 0);
                    i = i + 1;
                };
            };
        };

        tick.liquidity_gross = new_liquidity_gross;
        let new_liquidity_net = if (upper) {
            math_library::i128::sub(tick.liquidity_net, liquidity_delta)
        } else {
            math_library::i128::add(tick.liquidity_net, liquidity_delta)
        };
        tick.liquidity_net = new_liquidity_net;
        
        new_liquidity_gross == 0 != old_liquidity_gross == 0
    }

        public fun get_fee_and_reward_growths_inside(
        manager: &TickManager,
        tick_lower: math_library::i32::I32,
        tick_upper: math_library::i32::I32,
        current_tick: math_library::i32::I32,
        fee_growth_global_a: u128,
        fee_growth_global_b: u128,
        reward_growths: vector<u128>
    ) : (u128, u128, vector<u128>) {
        let (fee_a_lower, fee_b_lower, rewards_lower) = get_fee_and_reward_growths_outside(manager, tick_lower);
        let (fee_a_upper, fee_b_upper, rewards_upper) = get_fee_and_reward_growths_outside(manager, tick_upper);
        
        let (fee_a_below, fee_b_below, rewards_below) = if (math_library::i32::gte(current_tick, tick_lower)) {
            (fee_a_lower, fee_b_lower, rewards_lower)
        } else {
            (
                math_library::math_u128::wrapping_sub(fee_growth_global_a, fee_a_lower),
                math_library::math_u128::wrapping_sub(fee_growth_global_b, fee_b_lower),
                compute_reward_growths(reward_growths, rewards_lower)
            )
        };

        let (fee_a_above, fee_b_above, rewards_above) = if (math_library::i32::lt(current_tick, tick_upper)) {
            (fee_a_upper, fee_b_upper, rewards_upper)
        } else {
            (
                math_library::math_u128::wrapping_sub(fee_growth_global_a, fee_a_upper),
                math_library::math_u128::wrapping_sub(fee_growth_global_b, fee_b_upper),
                compute_reward_growths(reward_growths, rewards_upper)
            )
        };

        (
            math_library::math_u128::wrapping_sub(
                math_library::math_u128::wrapping_sub(fee_growth_global_a, fee_a_below),
                fee_a_above
            ),
            math_library::math_u128::wrapping_sub(
                math_library::math_u128::wrapping_sub(fee_growth_global_b, fee_b_below),
                fee_b_above
            ),
            compute_reward_growths(compute_reward_growths(reward_growths, rewards_below), rewards_above)
        )
    }

    public fun get_fee_and_reward_growths_outside(
        manager: &TickManager,
        tick_index: math_library::i32::I32
    ) : (u128, u128, vector<u128>) {
        if (!is_tick_initialized(manager, tick_index)) {
            (0, 0, vector::empty<u128>())
        } else {
            let tick = table::borrow<math_library::i32::I32, TickInfo>(&manager.ticks, tick_index);
            (tick.fee_growth_outside_a, tick.fee_growth_outside_b, tick.reward_growths_outside)
        }
    }

    public(friend) fun get_mutable_tick_from_manager(
        manager: &mut TickManager,
        tick_index: math_library::i32::I32
    ) : &mut TickInfo {
        get_mutable_tick_from_table(&mut manager.ticks, tick_index)
    }

    public(friend) fun get_mutable_tick_from_table(
        ticks: &mut table::Table<math_library::i32::I32, TickInfo>,
        tick_index: math_library::i32::I32
    ) : &mut TickInfo {
        if (!table::contains<math_library::i32::I32, TickInfo>(ticks, tick_index)) {
            table::add<math_library::i32::I32, TickInfo>(ticks, tick_index, create_tick(tick_index));
        };
        table::borrow_mut<math_library::i32::I32, TickInfo>(ticks, tick_index)
    }

    public fun get_tick_from_manager(
        manager: &TickManager,
        tick_index: math_library::i32::I32
    ) : &TickInfo {
        get_tick_from_table(&manager.ticks, tick_index)
    }

    public fun get_tick_from_table(
        ticks: &table::Table<math_library::i32::I32, TickInfo>,
        tick_index: math_library::i32::I32
    ) : &TickInfo {
        table::borrow<math_library::i32::I32, TickInfo>(ticks, tick_index)
    }

    public(friend) fun initialize_manager(
        tick_spacing: u32,
        ctx: &mut tx_context::TxContext
    ) : TickManager {
        TickManager {
            tick_spacing,
            ticks: table::new<math_library::i32::I32, TickInfo>(ctx),
            bitmap: table::new<math_library::i32::I32, u256>(ctx),
        }
    }

    public fun is_tick_initialized(
        manager: &TickManager,
        tick_index: math_library::i32::I32
    ) : bool {
        table::contains<math_library::i32::I32, TickInfo>(&manager.ticks, tick_index)
    }

    public fun liquidity_gross(tick: &TickInfo) : u128 {
        tick.liquidity_gross
    }

    public fun liquidity_net(tick: &TickInfo) : math_library::i128::I128 {
        tick.liquidity_net
    }

    public(friend) fun mutable_bitmap(
        manager: &mut TickManager
    ) : &mut table::Table<math_library::i32::I32, u256> {
        &mut manager.bitmap
    }

    public fun sqrt_price(tick: &TickInfo) : u128 {
        tick.sqrt_price
    }

    public fun tick_spacing(manager: &TickManager) : u32 {
        manager.tick_spacing
    }
}