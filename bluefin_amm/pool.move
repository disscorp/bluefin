module bluefin::pool {
    struct Pool<phantom CoinTypeA, phantom CoinTypeB> has store, key {
        id: 0x2::object::UID,
        name: 0x1::string::String,
        coin_a: 0x2::balance::Balance<CoinTypeA>,
        coin_b: 0x2::balance::Balance<CoinTypeB>,
        fee_rate: u64,
        protocol_fee_share: u64,
        fee_growth_global_coin_a: u128,
        fee_growth_global_coin_b: u128,
        protocol_fee_coin_a: u64,
        protocol_fee_coin_b: u64,
        ticks_manager: bluefin::tick::TickManager,
        observations_manager: bluefin::oracle::ObservationManager,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        liquidity: u128,
        reward_infos: vector<PoolRewardInfo>,
        is_paused: bool,
        icon_url: 0x1::string::String,
        position_index: u128,
        sequence_number: u128,
    }

    struct PoolRewardInfo has copy, drop, store {
        reward_coin_symbol: 0x1::string::String,
        reward_coin_decimals: u8,
        reward_coin_type: 0x1::string::String,
        last_update_time: u64,
        ended_at_seconds: u64,
        total_reward: u64,
        total_reward_allocated: u64,
        reward_per_seconds: u128,
        reward_growth_global: u128,
    }

    struct SwapResult has copy, drop {
        a2b: bool,
        by_amount_in: bool,
        amount_specified: u64,
        amount_specified_remaining: u64,
        amount_calculated: u64,
        fee_growth_global: u128,
        fee_amount: u64,
        protocol_fee: u64,
        start_sqrt_price: u128,
        end_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        is_exceed: bool,
        starting_liquidity: u128,
        liquidity: u128,
        steps: u64,
        step_results: vector<SwapStepResult>,
    }

    struct SwapStepResult has copy, drop, store {
        tick_index_next: math_library::i32::I32,
        initialized: bool,
        sqrt_price_start: u128,
        sqrt_price_next: u128,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        remaining_amount: u64,
    }

    struct FlashSwapReceipt<phantom CoinTypeA, phantom CoinTypeB> {
        pool_id: 0x2::object::ID,
        a2b: bool,
        pay_amount: u64,
    }

        public fun swap_pay_amount<CoinTypeA, CoinTypeB>(receipt: &FlashSwapReceipt<CoinTypeA, CoinTypeB>) : u64 {
        receipt.pay_amount
    }
    
    public(friend) fun update_pool_reward_emission<CoinTypeA, CoinTypeB, RewardType>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        reward_balance: 0x2::balance::Balance<RewardType>,
        emission_rate: u64,
        duration: u64,
        is_blue_reward: bool
    ) {
        let reward_info_index = find_reward_info_index<CoinTypeA, CoinTypeB, RewardType>(pool);
        let reward_info = 0x1::vector::borrow_mut<PoolRewardInfo>(&mut pool.reward_infos, reward_info_index);
        
        let reward_amount = 0x2::balance::value(&reward_balance);
        let reward_balance_ref = 0x2::dynamic_field::borrow_mut<0x1::string::String, 0x2::balance::Balance<RewardType>>(
            &mut pool.id,
            bluefin::utils::get_type_string<RewardType>()
        );
        0x2::balance::join(reward_balance_ref, reward_balance);

        reward_info.total_reward = reward_info.total_reward + reward_amount;
        reward_info.reward_per_seconds = emission_rate;
        if (duration > 0) {
            reward_info.ended_at_seconds = reward_info.last_update_time + duration;
        };

        bluefin::events::emit_update_pool_reward_emission_event(
            0x2::object::id<Pool<CoinTypeA, CoinTypeB>>(pool),
            reward_info.reward_coin_symbol,
            reward_info.reward_coin_type,
            reward_info.reward_coin_decimals,
            reward_amount,
            reward_info.ended_at_seconds,
            reward_info.last_update_time,
            reward_info.reward_per_seconds,
            pool.sequence_number
        );
        pool.sequence_number = pool.sequence_number + 1;
    }

    public(friend) fun update_reward_infos<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        timestamp: u64
    ) {
        let i = 0;
        while (i < 0x1::vector::length(&pool.reward_infos)) {
            let reward_info = 0x1::vector::borrow_mut<PoolRewardInfo>(&mut pool.reward_infos, i);
            if (reward_info.last_update_time < timestamp) {
                let time_delta = if (reward_info.ended_at_seconds < timestamp) {
                    reward_info.ended_at_seconds - reward_info.last_update_time
                } else {
                    timestamp - reward_info.last_update_time
                };
                if (time_delta > 0 && pool.liquidity > 0) {
                    let rewards = (reward_info.reward_per_seconds as u128) * (time_delta as u128);
                    reward_info.reward_growth_global = bluefin::utils::overflow_add(
                        reward_info.reward_growth_global,
                        bluefin::utils::mul_div_floor(rewards, bluefin::constants::q64(), pool.liquidity)
                    );
                };
                reward_info.last_update_time = timestamp;
            };
            i = i + 1;
        };
    }

    public fun verify_pool_manager<CoinTypeA, CoinTypeB>(pool: &Pool<CoinTypeA, CoinTypeB>, address: address) : bool {
        get_pool_manager(pool) == address
    }

    fun withdraw_balances<CoinTypeA, CoinTypeB>(
        pool: &mut Pool<CoinTypeA, CoinTypeB>,
        amount_a: u64,
        amount_b: u64
    ) : (0x2::balance::Balance<CoinTypeA>, 0x2::balance::Balance<CoinTypeB>) {
        (
            bluefin::utils::withdraw_balance(&mut pool.coin_a, amount_a),
            bluefin::utils::withdraw_balance(&mut pool.coin_b, amount_b)
        )
    }
}