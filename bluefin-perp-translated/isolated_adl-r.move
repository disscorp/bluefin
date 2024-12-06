module bluefin::isolated_adl {
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
        maker: address,
        taker: address,
        quantity: u128,
        allOrNothing: bool,
    }
    
    struct IMResponse has drop {
        fundsFlow: bluefin::signed_number::Number,
        pnl: bluefin::signed_number::Number,
    }
    
    struct TradeResponse has copy, drop {
        makerFundsFlow: bluefin::signed_number::Number,
        takerFundsFlow: bluefin::signed_number::Number,
    }
 
    fun apply_isolated_margin(position: &mut bluefin::position::UserPosition, trade_quantity: u128, trade_price: u128, error_code: u64) : IMResponse {
        let position_size = bluefin::position::qPos(*position);
        let margin = bluefin::position::margin(*position);
        let pnl_per_unit = bluefin::position::compute_pnl_per_unit(*position, trade_price);
        let new_position_size = position_size - trade_quantity;
        assert!(bluefin::signed_number::gte_uint(bluefin::signed_number::add_uint(bluefin::signed_number::add(bluefin::signed_number::from(bluefin::library::base_div(margin, position_size), true), pnl_per_unit), 100000), 0), bluefin::error::loss_exceeds_margin(error_code));
        bluefin::position::set_margin(position, margin * new_position_size / position_size);
        bluefin::position::set_oiOpen(position, bluefin::position::oiOpen(*position) * new_position_size / position_size);
        bluefin::position::set_qPos(position, new_position_size);
        IMResponse{
            fundsFlow : bluefin::signed_number::negative_number(bluefin::signed_number::sub_uint(bluefin::signed_number::mul_uint(bluefin::signed_number::negate(pnl_per_unit), trade_quantity), margin * trade_quantity / position_size)),
            pnl       : bluefin::signed_number::mul_uint(pnl_per_unit, trade_quantity),
        }
    }

    public(friend) fun makerFundsFlow(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.makerFundsFlow
    }

    public(friend) fun pack_trade_data(maker: address, taker: address, quantity: u128, all_or_nothing: bool) : TradeData {
        TradeData{
            maker,
            taker,
            quantity,
            allOrNothing : all_or_nothing,
        }
    }

    public(friend) fun takerFundsFlow(trade_response: TradeResponse) : bluefin::signed_number::Number {
        trade_response.takerFundsFlow
    }

    public(friend) fun trade(sender: address, perp: &mut bluefin::perpetual::PerpetualV2, trade_data: TradeData, tx_index: u128) : TradeResponse {
        let imr = bluefin::perpetual::imr_v2(perp);
        let mmr = bluefin::perpetual::mmr_v2(perp);
        let checks = bluefin::perpetual::checks_v2(perp);
        let positions = bluefin::perpetual::positions(perp);
        let oracle_price = bluefin::library::round(bluefin::perpetual::priceOracle_v2(perp), bluefin::evaluator::tickSize(checks));
        bluefin::evaluator::verify_min_max_price(checks, oracle_price);
        bluefin::evaluator::verify_qty_checks(checks, trade_data.quantity);
        let maker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.maker);
        let taker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.taker);
        verify_trade(maker_position, taker_position, trade_data, oracle_price);
        let trade_price = if (bluefin::position::isPosPositive(maker_position)) {
            bluefin::library::base_div(bluefin::position::oiOpen(maker_position) - bluefin::position::margin(maker_position), bluefin::position::qPos(maker_position))
        } else {
            bluefin::library::base_div(bluefin::position::oiOpen(maker_position) + bluefin::position::margin(maker_position), bluefin::position::qPos(maker_position))
        };
        let trade_quantity = bluefin::library::min(trade_data.quantity, bluefin::library::min(bluefin::position::qPos(maker_position), bluefin::position::qPos(taker_position)));
        let maker_im_response = apply_isolated_margin(sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, trade_data.maker), trade_quantity, trade_price, 0);
        let taker_im_response = apply_isolated_margin(sui::table::borrow_mut<address, bluefin::position::UserPosition>(positions, trade_data.taker), trade_quantity, trade_price, 1);
        let updated_maker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.maker);
        let updated_taker_position = *sui::table::borrow<address, bluefin::position::UserPosition>(positions, trade_data.taker);
        bluefin::position::verify_collat_checks(maker_position, updated_maker_position, imr, mmr, oracle_price, 3, 0);
        bluefin::position::verify_collat_checks(taker_position, updated_taker_position, imr, mmr, oracle_price, 3, 1);
        bluefin::position::emit_position_update_event(updated_maker_position, sender, 0, tx_index);
        bluefin::position::emit_position_update_event(updated_taker_position, sender, 0, tx_index);
        let trade_event = TradeExecutedV2{
            tx_index,
            sender,
            perpID        : sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp)),
            tradeType     : 3,
            maker         : trade_data.maker,
            taker         : trade_data.taker,
            makerMRO      : bluefin::position::mro(updated_maker_position),
            takerMRO      : bluefin::position::mro(updated_taker_position),
            makerPnl      : maker_im_response.pnl,
            takerPnl      : taker_im_response.pnl,
            tradeQuantity : trade_data.quantity,
            tradePrice,
            isBuy         : bluefin::position::isPosPositive(maker_position),
        };
        sui::event::emit<TradeExecutedV2>(trade_event);
        TradeResponse{
            makerFundsFlow : maker_im_response.fundsFlow,
            takerFundsFlow : taker_im_response.fundsFlow,
        }
    }

    public(friend) fun tradeType() : u8 {
        3
    }

    fun verify_account(position: bluefin::position::UserPosition, trade_data: TradeData, error_code: u64) {
        assert!(bluefin::position::qPos(position) > 0, bluefin::error::user_position_size_is_zero(error_code));
        assert!(!trade_data.allOrNothing || bluefin::position::qPos(position) >= trade_data.quantity, bluefin::error::adl_all_or_nothing_constraint_can_not_be_held(error_code));
    }

    fun verify_trade(maker_position: bluefin::position::UserPosition, taker_position: bluefin::position::UserPosition, trade_data: TradeData, oracle_price: u128) {
        verify_account(maker_position, trade_data, 0);
        verify_account(taker_position, trade_data, 1);
        assert!(bluefin::signed_number::lte_uint(bluefin::position::compute_margin_ratio(maker_position, oracle_price), 0), bluefin::error::maker_is_not_underwater());
        assert!(bluefin::signed_number::gt_uint(bluefin::position::compute_margin_ratio(taker_position, oracle_price), 0), bluefin::error::taker_is_under_underwater());
        assert!(bluefin::position::isPosPositive(maker_position) != bluefin::position::isPosPositive(taker_position), bluefin::error::maker_taker_must_have_opposite_side_positions());
    }
}
