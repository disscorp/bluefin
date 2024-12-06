module bluefin::events {
    struct AdminCapTransferred has copy, drop {
        owner: address,
    }

    struct ProtocolFeeCapTransferred has copy, drop {
        owner: address,
    }

    struct PoolCreated has copy, drop {
        id: 0x2::object::ID,
        coin_a: 0x1::string::String,
        coin_a_symbol: 0x1::string::String,
        coin_a_decimals: u8,
        coin_a_url: 0x1::string::String,
        coin_b: 0x1::string::String,
        coin_b_symbol: 0x1::string::String,
        coin_b_decimals: u8,
        coin_b_url: 0x1::string::String,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        tick_spacing: u32,
        fee_rate: u64,
        protocol_fee_share: u64,
    }

    struct PositionOpened has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        tick_lower: math_library::i32::I32,
        tick_upper: math_library::i32::I32,
    }

    struct PositionClosed has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        tick_lower: math_library::i32::I32,
        tick_upper: math_library::i32::I32,
    }

    struct AssetSwap has copy, drop {
        pool_id: 0x2::object::ID,
        a2b: bool,
        amount_in: u64,
        amount_out: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        fee: u64,
        before_liquidity: u128,
        after_liquidity: u128,
        before_sqrt_price: u128,
        after_sqrt_price: u128,
        current_tick: math_library::i32::I32,
        exceeded: bool,
        sequence_number: u128,
    }

    struct FlashSwap has copy, drop {
        pool_id: 0x2::object::ID,
        a2b: bool,
        amount_in: u64,
        amount_out: u64,
        fee: u64,
        before_liquidity: u128,
        after_liquidity: u128,
        before_sqrt_price: u128,
        after_sqrt_price: u128,
        current_tick: math_library::i32::I32,
        exceeded: bool,
        sequence_number: u128,
    }

    struct ProtocolFeeCollected has copy, drop {
        pool_id: 0x2::object::ID,
        sender: address,
        destination: address,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        sequence_number: u128,
    }

    struct UserFeeCollected has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        sequence_number: u128,
    }

    struct UserRewardCollected has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        reward_type: 0x1::string::String,
        reward_symbol: 0x1::string::String,
        reward_decimals: u8,
        reward_amount: u64,
        sequence_number: u128,
    }

    struct LiquidityProvided has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        liquidity: u128,
        before_liquidity: u128,
        after_liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        sequence_number: u128,
    }

    struct LiquidityRemoved has copy, drop {
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        liquidity: u128,
        before_liquidity: u128,
        after_liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        sequence_number: u128,
    }

    struct UpdatePoolRewardEmissionEvent has copy, drop {
        pool_id: 0x2::object::ID,
        reward_coin_symbol: 0x1::string::String,
        reward_coin_type: 0x1::string::String,
        reward_coin_decimals: u8,
        total_reward: u64,
        ended_at_seconds: u64,
        last_update_time: u64,
        reward_per_seconds: u128,
        sequence_number: u128,
    }

    public(friend) fun emit_admin_cap_transfer_event(new_owner: address) {
        let event = AdminCapTransferred{owner: new_owner};
        0x2::event::emit<AdminCapTransferred>(event);
    }

    public(friend) fun emit_flash_swap_event(
        pool_id: 0x2::object::ID,
        is_a_to_b: bool,
        amount_in: u64,
        amount_out: u64,
        fee_amount: u64,
        before_liquidity: u128,
        after_liquidity: u128,
        before_sqrt_price: u128,
        after_sqrt_price: u128,
        current_tick: math_library::i32::I32,
        exceeded_limit: bool,
        sequence_number: u128
    ) {
        let event = FlashSwap{
            pool_id,
            a2b: is_a_to_b,
            amount_in,
            amount_out,
            fee: fee_amount,
            before_liquidity,
            after_liquidity,
            before_sqrt_price,
            after_sqrt_price,
            current_tick,
            exceeded: exceeded_limit,
            sequence_number,
        };
        0x2::event::emit<FlashSwap>(event);
    }

    public(friend) fun emit_liquidity_provided_event(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        liquidity: u128,
        before_liquidity: u128,
        after_liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        sequence_number: u128
    ) {
        let event = LiquidityProvided{
            pool_id,
            position_id,
            coin_a_amount,
            coin_b_amount,
            pool_coin_a_amount,
            pool_coin_b_amount,
            liquidity,
            before_liquidity,
            after_liquidity,
            current_sqrt_price,
            current_tick_index,
            lower_tick,
            upper_tick,
            sequence_number,
        };
        0x2::event::emit<LiquidityProvided>(event);
    }

        public(friend) fun emit_liquidity_removed_event(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        liquidity: u128,
        before_liquidity: u128,
        after_liquidity: u128,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        sequence_number: u128
    ) {
        let event = LiquidityRemoved{
            pool_id,
            position_id,
            coin_a_amount,
            coin_b_amount,
            pool_coin_a_amount,
            pool_coin_b_amount,
            liquidity,
            before_liquidity,
            after_liquidity,
            current_sqrt_price,
            current_tick_index,
            lower_tick,
            upper_tick,
            sequence_number,
        };
        0x2::event::emit<LiquidityRemoved>(event);
    }

    public(friend) fun emit_pool_created_event(
        pool_id: 0x2::object::ID,
        coin_a_type: 0x1::string::String,
        coin_a_symbol: 0x1::string::String,
        coin_a_decimals: u8,
        coin_a_url: 0x1::string::String,
        coin_b_type: 0x1::string::String,
        coin_b_symbol: 0x1::string::String,
        coin_b_decimals: u8,
        coin_b_url: 0x1::string::String,
        current_sqrt_price: u128,
        current_tick_index: math_library::i32::I32,
        tick_spacing: u32,
        fee_rate: u64,
        protocol_fee_share: u64
    ) {
        let event = PoolCreated{
            id: pool_id,
            coin_a: coin_a_type,
            coin_a_symbol,
            coin_a_decimals,
            coin_a_url,
            coin_b: coin_b_type,
            coin_b_symbol,
            coin_b_decimals,
            coin_b_url,
            current_sqrt_price,
            current_tick_index,
            tick_spacing,
            fee_rate,
            protocol_fee_share,
        };
        0x2::event::emit<PoolCreated>(event);
    }

    public(friend) fun emit_position_close_event(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        tick_lower: math_library::i32::I32,
        tick_upper: math_library::i32::I32
    ) {
        let event = PositionClosed{
            pool_id,
            position_id,
            tick_lower,
            tick_upper,
        };
        0x2::event::emit<PositionClosed>(event);
    }

    public(friend) fun emit_position_open_event(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        tick_lower: math_library::i32::I32,
        tick_upper: math_library::i32::I32
    ) {
        let event = PositionOpened{
            pool_id,
            position_id,
            tick_lower,
            tick_upper,
        };
        0x2::event::emit<PositionOpened>(event);
    }

    public(friend) fun emit_protocol_fee_cap_transfer_event(new_owner: address) {
        let event = ProtocolFeeCapTransferred{owner: new_owner};
        0x2::event::emit<ProtocolFeeCapTransferred>(event);
    }

    public(friend) fun emit_protocol_fee_collected(
        pool_id: 0x2::object::ID,
        sender: address,
        destination: address,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        sequence_number: u128
    ) {
        let event = ProtocolFeeCollected{
            pool_id,
            sender,
            destination,
            coin_a_amount,
            coin_b_amount,
            pool_coin_a_amount,
            pool_coin_b_amount,
            sequence_number,
        };
        0x2::event::emit<ProtocolFeeCollected>(event);
    }

    public(friend) fun emit_swap_event(
        pool_id: 0x2::object::ID,
        is_a_to_b: bool,
        amount_in: u64,
        amount_out: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        fee_amount: u64,
        before_liquidity: u128,
        after_liquidity: u128,
        before_sqrt_price: u128,
        after_sqrt_price: u128,
        current_tick: math_library::i32::I32,
        exceeded_limit: bool,
        sequence_number: u128
    ) {
        let event = AssetSwap{
            pool_id,
            a2b: is_a_to_b,
            amount_in,
            amount_out,
            pool_coin_a_amount,
            pool_coin_b_amount,
            fee: fee_amount,
            before_liquidity,
            after_liquidity,
            before_sqrt_price,
            after_sqrt_price,
            current_tick,
            exceeded: exceeded_limit,
            sequence_number,
        };
        0x2::event::emit<AssetSwap>(event);
    }

    public(friend) fun emit_update_pool_reward_emission_event(
        pool_id: 0x2::object::ID,
        reward_coin_symbol: 0x1::string::String,
        reward_coin_type: 0x1::string::String,
        reward_coin_decimals: u8,
        total_reward: u64,
        ended_at_seconds: u64,
        last_update_time: u64,
        reward_per_seconds: u128,
        sequence_number: u128
    ) {
        let event = UpdatePoolRewardEmissionEvent{
            pool_id,
            reward_coin_symbol,
            reward_coin_type,
            reward_coin_decimals,
            total_reward,
            ended_at_seconds,
            last_update_time,
            reward_per_seconds,
            sequence_number,
        };
        0x2::event::emit<UpdatePoolRewardEmissionEvent>(event);
    }

    public(friend) fun emit_user_fee_collected(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        coin_a_amount: u64,
        coin_b_amount: u64,
        pool_coin_a_amount: u64,
        pool_coin_b_amount: u64,
        sequence_number: u128
    ) {
        let event = UserFeeCollected{
            pool_id,
            position_id,
            coin_a_amount,
            coin_b_amount,
            pool_coin_a_amount,
            pool_coin_b_amount,
            sequence_number,
        };
        0x2::event::emit<UserFeeCollected>(event);
    }

    public(friend) fun emit_user_reward_collected(
        pool_id: 0x2::object::ID,
        position_id: 0x2::object::ID,
        reward_type: 0x1::string::String,
        reward_symbol: 0x1::string::String,
        reward_decimals: u8,
        reward_amount: u64,
        sequence_number: u128
    ) {
        let event = UserRewardCollected{
            pool_id,
            position_id,
            reward_type,
            reward_symbol,
            reward_decimals,
            reward_amount,
            sequence_number,
        };
        0x2::event::emit<UserRewardCollected>(event);
    }
}