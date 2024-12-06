module bluefin::order {
    struct OrderFill has copy, drop {
        orderHash: vector<u8>,
        order: Order,
        sigMaker: address,
        fillPrice: u128,
        fillQty: u128,
        newFilledQuantity: u128,
    }
    
    struct OrderCancel has copy, drop {
        caller: address,
        sigMaker: address,
        perpetual: address,
        orderHash: vector<u8>,
    }
    
    struct OrderFillV2 has copy, drop {
        tx_index: u128,
        orderHash: vector<u8>,
        order: Order,
        sigMaker: address,
        fillPrice: u128,
        fillQty: u128,
        newFilledQuantity: u128,
    }
    
    struct OrderCancelV2 has copy, drop {
        tx_index: u128,
        caller: address,
        sigMaker: address,
        perpetual: address,
        orderHash: vector<u8>,
    }
    
    struct OrderFlags has copy, drop {
        ioc: bool,
        postOnly: bool,
        reduceOnly: bool,
        isBuy: bool,
        orderbookOnly: bool,
    }
    
    struct Order has copy, drop {
        market: address,
        maker: address,
        isBuy: bool,
        reduceOnly: bool,
        postOnly: bool,
        orderbookOnly: bool,
        ioc: bool,
        flags: u8,
        price: u128,
        quantity: u128,
        leverage: u128,
        expiration: u64,
        salt: u128,
    }
    
    struct OrderStatus has store {
        status: bool,
        filledQty: u128,
    }
    
    entry fun cancel_order(
        sub_accounts: &bluefin::roles::SubAccountsV2,
        sequencer: &mut bluefin::roles::Sequencer,
        orders: &mut sui::table::Table<vector<u8>, OrderStatus>,
        perpetual: address,
        flags: u8,
        price: u128,
        quantity: u128,
        leverage: u128,
        expiration: u64,
        salt: u128,
        maker: address,
        signature: vector<u8>,
        public_key: vector<u8>,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        bluefin::roles::validate_sub_accounts_version(sub_accounts);
        let sender = sui::tx_context::sender(ctx);
        
        assert!(
            sender == maker || bluefin::roles::is_sub_account_v2(sub_accounts, maker, sender),
            bluefin::error::sender_does_not_have_permission_for_account(2)
        );

        let serialized_order = get_serialized_order(
            pack_order(perpetual, flags, price, quantity, leverage, maker, expiration, salt)
        );
        let order_hash = bluefin::library::get_hash(serialized_order);
        
        create_order(orders, order_hash);
        let order_status = sui::table::borrow_mut<vector<u8>, OrderStatus>(orders, order_hash);
        assert!(order_status.status, bluefin::error::order_is_canceled(0));
        order_status.status = false;

        let cancel_event = OrderCancelV2{
            tx_index: bluefin::roles::validate_unique_tx_v2(sequencer, tx_data),
            caller: sender,
            signer_maker: verify_order_signature(sub_accounts, maker, serialized_order, signature, public_key, 0),
            perpetual,
            order_hash,
        };
        sui::event::emit<OrderCancelV2>(cancel_event);
    }

    public fun check_if_order_exists(orders: &sui::table::Table<vector<u8>, OrderStatus>, order_hash: vector<u8>) : bool {
        sui::table::contains<vector<u8>, OrderStatus>(orders, order_hash)
    }
    
    public(friend) fun create_order(
        orders: &mut sui::table::Table<vector<u8>, OrderStatus>,
        order_hash: vector<u8>
    ) {
        if (!sui::table::contains<vector<u8>, OrderStatus>(orders, order_hash)) {
            let order_status = OrderStatus{
                status: true,
                filled_qty: 0,
            };
            sui::table::add<vector<u8>, OrderStatus>(orders, order_hash, order_status);
        };
    }
    
    fun decode_order_flags(flags: u8) : OrderFlags {
        OrderFlags{
            ioc: flags & 1 > 0,
            post_only: flags & 2 > 0,
            reduce_only: flags & 4 > 0,
            is_buy: flags & 8 > 0,
            orderbook_only: flags & 16 > 0,
        }
    }
    
    public fun expiration(order: Order) : u64 {
        order.expiration
    }

    public fun flag_orderbook_only(flags: u8) : bool {
        flags & 16 > 0
    }

    public fun flags(order: Order) : u8 {
        order.flags
    }

    public fun get_serialized_order(order: Order) : vector<u8> {
        let serialized = std::vector::empty<u8>();
        let price_bytes = sui::bcs::to_bytes<u128>(&order.price);
        let qty_bytes = sui::bcs::to_bytes<u128>(&order.quantity);
        let leverage_bytes = sui::bcs::to_bytes<u128>(&order.leverage);
        let expiration_bytes = sui::bcs::to_bytes<u64>(&order.expiration);
        let salt_bytes = sui::bcs::to_bytes<u128>(&order.salt);
        let flags_bytes = sui::bcs::to_bytes<u8>(&order.flags);

        std::vector::reverse<u8>(&mut price_bytes);
        std::vector::reverse<u8>(&mut qty_bytes);
        std::vector::reverse<u8>(&mut leverage_bytes);
        std::vector::reverse<u8>(&mut expiration_bytes);
        std::vector::reverse<u8>(&mut salt_bytes);
        std::vector::reverse<u8>(&mut flags_bytes);

        std::vector::append<u8>(&mut serialized, price_bytes);
        std::vector::append<u8>(&mut serialized, qty_bytes);
        std::vector::append<u8>(&mut serialized, leverage_bytes);
        std::vector::append<u8>(&mut serialized, salt_bytes);
        std::vector::append<u8>(&mut serialized, expiration_bytes);
        std::vector::append<u8>(&mut serialized, sui::bcs::to_bytes<address>(&order.maker));
        std::vector::append<u8>(&mut serialized, sui::bcs::to_bytes<address>(&order.market));
        std::vector::append<u8>(&mut serialized, flags_bytes);
        std::vector::append<u8>(&mut serialized, b"Bluefin");
        
        serialized
    }
    
    public fun ioc(order: Order) : bool {
        order.ioc
    }

    public fun isBuy(order: Order) : bool {
        order.isBuy
    }

    public fun leverage(order: Order) : u128 {
        order.leverage
    }

    public fun maker(order: Order) : address {
        order.maker
    }

    public fun market(order: Order) : address {
        order.market
    }

    public fun orderbookOnly(order: Order) : bool {
        order.orderbookOnly
    }
    
    public fun pack_order(
        market_addr: address,
        flags: u8,
        price: u128,
        quantity: u128,
        leverage: u128,
        maker_addr: address,
        expiration: u64,
        salt: u128
    ) : Order {
        let decoded_flags = decode_order_flags(flags);
        Order{
            market: market_addr,
            maker: maker_addr,
            isBuy: decoded_flags.isBuy,
            reduceOnly: decoded_flags.reduceOnly,
            postOnly: decoded_flags.postOnly,
            orderbookOnly: decoded_flags.orderbookOnly,
            ioc: decoded_flags.ioc,
            flags,
            price,
            quantity,
            leverage,
            expiration,
            salt,
        }
    }
    
    public fun postOnly(order: Order) : bool {
        order.postOnly
    }

    public fun price(order: Order) : u128 {
        order.price
    }

    public fun quantity(order: Order) : u128 {
        order.quantity
    }

    public fun reduceOnly(order: Order) : bool {
        order.reduceOnly
    }

    public fun salt(order: Order) : u128 {
        order.salt
    }
    
    public(friend) fun set_leverage(order: &mut Order, new_leverage: u128) {
        order.leverage = new_leverage;
    }

    public(friend) fun set_price(order: &mut Order, new_price: u128) {
        order.price = new_price;
    }

    public fun to_1x9(order: Order) : Order {
        Order{
            market: order.market,
            maker: order.maker,
            isBuy: order.isBuy,
            reduceOnly: order.reduceOnly,
            postOnly: order.postOnly,
            orderbookOnly: order.orderbookOnly,
            ioc: order.ioc,
            flags: order.flags,
            price: order.price / bluefin::library::base_uint(),
            quantity: order.quantity / bluefin::library::base_uint(),
            leverage: order.leverage / bluefin::library::base_uint(),
            expiration: order.expiration,
            salt: order.salt,
        }
    }
    
    public(friend) fun verify_and_fill_order_qty(
        orders: &mut sui::table::Table<vector<u8>, OrderStatus>,
        order: Order,
        order_hash: vector<u8>,
        fill_price: u128,
        fill_qty: u128,
        is_taker_buy: bool,
        position_size: u128,
        signer_maker: address,
        error_offset: u64,
        tx_index: u128
    ) {
        assert!(
            order.isBuy && fill_price <= order.price || fill_price >= order.price,
            bluefin::error::fill_price_invalid(error_offset)
        );

        if (order.reduceOnly) {
            assert!(
                order.isBuy != is_taker_buy && fill_qty <= position_size,
                bluefin::error::fill_does_not_decrease_size(error_offset)
            );
        };

        let order_status = sui::table::borrow_mut<vector<u8>, OrderStatus>(orders, order_hash);
        order_status.filledQty = order_status.filledQty + fill_qty;
        
        assert!(
            order_status.filledQty <= order.quantity,
            bluefin::error::cannot_overfill_order(error_offset)
        );

        let fill_event = OrderFillV2{
            tx_index,
            orderHash: order_hash,
            order,
            sigMaker: signer_maker,
            fillPrice: fill_price,
            fillQty: fill_qty,
            newFilledQuantity: order_status.filledQty,
        };
        sui::event::emit<OrderFillV2>(fill_event);
    }
    
    public(friend) fun verify_order_expiry(
        expiration: u64,
        current_time: u64,
        error_offset: u64
    ) {
        assert!(
            expiration == 0 || expiration > current_time - 1800000,
            bluefin::error::order_expired(error_offset)
        );
    }

    public(friend) fun verify_order_leverage(
        target_mro: u128,
        leverage: u128,
        error_offset: u64
    ) {
        assert!(
            leverage > 0,
            bluefin::error::leverage_must_be_greater_than_zero(error_offset)
        );
        assert!(
            target_mro == 0 || bluefin::library::compute_mro(leverage) == target_mro,
            bluefin::error::invalid_leverage(error_offset)
        );
    }

    
    public(friend) fun verify_order_signature(
        sub_accounts: &bluefin::roles::SubAccountsV2,
        maker: address,
        serialized_order: vector<u8>,
        signature: vector<u8>,
        public_key: vector<u8>,
        error_offset: u64
    ) : address {
        let verify_result = bluefin::library::verify_signature(
            signature,
            public_key,
            sui::hex::encode(serialized_order)
        );
        
        assert!(
            bluefin::library::get_result_status(verify_result),
            bluefin::error::order_has_invalid_signature(error_offset)
        );

        let signer = if (std::vector::pop_back<u8>(&mut signature) == 3) {
            sui::address::from_bytes(public_key)
        } else {
            bluefin::library::get_public_address(
                bluefin::library::get_result_public_key(verify_result)
            )
        };

        assert!(
            maker == signer || bluefin::roles::is_sub_account_v2(sub_accounts, maker, signer),
            bluefin::error::order_has_invalid_signature(error_offset)
        );
        
        signer
    }
    
    public(friend) fun verify_order_state(
        orders: &sui::table::Table<vector<u8>, OrderStatus>,
        order_hash: vector<u8>,
        error_offset: u64
    ) {
        assert!(
            sui::table::borrow<vector<u8>, OrderStatus>(orders, order_hash).status,
            bluefin::error::order_is_canceled(error_offset)
        );
    }
}

