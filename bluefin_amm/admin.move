module bluefin::admin {
    struct AdminCap has key {
        id: 0x2::object::UID,
    }

    struct ProtocolFeeCap has key {
        id: 0x2::object::UID,
    }

    public entry fun update_pool_reward_emission<TokenA, TokenB, RewardToken>(
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<TokenA, TokenB>,
        emission_rate: u64,
        reward_coin: 0x2::coin::Coin<RewardToken>,
        duration: u64,
        clock: &0x2::clock::Clock,
        ctx: &0x2::tx_context::TxContext
    ) {
        bluefin::config::verify_version(global_config);
        let is_blue_reward = false;
        let is_reward_manager = bluefin::config::verify_reward_manager(global_config, 0x2::tx_context::sender(ctx));

        if (bluefin::utils::get_type_string<RewardToken>() == bluefin::constants::blue_reward_type()) {
            is_blue_reward = true;
            assert!(is_reward_manager, bluefin::errors::not_authorized());
        };

        assert!(
            bluefin::pool::verify_pool_manager<TokenA, TokenB>(pool, 0x2::tx_context::sender(ctx)) || is_reward_manager,
            bluefin::errors::not_authorized()
        );

        bluefin::pool::update_reward_infos<TokenA, TokenB>(
            pool,
            bluefin::utils::timestamp_seconds(clock)
        );

        bluefin::pool::update_pool_reward_emission<TokenA, TokenB, RewardToken>(
            pool,
            0x2::coin::into_balance<RewardToken>(reward_coin),
            emission_rate,
            duration,
            is_blue_reward
        );
    }

    public entry fun add_reward_manager(
        admin_cap: &AdminCap,
        global_config: &mut bluefin::config::GlobalConfig,
        manager_address: address
    ) {
        bluefin::config::verify_version(global_config);
        bluefin::config::set_reward_manager(global_config, manager_address);
    }

    public fun add_seconds_to_reward_emission<TokenA, TokenB, RewardToken>(
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<TokenA, TokenB>,
        seconds: u64,
        clock: &0x2::clock::Clock,
        ctx: &0x2::tx_context::TxContext
    ) {
        bluefin::config::verify_version(global_config);
        let is_blue_reward = false;
        let is_reward_manager = bluefin::config::verify_reward_manager(global_config, 0x2::tx_context::sender(ctx));

        if (bluefin::utils::get_type_string<RewardToken>() == bluefin::constants::blue_reward_type()) {
            is_blue_reward = true;
            assert!(is_reward_manager, bluefin::errors::not_authorized());
        };

        assert!(
            bluefin::pool::verify_pool_manager<TokenA, TokenB>(pool, 0x2::tx_context::sender(ctx)) || is_reward_manager,
            bluefin::errors::not_authorized()
        );

        bluefin::pool::update_reward_infos<TokenA, TokenB>(
            pool,
            bluefin::utils::timestamp_seconds(clock)
        );

        bluefin::pool::update_pool_reward_emission<TokenA, TokenB, RewardToken>(
            pool,
            0x2::balance::zero<RewardToken>(),
            seconds,
            0,
            is_blue_reward
        );
    }

    public entry fun claim_protocol_fee<TokenA, TokenB>(
        protocol_fee_cap: &ProtocolFeeCap,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<TokenA, TokenB>,
        amount_a: u64,
        amount_b: u64,
        recipient: address,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        bluefin::config::verify_version(global_config);
        let fee_a = bluefin::pool::get_protocol_fee_for_coin_a<TokenA, TokenB>(pool);
        let fee_b = bluefin::pool::get_protocol_fee_for_coin_b<TokenA, TokenB>(pool);

        assert!(amount_a <= fee_a, bluefin::errors::insufficient_amount());
        assert!(amount_b <= fee_b, bluefin::errors::insufficient_amount());

        bluefin::pool::set_protocol_fee_amount<TokenA, TokenB>(pool, fee_a - amount_a, fee_b - amount_b);
        let (balance_a, balance_b) = bluefin::pool::withdraw_balances<TokenA, TokenB>(pool, amount_a, amount_b);

        bluefin::utils::transfer_balance<TokenA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<TokenB>(balance_b, recipient, ctx);

        let (reserves_a, reserves_b) = bluefin::pool::coin_reserves<TokenA, TokenB>(pool);
        bluefin::events::emit_protocol_fee_collected(
            0x2::object::id<bluefin::pool::Pool<TokenA, TokenB>>(pool),
            0x2::tx_context::sender(ctx),
            recipient,
            amount_a,
            amount_b,
            reserves_a,
            reserves_b,
            bluefin::pool::sequence_number<TokenA, TokenB>(pool)
        );
    }

    fun init(ctx: &mut 0x2::tx_context::TxContext) {
        let admin_cap = AdminCap{id: 0x2::object::new(ctx)};
        let protocol_fee_cap = ProtocolFeeCap{id: 0x2::object::new(ctx)};
        let sender = 0x2::tx_context::sender(ctx);
        0x2::transfer::transfer<AdminCap>(admin_cap, sender);
        0x2::transfer::transfer<ProtocolFeeCap>(protocol_fee_cap, sender);
    }

    public entry fun initialize_pool_reward<TokenA, TokenB, RewardToken>(
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<TokenA, TokenB>,
        start_time: u64,
        emission_rate: u64,
        reward_coin: 0x2::coin::Coin<RewardToken>,
        reward_name: 0x1::string::String,
        reward_decimals: u8,
        duration: u64,
        clock: &0x2::clock::Clock,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        bluefin::config::verify_version(global_config);
        let is_blue_reward = false;
        let is_reward_manager = bluefin::config::verify_reward_manager(global_config, 0x2::tx_context::sender(ctx));

        if (bluefin::utils::get_type_string<RewardToken>() == bluefin::constants::blue_reward_type()) {
            is_blue_reward = true;
            assert!(is_reward_manager, bluefin::errors::not_authorized());
        };

        assert!(
            bluefin::pool::verify_pool_manager<TokenA, TokenB>(pool, 0x2::tx_context::sender(ctx)) || is_reward_manager,
            bluefin::errors::not_authorized()
        );

        assert!(
            start_time > bluefin::utils::timestamp_seconds(clock),
            bluefin::errors::invalid_timestamp()
        );

        bluefin::pool::add_reward_info<TokenA, TokenB, RewardToken>(
            pool,
            bluefin::pool::default_reward_info(
                bluefin::utils::get_type_string<RewardToken>(),
                reward_name,
                reward_decimals,
                start_time
            )
        );

        bluefin::pool::update_pool_reward_emission<TokenA, TokenB, RewardToken>(
            pool,
            0x2::coin::into_balance<RewardToken>(reward_coin),
            emission_rate,
            duration,
            is_blue_reward
        );
    }

    public entry fun transfer_admin_cap(
        global_config: &bluefin::config::GlobalConfig,
        admin_cap: AdminCap,
        new_admin: address
    ) {
        bluefin::config::verify_version(global_config);
        0x2::transfer::transfer<AdminCap>(admin_cap, new_admin);
        bluefin::events::emit_admin_cap_transfer_event(new_admin);
    }

    public entry fun transfer_protocol_fee_cap(
        global_config: &bluefin::config::GlobalConfig,
        protocol_fee_cap: ProtocolFeeCap,
        new_owner: address
    ) {
        bluefin::config::verify_version(global_config);
        0x2::transfer::transfer<ProtocolFeeCap>(protocol_fee_cap, new_owner);
        bluefin::events::emit_protocol_fee_cap_transfer_event(new_owner);
    }
}