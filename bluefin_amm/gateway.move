module bluefin::gateway {
    public entry fun close_position<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: bluefin::position::Position,
        recipient: address,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let (balance_a, balance_b) = bluefin::pool::close_position<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            position
        );
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, recipient, ctx);
    }

    public entry fun collect_fee<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut bluefin::position::Position,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let recipient = 0x2::tx_context::sender(ctx);
        let (_, _, balance_a, balance_b) = bluefin::pool::collect_fee<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            position
        );
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, recipient, ctx);
    }

    public fun collect_reward<CoinTypeA, CoinTypeB, RewardType>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut bluefin::position::Position,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        bluefin::utils::transfer_balance<RewardType>(
            bluefin::pool::collect_reward<CoinTypeA, CoinTypeB, RewardType>(
                clock,
                global_config,
                pool,
                position
            ),
            0x2::tx_context::sender(ctx),
            ctx
        );
    }

    public entry fun create_pool<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        coin_a_type: vector<u8>,
        coin_a_symbol: vector<u8>,
        coin_a_name: vector<u8>,
        coin_a_decimals: u8,
        coin_b_type: vector<u8>,
        coin_b_symbol: vector<u8>,
        coin_b_decimals: u8,
        coin_b_url: vector<u8>,
        tick_spacing: u32,
        fee_rate: u64,
        init_sqrt_price: u128,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        bluefin::pool::new<CoinTypeA, CoinTypeB>(
            clock,
            coin_a_type,
            coin_a_symbol,
            coin_a_name,
            coin_a_decimals,
            coin_b_type,
            coin_b_symbol,
            coin_b_decimals,
            coin_b_url,
            tick_spacing,
            fee_rate,
            init_sqrt_price,
            ctx
        );
    }

    public entry fun flash_swap<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: 0x2::coin::Coin<CoinTypeA>,
        coin_b: 0x2::coin::Coin<CoinTypeB>,
        is_a_to_b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let (balance_a, balance_b, swap_state) = bluefin::pool::flash_swap<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            is_a_to_b,
            by_amount_in,
            amount,
            sqrt_price_limit
        );

        let pay_amount = bluefin::pool::swap_pay_amount<CoinTypeA, CoinTypeB>(&swap_state);
        let receive_amount = if (is_a_to_b) {
            0x2::balance::value<CoinTypeB>(&balance_b)
        } else {
            0x2::balance::value<CoinTypeA>(&balance_a)
        };

        if (by_amount_in) {
            assert!(receive_amount >= amount_limit, bluefin::errors::slippage_exceeds());
        } else {
            assert!(pay_amount <= amount_limit, bluefin::errors::slippage_exceeds());
        };

        let (repay_balance_a, repay_balance_b) = if (is_a_to_b) {
            (
                0x2::coin::into_balance<CoinTypeA>(0x2::coin::split<CoinTypeA>(&mut coin_a, pay_amount, ctx)),
                0x2::balance::zero<CoinTypeB>()
            )
        } else {
            (
                0x2::balance::zero<CoinTypeA>(),
                0x2::coin::into_balance<CoinTypeB>(0x2::coin::split<CoinTypeB>(&mut coin_b, pay_amount, ctx))
            )
        };

        0x2::coin::join<CoinTypeA>(&mut coin_a, 0x2::coin::from_balance<CoinTypeA>(balance_a, ctx));
        0x2::coin::join<CoinTypeB>(&mut coin_b, 0x2::coin::from_balance<CoinTypeB>(balance_b, ctx));

        bluefin::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            repay_balance_a,
            repay_balance_b,
            swap_state
        );

        bluefin::utils::transfer_coin<CoinTypeA>(coin_a, 0x2::tx_context::sender(ctx));
        bluefin::utils::transfer_coin<CoinTypeB>(coin_b, 0x2::tx_context::sender(ctx));
    }

        public entry fun remove_liquidity<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut bluefin::position::Position,
        liquidity_amount: u128,
        min_amount_a: u64,
        min_amount_b: u64,
        recipient: address,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let (amount_a, amount_b, balance_a, balance_b) = bluefin::pool::remove_liquidity<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            position,
            liquidity_amount,
            clock
        );
        assert!(amount_a >= min_amount_a && amount_b >= min_amount_b, bluefin::errors::slippage_exceeds());
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, recipient, ctx);
    }

    public entry fun provide_liquidity<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut bluefin::position::Position,
        coin_a: 0x2::coin::Coin<CoinTypeA>,
        coin_b: 0x2::coin::Coin<CoinTypeB>,
        min_amount_a: u64,
        min_amount_b: u64,
        liquidity: u128,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let recipient = 0x2::tx_context::sender(ctx);
        let (amount_a, amount_b, balance_a, balance_b) = bluefin::pool::add_liquidity<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            position,
            0x2::coin::into_balance<CoinTypeA>(coin_a),
            0x2::coin::into_balance<CoinTypeB>(coin_b),
            liquidity
        );
        assert!(amount_a >= min_amount_a && amount_b >= min_amount_b, bluefin::errors::slippage_exceeds());
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, recipient, ctx);
    }

    public entry fun provide_liquidity_with_fixed_amount<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        position: &mut bluefin::position::Position,
        coin_a: 0x2::coin::Coin<CoinTypeA>,
        coin_b: 0x2::coin::Coin<CoinTypeB>,
        fixed_amount: u64,
        max_amount_a: u64,
        max_amount_b: u64,
        is_coin_a: bool,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let recipient = 0x2::tx_context::sender(ctx);
        let (amount_a, amount_b, balance_a, balance_b) = bluefin::pool::add_liquidity_with_fixed_amount<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            position,
            0x2::coin::into_balance<CoinTypeA>(coin_a),
            0x2::coin::into_balance<CoinTypeB>(coin_b),
            fixed_amount,
            is_coin_a
        );
        assert!(amount_a <= max_amount_a && amount_b <= max_amount_b, bluefin::errors::slippage_exceeds());
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, recipient, ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, recipient, ctx);
    }

    public fun route_swap<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: 0x2::coin::Coin<CoinTypeA>,
        coin_b: 0x2::coin::Coin<CoinTypeB>,
        is_a_to_b: bool,
        by_amount_in: bool,
        exact_input: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        ctx: &mut 0x2::tx_context::TxContext
    ) : (0x2::coin::Coin<CoinTypeA>, 0x2::coin::Coin<CoinTypeB>) {
        if (by_amount_in && exact_input) {
            let coin_value = if (is_a_to_b) {
                0x2::coin::value<CoinTypeA>(&coin_a)
            } else {
                0x2::coin::value<CoinTypeB>(&coin_b)
            };
            amount = coin_value;
        };

        let (balance_a, balance_b, swap_state) = bluefin::pool::flash_swap<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            is_a_to_b,
            by_amount_in,
            amount,
            sqrt_price_limit
        );

        let pay_amount = bluefin::pool::swap_pay_amount<CoinTypeA, CoinTypeB>(&swap_state);
        let receive_amount = if (is_a_to_b) {
            0x2::balance::value<CoinTypeB>(&balance_b)
        } else {
            0x2::balance::value<CoinTypeA>(&balance_a)
        };

        if (by_amount_in) {
            assert!(receive_amount >= amount_limit, bluefin::errors::slippage_exceeds());
            assert!(pay_amount == amount, 1);
        } else {
            assert!(pay_amount <= amount_limit, bluefin::errors::slippage_exceeds());
            assert!(receive_amount == amount, 1);
        };

        let (repay_balance_a, repay_balance_b) = if (is_a_to_b) {
            (
                0x2::coin::into_balance<CoinTypeA>(0x2::coin::split<CoinTypeA>(&mut coin_a, pay_amount, ctx)),
                0x2::balance::zero<CoinTypeB>()
            )
        } else {
            (
                0x2::balance::zero<CoinTypeA>(),
                0x2::coin::into_balance<CoinTypeB>(0x2::coin::split<CoinTypeB>(&mut coin_b, pay_amount, ctx))
            )
        };

        0x2::coin::join<CoinTypeA>(&mut coin_a, 0x2::coin::from_balance<CoinTypeA>(balance_a, ctx));
        0x2::coin::join<CoinTypeB>(&mut coin_b, 0x2::coin::from_balance<CoinTypeB>(balance_b, ctx));

        bluefin::pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            global_config,
            pool,
            repay_balance_a,
            repay_balance_b,
            swap_state
        );

        (coin_a, coin_b)
    }

    public entry fun swap_assets<CoinTypeA, CoinTypeB>(
        clock: &0x2::clock::Clock,
        global_config: &bluefin::config::GlobalConfig,
        pool: &mut bluefin::pool::Pool<CoinTypeA, CoinTypeB>,
        coin_a: 0x2::coin::Coin<CoinTypeA>,
        coin_b: 0x2::coin::Coin<CoinTypeB>,
        is_a_to_b: bool,
        by_amount_in: bool,
        amount: u64,
        amount_limit: u64,
        sqrt_price_limit: u128,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        let (balance_a, balance_b) = bluefin::pool::swap<CoinTypeA, CoinTypeB>(
            clock,
            global_config,
            pool,
            0x2::coin::into_balance<CoinTypeA>(coin_a),
            0x2::coin::into_balance<CoinTypeB>(coin_b),
            is_a_to_b,
            by_amount_in,
            amount,
            amount_limit,
            sqrt_price_limit
        );
        bluefin::utils::transfer_balance<CoinTypeA>(balance_a, 0x2::tx_context::sender(ctx), ctx);
        bluefin::utils::transfer_balance<CoinTypeB>(balance_b, 0x2::tx_context::sender(ctx), ctx);
    }
}
