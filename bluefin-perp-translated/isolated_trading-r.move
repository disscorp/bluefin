module bluefin::isolated_trading {
    struct TradeExecuted has copy, drop {
        sender: address,
        perpID: sui::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: bluefin::signed_number::Number,
        takerPnl: bluefin::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
    }
    
    struct TradeExecutedV2 has copy, drop {
        tx_index: u128,
        sender: address,
        perpID: sui::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: bluefin::signed_number::Number,
        takerPnl: bluefin::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
    }
    
    struct TradeExecutedV3 has copy, drop {
        tx_index: u128,
        sender: address,
        perpID: sui::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: bluefin::signed_number::Number,
        takerPnl: bluefin::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
        gasChargesMaker: u128,
        gasChargesTaker: u128,
    }
    
    struct TradeData has copy, drop {
        makerSignature: vector<u8>,
        takerSignature: vector<u8>,
        makerPublicKey: vector<u8>,
        takerPublicKey: vector<u8>,
        makerOrder: bluefin::order::Order,
        takerOrder: bluefin::order::Order,
        fill: Fill,
        currentTime: u64,
    }
    
    struct Fill has copy, drop {
        quantity: u128,
        price: u128,
    }
    
    struct IMResponse has drop {
        fundsFlow: bluefin::signed_number::Number,
        pnl: bluefin::signed_number::Number,
        fee: u128,
    }
    
    struct TradeResponse has copy, drop, store {
        makerFundsFlow: bluefin::signed_number::Number,
        takerFundsFlow: bluefin::signed_number::Number,
        fee: u128,
    }
    
    struct TradeResponseV2 has copy, drop, store {
        makerFundsFlow: bluefin::signed_number::Number,
        takerFundsFlow: bluefin::signed_number::Number,
        fee: u128,
        gas_charges_maker: u128,
        gas_charges_taker: u128,
    }
    
    }

    // This function handles the margin calculations for isolated trading positions. It processes three main scenarios:
    // Opening a new position or adding to an existing position
    // Reducing an existing position
    // Flipping a position from long to short or vice versa
    // The function calculates required margins, fees, and PnL while maintaining position state and enforcing trading checks.
    fun apply_isolated_margin(
        trade_checks: bluefin::evaluator::TradeChecks,
        position: &mut bluefin::position::UserPosition,
        order: bluefin::order::Order,
        fill: Fill,
        fee_rate: u128,
        error_offset: u64
    ) : IMResponse {
        let is_buy = bluefin::order::isBuy(order);
        let position_size = bluefin::position::qPos(*position);
        let is_position_positive = bluefin::position::isPosPositive(*position);
        let current_margin = bluefin::position::margin(*position);
        let margin_ratio = bluefin::library::compute_mro(bluefin::order::leverage(order));
        let pnl_per_unit = bluefin::position::compute_pnl_per_unit(*position, fill.price);

        let (funds_flow, pnl) = if (position_size == 0 || is_buy == is_position_positive) {
            // Opening new position or adding to existing position
            let required_margin = bluefin::library::base_mul(fill.price, margin_ratio);
            bluefin::position::set_oiOpen(position, bluefin::position::oiOpen(*position) + bluefin::library::base_mul(fill.quantity, fill.price));
            bluefin::position::set_qPos(position, position_size + fill.quantity);
            bluefin::position::set_margin(position, current_margin + bluefin::library::base_mul(fill.quantity, required_margin));
            bluefin::position::set_isPosPositive(position, is_buy);
            bluefin::evaluator::verify_oi_open_for_account(trade_checks, margin_ratio, bluefin::position::oiOpen(*position), error_offset);
            
            (bluefin::signed_number::from(bluefin::library::base_mul(fill.quantity, required_margin + fee_rate), true), 
            bluefin::signed_number::new())
        } else {
            let is_reducing = if (bluefin::order::reduceOnly(order)) {
                true
            } else {
                is_buy != is_position_positive && fill.quantity <= position_size
            };

            if (is_reducing) {
                // Reducing existing position
                let new_position_size = position_size - fill.quantity;
                let total_per_unit = bluefin::signed_number::add_uint(pnl_per_unit, bluefin::library::base_div(current_margin, position_size));
                assert!(bluefin::signed_number::gte_uint(total_per_unit, 0), bluefin::error::loss_exceeds_margin(error_offset));
                
                let available_per_unit = bluefin::signed_number::positive_value(total_per_unit);
                let adjusted_fee_rate = if (fee_rate > available_per_unit) { available_per_unit } else { fee_rate };
                fee_rate = adjusted_fee_rate;
                
                bluefin::position::set_margin(position, current_margin * new_position_size / position_size);
                bluefin::position::set_oiOpen(position, bluefin::position::oiOpen(*position) * new_position_size / position_size);
                bluefin::position::set_qPos(position, new_position_size);
                
                (bluefin::signed_number::negative_number(bluefin::signed_number::sub_uint(
                    bluefin::signed_number::mul_uint(
                        bluefin::signed_number::add_uint(bluefin::signed_number::negate(pnl_per_unit), adjusted_fee_rate),
                        fill.quantity
                    ),
                    current_margin * fill.quantity / position_size
                )),
                bluefin::signed_number::mul_uint(pnl_per_unit, fill.quantity))
            } else {
                // Flipping position
                let flip_size = fill.quantity - position_size;
                let new_open_interest = bluefin::library::base_mul(flip_size, fill.price);
                let total_per_unit = bluefin::signed_number::add_uint(pnl_per_unit, bluefin::library::base_div(current_margin, position_size));
                
                assert!(bluefin::signed_number::gte_uint(total_per_unit, 0), bluefin::error::loss_exceeds_margin(error_offset));
                
                let available_per_unit = bluefin::signed_number::positive_value(total_per_unit);
                let adjusted_fee_rate = if (fee_rate > available_per_unit) { available_per_unit } else { fee_rate };
                
                let funds_flow = bluefin::signed_number::add_uint(
                    bluefin::signed_number::sub_uint(
                        bluefin::signed_number::mul_uint(
                            bluefin::signed_number::add_uint(bluefin::signed_number::negate(pnl_per_unit), adjusted_fee_rate),
                            position_size
                        ),
                        current_margin
                    ),
                    bluefin::library::base_mul(flip_size, bluefin::library::base_mul(fill.price, margin_ratio) + fee_rate)
                );

                let total_fees = bluefin::library::base_mul(position_size, adjusted_fee_rate) + 
                                bluefin::library::base_mul(flip_size, fee_rate);
                fee_rate = bluefin::library::base_div(total_fees, fill.quantity);

                bluefin::evaluator::verify_oi_open_for_account(trade_checks, margin_ratio, new_open_interest, error_offset);
                bluefin::position::set_qPos(position, flip_size);
                bluefin::position::set_oiOpen(position, new_open_interest);
                bluefin::position::set_margin(position, bluefin::library::base_mul(flip_size, bluefin::library::base_mul(fill.price, margin_ratio)));
                bluefin::position::set_isPosPositive(position, !is_position_positive);

                (funds_flow, bluefin::signed_number::mul_uint(pnl_per_unit, position_size))
            }
        };

        bluefin::position::set_mro(position, margin_ratio);
        
        IMResponse{
            fundsFlow: funds_flow,
            pnl: pnl,
            fee: bluefin::library::base_mul(fee_rate, fill.quantity),
        }
    }
 
    fun compute_gas_fee(
        orders: &sui::table::Table<vector<u8>, bluefin::order::OrderStatus>,
        order_hash: vector<u8>,
        is_whitelisted: bool
    ) : u128 {
        if (bluefin::order::check_if_order_exists(orders, order_hash)) {
            return 0
        };
        if (is_whitelisted) {
            0
        } else {
            10000000
        }
    }

    public(friend) fun fee(trade_response: TradeResponseV2) : u128 {
        trade_response.fee
    }

    fun init(ctx: &mut sui::tx_context::TxContext) {
        sui::transfer::public_share_object<sui::table::Table<vector<u8>, bluefin::order::OrderStatus>>(
            sui::table::new<vector<u8>, bluefin::order::OrderStatus>(ctx)
        );
    }

    public(friend) fun makerFundsFlow(trade_response: TradeResponseV2) : bluefin::signed_number::Number {
        trade_response.makerFundsFlow
    }
    
    public(friend) fun pack_trade_data(
        maker_flags: u8,
        maker_price: u128,
        maker_quantity: u128,
        maker_leverage: u128,
        maker_address: address,
        maker_expiration: u64,
        maker_salt: u128,
        maker_signature: vector<u8>,
        maker_public_key: vector<u8>,
        taker_flags: u8,
        taker_price: u128,
        taker_quantity: u128,
        taker_leverage: u128,
        taker_address: address,
        taker_expiration: u64,
        taker_salt: u128,
        taker_signature: vector<u8>,
        taker_public_key: vector<u8>,
        fill_quantity: u128,
        fill_price: u128,
        market_address: address,
        current_time: u64
    ) : TradeData {
        let fill = Fill{
            quantity: fill_quantity,
            price: fill_price,
        };
        TradeData{
            makerSignature: maker_signature,
            takerSignature: taker_signature,
            makerPublicKey: maker_public_key,
            takerPublicKey: taker_public_key,
            makerOrder: bluefin::order::pack_order(market_address, maker_flags, maker_price, maker_quantity, maker_leverage, maker_address, maker_expiration, maker_salt),
            takerOrder: bluefin::order::pack_order(market_address, taker_flags, taker_price, taker_quantity, taker_leverage, taker_address, taker_expiration, taker_salt),
            fill,
            currentTime: current_time,
        }
    }

    public(friend) fun takerFundsFlow(trade_response: TradeResponseV2) : bluefin::signed_number::Number {
        trade_response.takerFundsFlow
    }

    public(friend) fun taker_gas_charges(trade_response: TradeResponseV2) : u128 {
        trade_response.gas_charges_taker
    }
    
    /// Executes a trade between maker and taker orders, handling position updates, margin calculations, 
    /// collateral checks, and fee collection. Validates order signatures, prices, and quantities before 
    /// processing the trade and emitting relevant events.
    public(friend) fun trade(
        sender: address,
        perp: &mut bluefin::perpetual::PerpetualV2,
        orders: &mut sui::table::Table<vector<u8>, bluefin::order::OrderStatus>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        trade_data: TradeData,
        tx_index: u128
    ) : TradeResponseV2 {
        let normalized_trade = trade_data;
        normalized_trade.fill.quantity = normalized_trade.fill.quantity / bluefin::library::base_uint();
        normalized_trade.fill.price = normalized_trade.fill.price / bluefin::library::base_uint();
        normalized_trade.makerOrder = bluefin::order::to_1x9(normalized_trade.makerOrder);
        normalized_trade.takerOrder = bluefin::order::to_1x9(normalized_trade.takerOrder);

        let fill = normalized_trade.fill;
        let current_time = normalized_trade.currentTime;
        let maker_order = &mut normalized_trade.makerOrder;
        let taker_order = &mut normalized_trade.takerOrder;

        assert!(
            bluefin::order::isBuy(*maker_order) != bluefin::order::isBuy(*taker_order),
            bluefin::error::order_cannot_be_of_same_side()
        );

        let serialized_maker_order = bluefin::order::get_serialized_order(trade_data.makerOrder);
        let serialized_taker_order = bluefin::order::get_serialized_order(trade_data.takerOrder);
        let maker_order_hash = bluefin::library::get_hash(serialized_maker_order);
        let taker_order_hash = bluefin::library::get_hash(serialized_taker_order);
        
        let taker_gas_fee = compute_gas_fee(
            orders,
            taker_order_hash,
            bluefin::perpetual::is_whitelisted_for_special_fee(perp, bluefin::order::maker(*taker_order))
        );

        bluefin::order::create_order(orders, maker_order_hash);
        bluefin::order::create_order(orders, taker_order_hash);

        if (bluefin::order::price(*taker_order) == 0) {
            bluefin::order::set_price(taker_order, fill.price);
        };

        bluefin::order::set_leverage(maker_order, bluefin::library::round_down(bluefin::order::leverage(*maker_order)));
        bluefin::order::set_leverage(taker_order, bluefin::library::round_down(bluefin::order::leverage(*taker_order)));

        let oracle_price = bluefin::perpetual::priceOracle_v2(perp);
        let trade_checks = bluefin::perpetual::checks_v2(perp);
        let initial_margin_ratio = bluefin::perpetual::imr_v2(perp);
        let maintenance_margin_ratio = bluefin::perpetual::mmr_v2(perp);
        let positions = bluefin::perpetual::positions(perp);
        
        let maker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*maker_order));
        let taker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*taker_order));

        verify_order(
            maker_position, orders, sub_accounts, *maker_order, serialized_maker_order,
            maker_order_hash, normalized_trade.makerSignature, normalized_trade.makerPublicKey,
            fill, current_time, 0, tx_index
        );
        verify_order(
            taker_position, orders, sub_accounts, *taker_order, serialized_taker_order,
            taker_order_hash, normalized_trade.takerSignature, normalized_trade.takerPublicKey,
            fill, current_time, 1, tx_index
        );

        bluefin::evaluator::verify_price_checks(trade_checks, fill.price);
        bluefin::evaluator::verify_qty_checks(trade_checks, fill.quantity);
        bluefin::evaluator::verify_market_take_bound_checks(trade_checks, fill.price, oracle_price, bluefin::order::isBuy(*taker_order));

        if (bluefin::order::maker(*maker_order) == bluefin::order::maker(*taker_order)) {
            return TradeResponseV2{
                makerFundsFlow: bluefin::signed_number::new(),
                takerFundsFlow: bluefin::signed_number::new(),
                fee: 0,
                gas_charges_maker: 0,
                gas_charges_taker: taker_gas_fee,
            }
        };

        let maker_response = apply_isolated_margin(
            trade_checks,
            sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*maker_order)),
            *maker_order,
            fill,
            bluefin::library::base_mul(fill.price, bluefin::perpetual::get_fee_v2(bluefin::order::maker(*maker_order), perp, true)),
            0
        );

        let taker_response = apply_isolated_margin(
            trade_checks,
            sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*taker_order)),
            *taker_order,
            fill,
            bluefin::library::base_mul(fill.price, bluefin::perpetual::get_fee_v2(bluefin::order::maker(*taker_order), perp, false)),
            1
        );

        let updated_maker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*maker_order));
        let updated_taker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, bluefin::order::maker(*taker_order));

        bluefin::position::verify_collat_checks(maker_position, updated_maker_position, initial_margin_ratio, maintenance_margin_ratio, oracle_price, 1, 0);
        bluefin::position::verify_collat_checks(taker_position, updated_taker_position, initial_margin_ratio, maintenance_margin_ratio, oracle_price, 1, 1);

        bluefin::position::emit_position_update_event(updated_maker_position, sender, 0, tx_index);
        bluefin::position::emit_position_update_event(updated_taker_position, sender, 0, tx_index);

        let trade_event = TradeExecutedV3{
            tx_index,
            sender,
            perpID: sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp)),
            tradeType: 1,
            maker: bluefin::order::maker(*maker_order),
            taker: bluefin::order::maker(*taker_order),
            makerOrderHash: maker_order_hash,
            takerOrderHash: taker_order_hash,
            makerMRO: bluefin::position::mro(updated_maker_position),
            takerMRO: bluefin::position::mro(updated_taker_position),
            makerFee: maker_response.fee,
            takerFee: taker_response.fee,
            makerPnl: maker_response.pnl,
            takerPnl: taker_response.pnl,
            tradeQuantity: fill.quantity,
            tradePrice: fill.price,
            isBuy: bluefin::order::isBuy(*taker_order),
            gasChargesMaker: 0,
            gasChargesTaker: taker_gas_fee,
        };
        sui::event::emit<TradeExecutedV3>(trade_event);

        TradeResponseV2{
            makerFundsFlow: maker_response.fundsFlow,
            takerFundsFlow: taker_response.fundsFlow,
            fee: taker_response.fee + maker_response.fee,
            gas_charges_maker: 0,
            gas_charges_taker: taker_gas_fee,
        }
    }
    
    public(friend) fun tradeType() : u8 {
        1
    }
    
    fun verify_order(
        position: bluefin::position::UserPosition,
        orders: &mut sui::table::Table<vector<u8>, bluefin::order::OrderStatus>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        order: bluefin::order::Order,
        serialized_order: vector<u8>,
        order_hash: vector<u8>,
        signature: vector<u8>,
        public_key: vector<u8>,
        fill: Fill,
        current_time: u64,
        error_offset: u64,
        tx_index: u128
    ) {
        assert!(
            error_offset == 0 || !bluefin::order::postOnly(order),
            bluefin::error::taker_order_can_not_be_post_only()
        );
        assert!(
            error_offset == 1 || !bluefin::order::ioc(order),
            bluefin::error::maker_order_can_not_be_ioc()
        );

        bluefin::order::verify_order_state(orders, order_hash, error_offset);
        bluefin::order::verify_order_expiry(bluefin::order::expiration(order), current_time, error_offset);
        bluefin::order::verify_order_leverage(bluefin::position::mro(position), bluefin::order::leverage(order), error_offset);
        
        bluefin::order::verify_and_fill_order_qty(
            orders,
            order,
            order_hash,
            fill.price,
            fill.quantity,
            bluefin::position::isPosPositive(position),
            bluefin::position::qPos(position),
            bluefin::order::verify_order_signature(
                sub_accounts,
                bluefin::order::maker(order),
                serialized_order,
                signature,
                public_key,
                error_offset
            ),
            error_offset,
            tx_index
        );
    }
}

