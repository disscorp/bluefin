module bluefin::position {
    struct POSITION has drop {
        dummy_field: bool,
    }

    struct Position has store, key {
        id: 0x2::object::UID,
        pool_id: 0x2::object::ID,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        fee_rate: u64,
        liquidity: u128,
        fee_growth_coin_a: u128,
        fee_growth_coin_b: u128,
        token_a_fee: u64,
        token_b_fee: u64,
        name: 0x1::string::String,
        coin_type_a: 0x1::string::String,
        coin_type_b: 0x1::string::String,
        description: 0x1::string::String,
        image_url: 0x1::string::String,
        position_index: u128,
        reward_infos: vector<PositionRewardInfo>,
    }

    struct PositionRewardInfo has copy, drop, store {
        reward_growth_inside_last: u128,
        coins_owed_reward: u64,
    }

    public(friend) fun update(
        position: &mut Position,
        liquidity_delta: math_library::i128::I128,
        fee_growth_inside_a: u128,
        fee_growth_inside_b: u128,
        reward_growths_inside: vector<u128>
    ) {
        let new_liquidity = if (math_library::i128::eq(liquidity_delta, math_library::i128::zero())) {
            assert!(position.liquidity > 0, bluefin::errors::insufficient_liquidity());
            position.liquidity
        } else {
            bluefin::utils::add_delta(position.liquidity, liquidity_delta)
        };

        let fee_delta_a = math_library::full_math_u128::mul_div_floor(
            math_library::math_u128::wrapping_sub(fee_growth_inside_a, position.fee_growth_coin_a),
            position.liquidity,
            bluefin::constants::q64()
        );
        
        let fee_delta_b = math_library::full_math_u128::mul_div_floor(
            math_library::math_u128::wrapping_sub(fee_growth_inside_b, position.fee_growth_coin_b),
            position.liquidity,
            bluefin::constants::q64()
        );

        assert!(
            fee_delta_a <= (bluefin::constants::max_u64() as u128) && 
            fee_delta_b <= (bluefin::constants::max_u64() as u128),
            bluefin::errors::invalid_fee_growth()
        );

        assert!(
            math_library::math_u64::add_check(position.token_a_fee, fee_delta_a as u64) && 
            math_library::math_u64::add_check(position.token_b_fee, fee_delta_b as u64),
            bluefin::errors::add_check_failed()
        );

        update_reward_infos(position, reward_growths_inside);
        position.liquidity = new_liquidity;
        position.fee_growth_coin_a = fee_growth_inside_a;
        position.fee_growth_coin_b = fee_growth_inside_b;
        position.token_a_fee = position.token_a_fee + (fee_delta_a as u64);
        position.token_b_fee = position.token_b_fee + (fee_delta_b as u64);
    }

    public(friend) fun new(
        pool_id: 0x2::object::ID,
        pool_name: 0x1::string::String,
        image_url: 0x1::string::String,
        coin_type_a: 0x1::string::String,
        coin_type_b: 0x1::string::String,
        position_index: u128,
        lower_tick: math_library::i32::I32,
        upper_tick: math_library::i32::I32,
        fee_rate: u64,
        ctx: &mut 0x2::tx_context::TxContext
    ): Position {
        Position {
            id: 0x2::object::new(ctx),
            pool_id,
            lower_tick,
            upper_tick,
            fee_rate,
            liquidity: 0,
            fee_growth_coin_a: 0,
            fee_growth_coin_b: 0,
            token_a_fee: 0,
            token_b_fee: 0,
            name: create_position_name(pool_name),
            coin_type_a,
            coin_type_b,
            description: create_position_description(pool_name),
            image_url,
            position_index,
            reward_infos: 0x1::vector::empty<PositionRewardInfo>(),
        }
    }

    fun create_position_description(pool_name: 0x1::string::String): 0x1::string::String {
        let description = 0x1::string::utf8(b"This NFT represents a liquidity position of a Bluefin ");
        0x1::string::append(&mut description, pool_name);
        0x1::string::append(&mut description, 0x1::string::utf8(b" pool. The owner of this NFT can modify or redeem the position"));
        description
    }

    fun create_position_name(pool_name: 0x1::string::String): 0x1::string::String {
        let name = 0x1::string::utf8(b"Bluefin Position, ");
        0x1::string::append(&mut name, pool_name);
        name
    }

    public fun coins_owed_reward(position: &Position, reward_index: u64): u64 {
        if (reward_index >= 0x1::vector::length(&position.reward_infos)) {
            0
        } else {
            0x1::vector::borrow(&position.reward_infos, reward_index).coins_owed_reward
        }
    }

    public(friend) fun decrease_reward_amount(position: &mut Position, reward_index: u64, amount: u64) {
        let reward_info = get_mutable_reward_info(position, reward_index);
        reward_info.coins_owed_reward = reward_info.coins_owed_reward - amount;
    }

    public(friend) fun del(position: Position): (0x2::object::ID, 0x2::object::ID, math_library::i32::I32, math_library::i32::I32) {
        assert!(is_empty(&position), bluefin::errors::non_empty_position());
        let Position { 
            id, pool_id, lower_tick, upper_tick, fee_rate: _, liquidity: _, 
            fee_growth_coin_a: _, fee_growth_coin_b: _, token_a_fee: _, 
            token_b_fee: _, name: _, coin_type_a: _, coin_type_b: _, 
            description: _, image_url: _, position_index: _, reward_infos: _ 
        } = position;
        0x2::object::delete(id);
        (0x2::object::id(&position), pool_id, lower_tick, upper_tick)
    }

    public fun get_accrued_fee(position: &Position): (u64, u64) {
        (position.token_a_fee, position.token_b_fee)
    }

    fun get_mutable_reward_info(position: &mut Position, reward_index: u64): &mut PositionRewardInfo {
        if (reward_index >= 0x1::vector::length(&position.reward_infos)) {
            let reward_info = PositionRewardInfo {
                reward_growth_inside_last: 0,
                coins_owed_reward: 0,
            };
            0x1::vector::push_back(&mut position.reward_infos, reward_info);
        };
        0x1::vector::borrow_mut(&mut position.reward_infos, reward_index)
    }

    fun init(witness: POSITION, ctx: &mut 0x2::tx_context::TxContext) {
        let keys = 0x1::vector::empty<0x1::string::String>();
        let values = 0x1::vector::empty<0x1::string::String>();

        let display_keys = vector[
            b"name", b"id", b"pool", b"coin_a", b"coin_b", b"link",
            b"image_url", b"description", b"project_url", b"creator"
        ];
        let display_values = vector[
            b"{name}", b"{id}", b"{pool_id}", b"{coin_type_a}", b"{coin_type_b}",
            b"https://trade.bluefin.io/spot-nft/id={id}", b"{image_url}",
            b"{description}", b"https://trade.bluefin.io", b"Bluefin"
        ];

        let i = 0;
        while (i < 0x1::vector::length(&display_keys)) {
            0x1::vector::push_back(&mut keys, 0x1::string::utf8(*0x1::vector::borrow(&display_keys, i)));
            0x1::vector::push_back(&mut values, 0x1::string::utf8(*0x1::vector::borrow(&display_values, i)));
            i = i + 1;
        };

        let publisher = 0x2::package::claim(witness, ctx);
        let display = 0x2::display::new_with_fields(&publisher, keys, values, ctx);
        0x2::display::update_version(&mut display);
        0x2::transfer::public_transfer(publisher, 0x2::tx_context::sender(ctx));
        0x2::transfer::public_transfer(display, 0x2::tx_context::sender(ctx));
    }

    public fun is_empty(position: &Position): bool {
        let is_rewards_empty = true;
        let i = 0;
        while (i < 0x1::vector::length(&position.reward_infos)) {
            if (0x1::vector::borrow(&position.reward_infos, i).coins_owed_reward != 0) {
                is_rewards_empty = false;
                break
            };
            i = i + 1;
        };
        is_rewards_empty && position.liquidity == 0
    }

    public fun liquidity(position: &Position): u128 {
        position.liquidity
    }

    public fun lower_tick(position: &Position): math_library::i32::I32 {
        position.lower_tick
    }

    public fun pool_id(position: &Position): 0x2::object::ID {
        position.pool_id
    }

    public(friend) fun set_fee_amounts(position: &mut Position, fee_amount_a: u64, fee_amount_b: u64) {
        position.token_a_fee = fee_amount_a;
        position.token_b_fee = fee_amount_b;
    }

    fun update_reward_infos(position: &mut Position, reward_growths_inside: vector<u128>) {
        let i = 0;
        while (i < 0x1::vector::length(&reward_growths_inside)) {
            let growth_inside = *0x1::vector::borrow(&reward_growths_inside, i);
            let reward_info = get_mutable_reward_info(position, i);
            
            let reward_delta = math_library::full_math_u128::mul_div_floor(
                math_library::math_u128::wrapping_sub(growth_inside, reward_info.reward_growth_inside_last),
                position.liquidity,
                bluefin::constants::q64()
            );

            assert!(
                reward_delta <= (bluefin::constants::max_u64() as u128) && 
                math_library::math_u64::add_check(reward_info.coins_owed_reward, reward_delta as u64),
                bluefin::errors::update_rewards_info_check_failed()
            );

            reward_info.reward_growth_inside_last = growth_inside;
            reward_info.coins_owed_reward = reward_info.coins_owed_reward + (reward_delta as u64);
            i = i + 1;
        };
    }

    public fun upper_tick(position: &Position): math_library::i32::I32 {
        position.upper_tick
    }
}