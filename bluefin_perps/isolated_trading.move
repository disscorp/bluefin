module 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::isolated_trading {
    struct TradeExecuted has copy, drop {
        sender: address,
        perpID: 0x2::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        takerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
    }
    
    struct TradeExecutedV2 has copy, drop {
        tx_index: u128,
        sender: address,
        perpID: 0x2::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        takerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        tradeQuantity: u128,
        tradePrice: u128,
        isBuy: bool,
    }
    
    struct TradeExecutedV3 has copy, drop {
        tx_index: u128,
        sender: address,
        perpID: 0x2::object::ID,
        tradeType: u8,
        maker: address,
        taker: address,
        makerOrderHash: vector<u8>,
        takerOrderHash: vector<u8>,
        makerMRO: u128,
        takerMRO: u128,
        makerFee: u128,
        takerFee: u128,
        makerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        takerPnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
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
        makerOrder: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::Order,
        takerOrder: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::Order,
        fill: Fill,
        currentTime: u64,
    }
    
    struct Fill has copy, drop {
        quantity: u128,
        price: u128,
    }
    
    struct IMResponse has drop {
        fundsFlow: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        pnl: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        fee: u128,
    }
    
    struct TradeResponse has copy, drop, store {
        makerFundsFlow: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        takerFundsFlow: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        fee: u128,
    }
    
    struct TradeResponseV2 has copy, drop, store {
        makerFundsFlow: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        takerFundsFlow: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number,
        fee: u128,
        gas_charges_maker: u128,
        gas_charges_taker: u128,
    }
    
    fun apply_isolated_margin(arg0: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::TradeChecks, arg1: &mut 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition, arg2: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::Order, arg3: Fill, arg4: u128, arg5: u64) : IMResponse {
        let v0 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::isBuy(arg2);
        let v1 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::qPos(*arg1);
        let v2 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::isPosPositive(*arg1);
        let v3 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::margin(*arg1);
        let v4 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::compute_mro(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::leverage(arg2));
        let v5 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::compute_pnl_per_unit(*arg1, arg3.price);
        let (v6, v7) = if (v1 == 0 || v0 == v2) {
            let v8 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.price, v4);
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_oiOpen(arg1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::oiOpen(*arg1) + 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.quantity, arg3.price));
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_qPos(arg1, v1 + arg3.quantity);
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_margin(arg1, v3 + 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.quantity, v8));
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_isPosPositive(arg1, v0);
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::verify_oi_open_for_account(arg0, v4, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::oiOpen(*arg1), arg5);
            (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::from(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.quantity, v8 + arg4), true), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::new())
        } else {
            let v9 = if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::reduceOnly(arg2)) {
                true
            } else {
                let v10 = v0 != v2 && arg3.quantity <= v1;
                v10
            };
            if (v9) {
                let v11 = v1 - arg3.quantity;
                let v12 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::add_uint(v5, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_div(v3, v1));
                assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gte_uint(v12, 0), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::loss_exceeds_margin(arg5));
                let v13 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::positive_value(v12);
                let v14 = if (arg4 > v13) {
                    v13
                } else {
                    arg4
                };
                arg4 = v14;
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_margin(arg1, v3 * v11 / v1);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_oiOpen(arg1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::oiOpen(*arg1) * v11 / v1);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_qPos(arg1, v11);
                (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::negative_number(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::sub_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::mul_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::add_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::negate(v5), v14), arg3.quantity), v3 * arg3.quantity / v1)), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::mul_uint(v5, arg3.quantity))
            } else {
                let v15 = arg3.quantity - v1;
                let v16 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v15, arg3.price);
                let v17 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::add_uint(v5, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_div(v3, v1));
                assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gte_uint(v17, 0), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::loss_exceeds_margin(arg5));
                let v18 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::positive_value(v17);
                let v19 = if (arg4 > v18) {
                    v18
                } else {
                    arg4
                };
                let v6 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::add_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::sub_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::mul_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::add_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::negate(v5), v19), v1), v3), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v15, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.price, v4) + arg4));
                let v20 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v1, v19) + 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v15, arg4);
                arg4 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_div(v20, arg3.quantity);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::verify_oi_open_for_account(arg0, v4, v16, arg5);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_qPos(arg1, v15);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_oiOpen(arg1, v16);
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_margin(arg1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v15, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg3.price, v4)));
                0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_isPosPositive(arg1, !v2);
                (v6, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::mul_uint(v5, v1))
            }
        };
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::set_mro(arg1, v4);
        IMResponse{
            fundsFlow : v6, 
            pnl       : v7, 
            fee       : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg4, arg3.quantity),
        }
    }
    
    fun compute_gas_fee(arg0: &0x2::table::Table<vector<u8>, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::OrderStatus>, arg1: vector<u8>, arg2: bool) : u128 {
        if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::check_if_order_exists(arg0, arg1)) {
            return 0
        };
        if (arg2) {
            0
        } else {
            30000000
        }
    }
    
    public(friend) fun fee(arg0: TradeResponseV2) : u128 {
        arg0.fee
    }
    
    fun init(arg0: &mut 0x2::tx_context::TxContext) {
        0x2::transfer::public_share_object<0x2::table::Table<vector<u8>, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::OrderStatus>>(0x2::table::new<vector<u8>, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::OrderStatus>(arg0));
    }
    
    public(friend) fun makerFundsFlow(arg0: TradeResponseV2) : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number {
        arg0.makerFundsFlow
    }
    
    public(friend) fun pack_trade_data(arg0: u8, arg1: u128, arg2: u128, arg3: u128, arg4: address, arg5: u64, arg6: u128, arg7: vector<u8>, arg8: vector<u8>, arg9: u8, arg10: u128, arg11: u128, arg12: u128, arg13: address, arg14: u64, arg15: u128, arg16: vector<u8>, arg17: vector<u8>, arg18: u128, arg19: u128, arg20: address, arg21: u64) : TradeData {
        let v0 = Fill{
            quantity : arg18, 
            price    : arg19,
        };
        TradeData{
            makerSignature : arg7, 
            takerSignature : arg16, 
            makerPublicKey : arg8, 
            takerPublicKey : arg17, 
            makerOrder     : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::pack_order(arg20, arg0, arg1, arg2, arg3, arg4, arg5, arg6), 
            takerOrder     : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::pack_order(arg20, arg9, arg10, arg11, arg12, arg13, arg14, arg15), 
            fill           : v0, 
            currentTime    : arg21,
        }
    }
    
    public(friend) fun takerFundsFlow(arg0: TradeResponseV2) : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number {
        arg0.takerFundsFlow
    }
    
    public(friend) fun taker_gas_charges(arg0: TradeResponseV2) : u128 {
        arg0.gas_charges_taker
    }
    
    public(friend) fun trade(arg0: address, arg1: &mut 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::PerpetualV2, arg2: &mut 0x2::table::Table<vector<u8>, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::OrderStatus>, arg3: &0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::roles::SubAccountsV2, arg4: TradeData, arg5: u128) : TradeResponseV2 {
        let v0 = arg4;
        v0.fill.quantity = v0.fill.quantity / 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_uint();
        v0.fill.price = v0.fill.price / 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_uint();
        v0.makerOrder = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::to_1x9(v0.makerOrder);
        v0.takerOrder = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::to_1x9(v0.takerOrder);
        let v1 = v0.fill;
        let v2 = v0.currentTime;
        let v3 = &mut v0.makerOrder;
        let v4 = &mut v0.takerOrder;
        assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::isBuy(*v3) != 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::isBuy(*v4), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::order_cannot_be_of_same_side());
        let v5 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::get_serialized_order(arg4.makerOrder);
        let v6 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::get_serialized_order(arg4.takerOrder);
        let v7 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_hash(v5);
        let v8 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_hash(v6);
        let v9 = compute_gas_fee(arg2, v8, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::is_whitelisted_for_special_fee(arg1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4)));
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::create_order(arg2, v7);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::create_order(arg2, v8);
        if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::price(*v4) == 0) {
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::set_price(v4, v1.price);
        };
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::set_leverage(v3, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::round_down(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::leverage(*v3)));
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::set_leverage(v4, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::round_down(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::leverage(*v4)));
        let v10 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::priceOracle_v2(arg1);
        let v11 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::checks_v2(arg1);
        let v12 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::imr_v2(arg1);
        let v13 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::mmr_v2(arg1);
        let v14 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::positions(arg1);
        let v15 = *0x2::table::borrow<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3));
        let v16 = *0x2::table::borrow<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4));
        verify_order(v15, arg2, arg3, *v3, v5, v7, v0.makerSignature, v0.makerPublicKey, v1, v2, 0, arg5);
        verify_order(v16, arg2, arg3, *v4, v6, v8, v0.takerSignature, v0.takerPublicKey, v1, v2, 1, arg5);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::verify_price_checks(v11, v1.price);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::verify_qty_checks(v11, v1.quantity);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::evaluator::verify_market_take_bound_checks(v11, v1.price, v10, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::isBuy(*v4));
        if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3) == 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4)) {
            return TradeResponseV2{
                makerFundsFlow    : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::new(), 
                takerFundsFlow    : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::new(), 
                fee               : 0, 
                gas_charges_maker : 0, 
                gas_charges_taker : v9,
            }
        };
        let v17 = apply_isolated_margin(v11, 0x2::table::borrow_mut<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3)), *v3, v1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v1.price, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::get_fee_v2(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3), arg1, true)), 0);
        let v18 = apply_isolated_margin(v11, 0x2::table::borrow_mut<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4)), *v4, v1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(v1.price, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::get_fee_v2(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4), arg1, false)), 1);
        let v19 = *0x2::table::borrow<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3));
        let v20 = *0x2::table::borrow<address, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition>(v14, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4));
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::verify_collat_checks(v15, v19, v12, v13, v10, 1, 0);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::verify_collat_checks(v16, v20, v12, v13, v10, 1, 1);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::emit_position_update_event(v19, arg0, 0, arg5);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::emit_position_update_event(v20, arg0, 0, arg5);
        let v21 = TradeExecutedV3{
            tx_index        : arg5, 
            sender          : arg0, 
            perpID          : 0x2::object::uid_to_inner(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::perpetual::id_v2(arg1)), 
            tradeType       : 1, 
            maker           : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v3), 
            taker           : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(*v4), 
            makerOrderHash  : v7, 
            takerOrderHash  : v8, 
            makerMRO        : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::mro(v19), 
            takerMRO        : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::mro(v20), 
            makerFee        : v17.fee, 
            takerFee        : v18.fee, 
            makerPnl        : v17.pnl, 
            takerPnl        : v18.pnl, 
            tradeQuantity   : v1.quantity, 
            tradePrice      : v1.price, 
            isBuy           : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::isBuy(*v4), 
            gasChargesMaker : 0, 
            gasChargesTaker : v9,
        };
        0x2::event::emit<TradeExecutedV3>(v21);
        TradeResponseV2{
            makerFundsFlow    : v17.fundsFlow, 
            takerFundsFlow    : v18.fundsFlow, 
            fee               : v18.fee + v17.fee, 
            gas_charges_maker : 0, 
            gas_charges_taker : v9,
        }
    }
    
    public(friend) fun tradeType() : u8 {
        1
    }
    
    fun verify_order(arg0: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::UserPosition, arg1: &mut 0x2::table::Table<vector<u8>, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::OrderStatus>, arg2: &0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::roles::SubAccountsV2, arg3: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::Order, arg4: vector<u8>, arg5: vector<u8>, arg6: vector<u8>, arg7: vector<u8>, arg8: Fill, arg9: u64, arg10: u64, arg11: u128) {
        assert!(arg10 == 0 || !0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::postOnly(arg3), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::taker_order_can_not_be_post_only());
        assert!(arg10 == 1 || !0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::ioc(arg3), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::maker_order_can_not_be_ioc());
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::verify_order_state(arg1, arg5, arg10);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::verify_order_expiry(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::expiration(arg3), arg9, arg10);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::verify_order_leverage(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::mro(arg0), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::leverage(arg3), arg10);
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::verify_and_fill_order_qty(arg1, arg3, arg5, arg8.price, arg8.quantity, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::isPosPositive(arg0), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position::qPos(arg0), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::verify_order_signature(arg2, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::maker(arg3), arg4, arg6, arg7, arg10), arg10, arg11);
    }
    
    // decompiled from Move bytecode v6
}

