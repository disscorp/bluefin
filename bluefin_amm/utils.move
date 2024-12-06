module bluefin::utils {
    public fun add_delta(value: u128, delta: math_library::i128::I128) : u128 {
        let delta_abs = math_library::i128::abs_u128(delta);
        if (math_library::i128::is_neg(delta)) {
            assert!(value >= delta_abs, bluefin::errors::insufficient_liquidity());
            value - delta_abs
        } else {
            assert!(delta_abs < bluefin::constants::max_u128() - value, bluefin::errors::insufficient_liquidity());
            value + delta_abs
        }
    }

    public fun deposit_balance<CoinType>(
        target: &mut 0x2::balance::Balance<CoinType>,
        source: 0x2::balance::Balance<CoinType>,
        amount: u64
    ) : 0x2::balance::Balance<CoinType> {
        assert!(0x2::balance::value<CoinType>(&source) >= amount, bluefin::errors::insufficient_coin_balance());
        0x2::balance::join<CoinType>(target, 0x2::balance::split<CoinType>(&mut source, amount));
        source
    }

    public fun get_type_string<T>() : 0x1::string::String {
        0x1::string::utf8(0x1::ascii::into_bytes(0x1::type_name::into_string(0x1::type_name::get<T>())))
    }

    public fun overflow_add(a: u256, b: u256) : u256 {
        if (!math_library::math_u256::add_check(a, b)) {
            b - bluefin::constants::max_u256() - a - 1
        } else {
            a + b
        }
    }

    public fun timestamp_seconds(clock: &0x2::clock::Clock) : u64 {
        0x2::clock::timestamp_ms(clock) / 1000
    }

    public fun transfer_balance<CoinType>(
        balance: 0x2::balance::Balance<CoinType>,
        recipient: address,
        ctx: &mut 0x2::tx_context::TxContext
    ) {
        if (0x2::balance::value<CoinType>(&balance) > 0) {
            0x2::transfer::public_transfer<0x2::coin::Coin<CoinType>>(
                0x2::coin::from_balance<CoinType>(balance, ctx),
                recipient
            );
        } else {
            0x2::balance::destroy_zero<CoinType>(balance);
        }
    }

    public fun transfer_coin<CoinType>(coin: 0x2::coin::Coin<CoinType>, recipient: address) {
        if (0x2::coin::value<CoinType>(&coin) > 0) {
            0x2::transfer::public_transfer<0x2::coin::Coin<CoinType>>(coin, recipient);
        } else {
            0x2::coin::destroy_zero<CoinType>(coin);
        }
    }

    public fun u128_to_string(number: u128) : 0x1::string::String {
        if (number == 0) {
            return 0x1::string::utf8(b"0")
        };
        
        let digits = 0x1::vector::empty<u8>();
        while (number > 0) {
            let digit = (number % 10) as u8;
            number = number / 10;
            0x1::vector::push_back<u8>(&mut digits, digit + 48);
        };
        0x1::vector::reverse<u8>(&mut digits);
        0x1::string::utf8(digits)
    }

    public fun withdraw_balance<CoinType>(
        source: &mut 0x2::balance::Balance<CoinType>,
        amount: u64
    ) : 0x2::balance::Balance<CoinType> {
        assert!(0x2::balance::value<CoinType>(source) >= amount, bluefin::errors::insufficient_coin_balance());
        0x2::balance::split<CoinType>(source, amount)
    }
}