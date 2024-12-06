module bluefin::isolated_liquidation {
    struct TradeExecuted has copy, drop {
        sender: address,
        perpID: sui::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerMRO: u128,
        takerMRO: u128,
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
        makerMRO: u128,
        takerMRO: u128,
        makerPnl: bluefin::signed_number::Number,
        takerPnl: bluefin::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
    }
    
    struct TradeData has copy, drop {
        liquidator: address,
        liquidatee: address,
        quantity: u128,
        leverage: u128,
        allOrNothing: bool,
    }
    
    struct IMResponse has drop {
        fundsFlow: bluefin::signed_number::Number,
        pnl: bluefin::signed_number::Number,
    }
    
    struct Premium has copy, drop, store {
        pool: bluefin::signed_number::Number,
        liquidator: bluefin::signed_number::Number,
    }
    
    struct TradeResponse has copy, drop, store {
        makerFundsFlow: bluefin::signed_number::Number,
        takerFundsFlow: bluefin::signed_number::Number,
        premium: Premium,
    }
    
    fun apply_isolated_margin(
        position: &mut bluefin::position::UserPosition,
        trade_checks: bluefin::evaluator::TradeChecks,
        trade_quantity: u128,
        trade_price: u128,
        mark_price: u128,
        maintenance_margin_ratio: u128,
        is_buy: bool,
        error_code: u64
    ) : IMResponse {
        let position_size = bluefin::position::qPos(*position);
        let is_position_positive = bluefin::position::isPosPositive(*position);
        let current_margin = bluefin::position::margin(*position);
        let pnl_per_unit = bluefin::position::compute_pnl_per_unit(*position, trade_price);
        let total_pnl = pnl_per_unit;

        let funds_flow = if (position_size == 0 || is_buy == is_position_positive) {
            let required_margin = bluefin::library::base_mul(trade_price, maintenance_margin_ratio);
            bluefin::position::set_oiOpen(position, bluefin::position::oiOpen(*position) + bluefin::library::base_mul(trade_quantity, trade_price));
            bluefin::position::set_qPos(position, position_size + trade_quantity);
            bluefin::position::set_margin(position, current_margin + bluefin::library::base_mul(trade_quantity, required_margin));
            bluefin::position::set_isPosPositive(position, is_buy);
            bluefin::evaluator::verify_oi_open_for_account(trade_checks, maintenance_margin_ratio, bluefin::position::oiOpen(*position), error_code);
            total_pnl = bluefin::signed_number::new();
            bluefin::signed_number::from(bluefin::library::base_mul(trade_quantity, required_margin), true)
        } else {
            if (is_buy != is_position_positive && trade_quantity <= position_size) {
                let new_position_size = position_size - trade_quantity;
                let partial_close_funds_flow = if (error_code == 1) {
                    assert!(bluefin::signed_number::gte_uint(bluefin::signed_number::add_uint(pnl_per_unit, bluefin::library::base_div(current_margin, position_size)), 0), bluefin::error::loss_exceeds_margin(error_code));
                    bluefin::signed_number::negative_number(bluefin::signed_number::sub_uint(bluefin::signed_number::mul_uint(bluefin::signed_number::negate(pnl_per_unit), trade_quantity), current_margin * trade_quantity / position_size))
                } else {
                    total_pnl = bluefin::position::compute_pnl_per_unit(*position, mark_price);
                    bluefin::signed_number::new()
                };
                total_pnl = bluefin::signed_number::mul_uint(total_pnl, trade_quantity);
                bluefin::position::set_margin(position, current_margin * new_position_size / position_size);
                bluefin::position::set_oiOpen(position, bluefin::position::oiOpen(*position) * new_position_size / position_size);
                bluefin::position::set_qPos(position, new_position_size);
                partial_close_funds_flow
            } else {
                let flipped_quantity = trade_quantity - position_size;
                let new_open_interest = bluefin::library::base_mul(flipped_quantity, trade_price);
                let new_margin = bluefin::library::base_mul(new_open_interest, maintenance_margin_ratio);
                assert!(bluefin::signed_number::gte_uint(bluefin::signed_number::add_uint(pnl_per_unit, bluefin::library::base_div(current_margin, position_size)), 0), bluefin::error::loss_exceeds_margin(error_code));
                bluefin::evaluator::verify_oi_open_for_account(trade_checks, maintenance_margin_ratio, new_open_interest, error_code);
                total_pnl = bluefin::signed_number::mul_uint(pnl_per_unit, position_size);
                bluefin::position::set_qPos(position, flipped_quantity);
                bluefin::position::set_oiOpen(position, new_open_interest);
                bluefin::position::set_margin(position, new_margin);
                bluefin::position::set_isPosPositive(position, !is_position_positive);
                bluefin::signed_number::add_uint(bluefin::signed_number::sub_uint(bluefin::signed_number::mul_uint(bluefin::signed_number::negate(pnl_per_unit), position_size), current_margin), new_margin)
            }
        };
        bluefin::position::set_mro(position, maintenance_margin_ratio);
        IMResponse{
            fundsFlow : funds_flow,
            pnl       : total_pnl,
        }
    }
    
    fun calculate_premium(
        is_long: bool,
        position_size: u128,
        mark_price: u128,
        bankruptcy_price: u128,
        pool_cut: u128
    ) : Premium {
        let pool_premium = bluefin::signed_number::new();
        let (is_profitable, price_difference) = if (is_long) {
            (mark_price >= bankruptcy_price, bluefin::signed_number::from_subtraction(mark_price, bankruptcy_price))
        } else {
            (mark_price <= bankruptcy_price, bluefin::signed_number::from_subtraction(bankruptcy_price, mark_price))
        };
        let total_premium = bluefin::signed_number::mul_uint(price_difference, position_size);
        let liquidator_premium = if (is_profitable) {
            pool_premium = bluefin::signed_number::mul_uint(total_premium, pool_cut);
            bluefin::signed_number::mul_uint(total_premium, bluefin::library::base_uint() - pool_cut)
        } else {
            total_premium
        };
        Premium{
            pool       : pool_premium,
            liquidator : liquidator_premium,
        }
    }
    
    public(friend) fun insurancePoolPortion(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.premium.pool
    }

    public(friend) fun liquidatorPortion(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.premium.liquidator
    }

    public(friend) fun makerFundsFlow(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.makerFundsFlow
    }

    public(friend) fun pack_trade_data(liquidator_addr: address, liquidatee_addr: address, trade_quantity: u128, trade_leverage: u128, is_all_or_nothing: bool) : TradeData {
        TradeData{
            liquidator   : liquidator_addr,
            liquidatee   : liquidatee_addr,
            quantity     : trade_quantity,
            leverage     : trade_leverage,
            allOrNothing : is_all_or_nothing,
        }
    }

    public(friend) fun takerFundsFlow(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.takerFundsFlow
    }    

    public(friend) fun trade(sender: address, perp: &mut bluefin::perpetual::PerpetualV2, trade_data: TradeData, tx_index: u128) : TradeResponse {
        let initial_margin_ratio = bluefin::perpetual::imr_v2(perp);
        let maintenance_margin_ratio = bluefin::perpetual::mmr_v2(perp);
        let trade_checks = bluefin::perpetual::checks_v2(perp);
        let positions = bluefin::perpetual::positions(perp);
        let oracle_price = bluefin::library::round(bluefin::perpetual::priceOracle_v2(perp), bluefin::evaluator::tickSize(trade_checks));
        bluefin::evaluator::verify_min_max_price(trade_checks, oracle_price);
        bluefin::evaluator::verify_qty_checks(trade_checks, trade_data.quantity);
        let liquidatee_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.liquidatee);
        let liquidator_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.liquidator);
        let is_liquidatee_long = bluefin::position::isPosPositive(liquidatee_position);
        verify_trade(trade_data, liquidatee_position, liquidator_position, oracle_price, maintenance_margin_ratio);
        let bankruptcy_price = if (bluefin::position::isPosPositive(liquidatee_position)) {
            bluefin::library::base_div(bluefin::position::oiOpen(liquidatee_position) - bluefin::position::margin(liquidatee_position), bluefin::position::qPos(liquidatee_position))
        } else {
            bluefin::library::base_div(bluefin::position::oiOpen(liquidatee_position) + bluefin::position::margin(liquidatee_position), bluefin::position::qPos(liquidatee_position))
        };
        let liquidation_quantity = bluefin::library::min(trade_data.quantity, bluefin::position::qPos(liquidatee_position));
        let liquidatee_im_response = apply_isolated_margin(sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, trade_data.liquidatee), trade_checks, liquidation_quantity, oracle_price, bankruptcy_price, bluefin::position::mro(liquidatee_position), !bluefin::position::isPosPositive(liquidatee_position), 0);
        let liquidator_im_response = apply_isolated_margin(sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, trade_data.liquidator), trade_checks, liquidation_quantity, oracle_price, bankruptcy_price, bluefin::library::compute_mro(trade_data.leverage), bluefin::position::isPosPositive(liquidatee_position), 1);
        let updated_liquidatee_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.liquidatee);
        let updated_liquidator_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.liquidator);
        bluefin::position::verify_collat_checks(liquidatee_position, updated_liquidatee_position, initial_margin_ratio, maintenance_margin_ratio, oracle_price, 2, 0);
        bluefin::position::verify_collat_checks(liquidator_position, updated_liquidator_position, initial_margin_ratio, maintenance_margin_ratio, oracle_price, 2, 1);
        let premium = calculate_premium(is_liquidatee_long, liquidation_quantity, oracle_price, bankruptcy_price, bluefin::perpetual::poolPercentage_v2(perp));
        liquidator_im_response.pnl = bluefin::signed_number::add(premium.liquidator, liquidator_im_response.pnl);
        bluefin::position::emit_position_update_event(updated_liquidatee_position, sender, 0, tx_index);
        bluefin::position::emit_position_update_event(updated_liquidator_position, sender, 0, tx_index);
        let trade_event = TradeExecutedV2{
            tx_index,
            sender,
            perpID        : sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp)),
            tradeType     : 2,
            maker         : trade_data.liquidatee,
            taker         : trade_data.liquidator,
            makerMRO      : bluefin::position::mro(updated_liquidatee_position),
            takerMRO      : bluefin::position::mro(updated_liquidator_position),
            makerPnl      : liquidatee_im_response.pnl,
            takerPnl      : liquidator_im_response.pnl,
            tradeQuantity : trade_data.quantity,
            tradePrice    : oracle_price,
            isBuy         : is_liquidatee_long,
        };
        sui::event::emit<TradeExecutedV2>(trade_event);
        TradeResponse{
            makerFundsFlow : liquidatee_im_response.fundsFlow,
            takerFundsFlow : liquidator_im_response.fundsFlow,
            premium,
        }
    }
    
    public(friend) fun tradeType() : u8 {
        2
    }
    
    fun verify_trade(
        trade_data: TradeData,
        liquidatee_position: bluefin::position::UserPosition,
        liquidator_position: bluefin::position::UserPosition,
        oracle_price: u128,
        maintenance_margin_ratio: u128
    ) {
        assert!(bluefin::position::qPos(liquidatee_position) > 0, bluefin::error::user_position_size_is_zero(0));
        assert!(
            !trade_data.allOrNothing || bluefin::position::qPos(liquidatee_position) >= trade_data.quantity,
            bluefin::error::liquidation_all_or_nothing_constraint_not_held()
        );
        assert!(
            bluefin::position::is_undercollat(liquidatee_position, oracle_price, maintenance_margin_ratio),
            bluefin::error::liquidatee_above_mmr()
        );
        assert!(
            bluefin::position::mro(liquidator_position) == 0 ||
            bluefin::library::compute_mro(trade_data.leverage) == bluefin::position::mro(liquidator_position),
            bluefin::error::invalid_liquidator_leverage()
        );
    }
}

