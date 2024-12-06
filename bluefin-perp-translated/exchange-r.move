module bluefin::exchange {
    struct LiquidatorPaidForAccountSettlementEvnet has copy, drop {
        id: sui::object::ID,
        liquidator: address,
        account: address,
        amount: u128,
    }
    
    struct SettlementAmountNotPaidCompletelyEvent has copy, drop {
        account: address,
        amount: u128,
    }
    
    struct SettlementAmtDueByMakerEvent has copy, drop {
        account: address,
        amount: u128,
    }
    
    struct AccountSettlementUpdateEvent has copy, drop {
        account: address,
        balance: bluefin::position::UserPosition,
        settlementIsPositive: bool,
        settlementAmount: u128,
        price: u128,
        fundingRate: bluefin::signed_number::Number,
    }
    
    struct LiquidatorPaidForAccountSettlementEvnetV2 has copy, drop {
        tx_index: u128,
        id: sui::object::ID,
        liquidator: address,
        account: address,
        amount: u128,
    }
    
    struct SettlementAmountNotPaidCompletelyEventV2 has copy, drop {
        tx_index: u128,
        account: address,
        amount: u128,
    }
    
    struct SettlementAmtDueByMakerEventV2 has copy, drop {
        tx_index: u128,
        account: address,
        amount: u128,
    }
    
    struct AccountSettlementUpdateEventV2 has copy, drop {
        tx_index: u128,
        account: address,
        balance: bluefin::position::UserPosition,
        settlementIsPositive: bool,
        settlementAmount: u128,
        price: u128,
        fundingRate: bluefin::signed_number::Number,
    }
    
    entry fun trade<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        capabilities_safe: &bluefin::roles::CapabilitiesSafeV2,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        orders: &mut sui::table::Table<vector<u8>, bluefin::order::OrderStatus>,
        sequencer: &mut bluefin::roles::Sequencer,
        settlement_cap: &bluefin::roles::SettlementCap,
        price_info: &pyth_network::price_info::PriceInfoObject,
        maker_flags: u8,
        maker_price: u128,
        maker_quantity: u128,
        maker_leverage: u128,
        maker_expiration: u64,
        maker_salt: u128,
        maker_address: address,
        maker_signature: vector<u8>,
        maker_public_key: vector<u8>,
        taker_flags: u8,
        taker_price: u128,
        taker_quantity: u128,
        taker_leverage: u128,
        taker_expiration: u64,
        taker_salt: u128,
        taker_address: address,
        taker_signature: vector<u8>,
        taker_public_key: vector<u8>,
        fill_quantity: u128,
        fill_price: u128,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        // Version checks
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        
        // Validate roles and permissions
        bluefin::roles::validate_sub_accounts_version(sub_accounts);
        bluefin::roles::validate_safe_version(capabilities_safe);
        
        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);
        
        let sender = sui::tx_context::sender(ctx);
        
        // Trading checks
        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());
        assert!(bluefin::perpetual::is_trading_permitted_v2(perp), bluefin::error::trading_is_stopped_on_perpetual());
        assert!(sui::clock::timestamp_ms(clock) > bluefin::perpetual::startTime_v2(perp), bluefin::error::trading_not_started());
        
        bluefin::roles::check_settlement_operator_validity_v2(capabilities_safe, settlement_cap);
        
        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let perp_address = sui::object::id_to_address(&perp_id);
        
        // Initialize positions
        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), maker_address);
        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), taker_address);
        
        // Apply funding rates
        apply_funding_rate<CoinType>(tx_index, bank, perp, sender, maker_address, bluefin::isolated_trading::tradeType(), 0);
        apply_funding_rate<CoinType>(tx_index, bank, perp, sender, taker_address, bluefin::isolated_trading::tradeType(), 1);
        
        // Execute trade
        let trade_response = bluefin::isolated_trading::trade(
            sender, perp, orders, sub_accounts,
            bluefin::isolated_trading::pack_trade_data(
                maker_flags, maker_price, maker_quantity, maker_leverage, maker_address, maker_expiration,
                maker_salt, maker_signature, maker_public_key, taker_flags, taker_price, taker_quantity,
                taker_leverage, taker_address, taker_expiration, taker_salt, taker_signature,
                taker_public_key, fill_quantity, fill_price, perp_address, sui::clock::timestamp_ms(clock)
            ),
            tx_index
        );

        // Handle margin transfers
        bluefin::margin_bank::transfer_trade_margin<CoinType>(
            bank, perp_address, maker_address, taker_address,
            bluefin::isolated_trading::makerFundsFlow(trade_response),
            bluefin::isolated_trading::takerFundsFlow(trade_response),
            tx_index
        );

        // Handle fees
        let total_fee = bluefin::isolated_trading::fee(trade_response);
        if (total_fee > 0) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                bank, perp_address, bluefin::perpetual::feePool_v2(perp),
                total_fee, 2, tx_index
            );
        };

        // Handle gas charges
        let taker_gas = bluefin::isolated_trading::taker_gas_charges(trade_response);
        if (taker_gas > 0) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                bank, taker_address,
                @0xfddf022ecb6ec6667131e560ba3c24de3464181792312fcc468521ee0a49c7c5,
                taker_gas, 1, tx_index
            );
        };
    }
    
    entry fun add_margin<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        sequencer: &mut bluefin::roles::Sequencer,
        price_info: &pyth_network::price_info::PriceInfoObject,
        account: address,
        margin_amount: u128,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        // Version checks and validations
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_sub_accounts_version(sub_accounts);

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        let normalized_margin = margin_amount / bluefin::library::base_uint();
        
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);
        
        let sender = sui::tx_context::sender(ctx);
        assert!(sender == account || bluefin::roles::is_sub_account_v2(sub_accounts, account, sender), bluefin::error::sender_does_not_have_permission_for_account(2));
        
        // Checks
        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());
        assert!(normalized_margin > 0, bluefin::error::margin_amount_must_be_greater_than_zero());
        assert!(sui::table::contains<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account), bluefin::error::user_has_no_position_in_table(2));

        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let position = sui::table::borrow_mut<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account);
        assert!(bluefin::position::qPos(*position) > 0, bluefin::error::user_position_size_is_zero(2));

        // Transfer margin and update position
        bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(bank, account, sui::object::id_to_address(&perp_id), normalized_margin, 3, tx_index);
        bluefin::position::set_margin(position, bluefin::position::margin(*position) + normalized_margin);
        bluefin::position::emit_position_update_event(*position, sender, 1, tx_index);

        apply_funding_rate<CoinType>(tx_index, bank, perp, account, account, 0, 2);
    }
    
    entry fun adjust_leverage<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        sequencer: &mut bluefin::roles::Sequencer,
        price_info: &pyth_network::price_info::PriceInfoObject,
        account: address,
        new_leverage: u128,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(perp.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bank.version == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_sub_accounts_version(sub_accounts);

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);

        let sender = sui::tx_context::sender(ctx);
        assert!(sender == account || bluefin::roles::is_sub_account_v2(sub_accounts, account, sender), bluefin::error::sender_does_not_have_permission_for_account(2));
        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());

        let normalized_leverage = bluefin::library::round_down(new_leverage / bluefin::library::base_uint());
        assert!(normalized_leverage > 0, bluefin::error::leverage_can_not_be_set_to_zero());

        let oracle_price = bluefin::perpetual::priceOracle_v2(perp);
        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        assert!(sui::table::contains<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account), bluefin::error::user_has_no_position_in_table(2));

        apply_funding_rate<CoinType>(tx_index, bank, perp, account, account, 0, 2);

        let position = sui::table::borrow_mut<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account);
        let current_margin = bluefin::position::margin(*position);
        let target_margin = bluefin::margin_math::get_target_margin(*position, normalized_leverage, oracle_price);

        if (current_margin > target_margin) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(bank, sui::object::id_to_address(&perp_id), account, current_margin - target_margin, 2, tx_index);
        } else if (current_margin < target_margin) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(bank, account, sui::object::id_to_address(&perp_id), target_margin - current_margin, 3, tx_index);
        };

        bluefin::position::set_mro(position, bluefin::library::base_div(bluefin::library::base_uint(), normalized_leverage));
        bluefin::position::set_margin(position, target_margin);

        bluefin::evaluator::verify_oi_open_for_account(bluefin::perpetual::checks_v2(perp), bluefin::position::mro(*position), bluefin::position::oiOpen(*position), 0);

        let updated_position = *sui::table::borrow<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account);
        bluefin::position::verify_collat_checks(*position, updated_position, bluefin::perpetual::imr_v2(perp), bluefin::perpetual::mmr_v2(perp), oracle_price, 0, 0);
        bluefin::position::emit_position_update_event(updated_position, sender, 3, tx_index);
    }
    
    fun apply_funding_rate<CoinType>(
        tx_index: u128,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        perp: &mut bluefin::perpetual::PerpetualV2,
        sender: address,
        account: address,
        trade_type: u8,
        error_offset: u64
    ) {
        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let funding = bluefin::perpetual::fundingRate_v2(perp);
        let global_index = bluefin::funding_rate::index(funding);
        
        let position = sui::table::borrow_mut<address, bluefin::position::UserPosition>(
            bluefin::perpetual::positions(perp),
            account
        );

        let user_index = bluefin::position::index(*position);
        let current_margin = bluefin::position::margin(*position);
        let position_size = bluefin::position::qPos(*position);
        let open_interest = bluefin::position::oiOpen(*position);
        let is_position_positive = bluefin::position::isPosPositive(*position);

        bluefin::position::set_index(position, global_index);

        if (bluefin::funding_rate::are_indexes_equal(user_index, global_index) || position_size == 0) {
            return
        };

        let funding_diff = if (is_position_positive) {
            bluefin::signed_number::sub(bluefin::funding_rate::index_value(user_index), bluefin::funding_rate::index_value(global_index))
        } else {
            bluefin::signed_number::sub(bluefin::funding_rate::index_value(global_index), bluefin::funding_rate::index_value(user_index))
        };

        let funding_amount = bluefin::library::base_mul(bluefin::signed_number::value(funding_diff), position_size);
        let final_amount = funding_amount;

        if (bluefin::signed_number::gt_uint(funding_diff, 0)) {
            bluefin::position::set_margin(position, current_margin + funding_amount);
        } else {
            if (trade_type == 0 || trade_type == 1) {
                assert!(current_margin >= funding_amount, bluefin::error::funding_due_exceeds_margin(error_offset));
            } else if (trade_type == 2) {
                if (current_margin < funding_amount) {
                    let shortfall = funding_amount - current_margin;
                    bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                        bank,
                        sender,
                        sui::object::id_to_address(&perp_id),
                        shortfall,
                        1,
                        tx_index
                    );

                    let event = LiquidatorPaidForAccountSettlementEvnetV2{
                        tx_index,
                        id: perp_id,
                        liquidator: sender,
                        account,
                        amount: shortfall,
                    };
                    sui::event::emit<LiquidatorPaidForAccountSettlementEvnetV2>(event);
                    final_amount = funding_amount - shortfall;
                }
            } else {
                if (current_margin < funding_amount) {
                    if (is_position_positive) {
                        bluefin::position::set_oiOpen(position, open_interest + funding_amount);
                    } else {
                        if (funding_amount > open_interest) {
                            bluefin::position::set_oiOpen(position, 0);
                            let event = SettlementAmountNotPaidCompletelyEventV2{
                                tx_index,
                                account,
                                amount: funding_amount - open_interest,
                            };
                            sui::event::emit<SettlementAmountNotPaidCompletelyEventV2>(event);
                        } else {
                            bluefin::position::set_oiOpen(position, open_interest - funding_amount);
                        }
                    }
                    let event = SettlementAmtDueByMakerEventV2{
                        tx_index,
                        account,
                        amount: funding_amount,
                    };
                    sui::event::emit<SettlementAmtDueByMakerEventV2>(event);
                    final_amount = 0;
                }
            }
            bluefin::position::set_margin(position, current_margin - final_amount);
        }

        let event = AccountSettlementUpdateEventV2{
            tx_index,
            account,
            balance: *position,
            settlementIsPositive: bluefin::signed_number::sign(funding_diff),
            settlementAmount: final_amount,
            price: bluefin::perpetual::priceOracle_v2(perp),
            fundingRate: bluefin::funding_rate::rate(funding),
        };
        sui::event::emit<AccountSettlementUpdateEventV2>(event);
    }
    
    entry fun close_position<CoinType>(
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sequencer: &mut bluefin::roles::Sequencer,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        assert!(bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_not_delisted());

        let sender = sui::tx_context::sender(ctx);
        assert!(sui::table::contains<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), sender), bluefin::error::user_has_no_position_in_table(2));

        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let perp_address = sui::object::id_to_address(&perp_id);

        apply_funding_rate<CoinType>(tx_index, bank, perp, sender, sender, 0, 2);

        let position = sui::table::borrow_mut<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), sender);
        assert!(bluefin::position::qPos(*position) > 0, bluefin::error::user_position_size_is_zero(2));

        let margin_left = bluefin::margin_math::get_margin_left(*position, bluefin::perpetual::delistingPrice_v2(perp), bluefin::margin_bank::get_balance_v2<CoinType>(bank, perp_address));
        bluefin::position::set_qPos(position, 0);
        bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(bank, perp_address, sender, margin_left, 2, tx_index);

        bluefin::position::emit_position_closed_event(perp_id, sender, margin_left, tx_index);
        bluefin::position::emit_position_update_event(*position, sender, 4, tx_index);
    }
    
    entry fun create_perpetual<CoinType>(
        admin_cap: &bluefin::roles::ExchangeAdminCap,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        perp_name: vector<u8>,
        min_price: u128,
        max_price: u128,
        tick_size: u128,
        min_qty: u128,
        max_qty_limit: u128,
        max_qty_market: u128,
        step_size: u128,
        mtb_long: u128,
        mtb_short: u128,
        max_oi_open: vector<u128>,
        imr: u128,
        mmr: u128,
        maker_fee: u128,
        taker_fee: u128,
        funding_period: u128,
        insurance_ratio: u128,
        insurance_addr: address,
        fee_addr: address,
        start_time: u64,
        price_feed_id: vector<u8>,
        ctx: &mut sui::tx_context::TxContext
    ) {
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        
        let perp_id = bluefin::perpetual::initialize(
            perp_name,
            imr / bluefin::library::base_uint(),
            mmr / bluefin::library::base_uint(),
            maker_fee / bluefin::library::base_uint(),
            taker_fee / bluefin::library::base_uint(),
            insurance_ratio / bluefin::library::base_uint(),
            insurance_addr,
            fee_addr,
            min_price / bluefin::library::base_uint(),
            max_price / bluefin::library::base_uint(),
            tick_size / bluefin::library::base_uint(),
            min_qty / bluefin::library::base_uint(),
            max_qty_limit / bluefin::library::base_uint(),
            max_qty_market / bluefin::library::base_uint(),
            step_size / bluefin::library::base_uint(),
            mtb_long / bluefin::library::base_uint(),
            mtb_short / bluefin::library::base_uint(),
            funding_period / bluefin::library::base_uint(),
            start_time,
            bluefin::library::to_1x9_vec(max_oi_open),
            price_feed_id,
            ctx
        );

        // Initialize accounts in margin bank
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), sui::object::id_to_address(&perp_id));
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), insurance_addr);
        bluefin::margin_bank::initialize_account(bluefin::margin_bank::mut_accounts_v2<CoinType>(bank), fee_addr);
    }
    
    entry fun deleverage<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        capabilities_safe: &bluefin::roles::CapabilitiesSafeV2,
        sequencer: &mut bluefin::roles::Sequencer,
        deleveraging_cap: &bluefin::roles::DeleveragingCap,
        price_info: &pyth_network::price_info::PriceInfoObject,
        maker_account: address,
        taker_account: address,
        quantity: u128,
        is_buy: bool,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_safe_version(capabilities_safe);

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);

        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());
        assert!(bluefin::perpetual::is_trading_permitted_v2(perp), bluefin::error::trading_is_stopped_on_perpetual());
        assert!(sui::clock::timestamp_ms(clock) > bluefin::perpetual::startTime_v2(perp), bluefin::error::trading_not_started());
        bluefin::roles::check_delevearging_operator_validity_v2(capabilities_safe, deleveraging_cap);

        let sender = sui::tx_context::sender(ctx);
        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));

        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), maker_account);
        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), taker_account);

        apply_funding_rate<CoinType>(tx_index, bank, perp, sender, maker_account, bluefin::isolated_adl::tradeType(), 0);
        apply_funding_rate<CoinType>(tx_index, bank, perp, sender, taker_account, bluefin::isolated_adl::tradeType(), 1);

        let trade_response = bluefin::isolated_adl::trade(
            sender,
            perp,
            bluefin::isolated_adl::pack_trade_data(
                maker_account,
                taker_account,
                quantity / bluefin::library::base_uint(),
                is_buy
            ),
            tx_index
        );

        bluefin::margin_bank::transfer_trade_margin<CoinType>(
            bank,
            sui::object::id_to_address(&perp_id),
            maker_account,
            taker_account,
            bluefin::isolated_adl::makerFundsFlow(trade_response),
            bluefin::isolated_adl::takerFundsFlow(trade_response),
            tx_index
        );
    }
    
    entry fun liquidate<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        sequencer: &mut bluefin::roles::Sequencer,
        price_info: &pyth_network::price_info::PriceInfoObject,
        liquidated_account: address,
        liquidator: address,
        quantity: u128,
        price: u128,
        is_buy: bool,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_sub_accounts_version(sub_accounts);

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);

        // Trading checks
        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());
        assert!(bluefin::perpetual::is_trading_permitted_v2(perp), bluefin::error::trading_is_stopped_on_perpetual());
        assert!(sui::clock::timestamp_ms(clock) > bluefin::perpetual::startTime_v2(perp), bluefin::error::trading_not_started());

        let sender = sui::tx_context::sender(ctx);
        assert!(sender == liquidator || bluefin::roles::is_sub_account_v2(sub_accounts, liquidator, sender), bluefin::error::sender_does_not_have_permission_for_account(1));
        assert!(liquidator != liquidated_account, bluefin::error::self_liquidation_not_allowed());

        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let perp_address = sui::object::id_to_address(&perp_id);

        // Initialize positions
        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), liquidated_account);
        bluefin::position::create_position(perp_id, bluefin::perpetual::positions(perp), liquidator);

        // Apply funding rates
        apply_funding_rate<CoinType>(tx_index, bank, perp, liquidator, liquidated_account, bluefin::isolated_liquidation::tradeType(), 0);
        apply_funding_rate<CoinType>(tx_index, bank, perp, liquidator, liquidator, bluefin::isolated_liquidation::tradeType(), 1);

        // Execute liquidation
        let liquidation_response = bluefin::isolated_liquidation::trade(
            sender,
            perp,
            bluefin::isolated_liquidation::pack_trade_data(
                liquidator,
                liquidated_account,
                quantity / bluefin::library::base_uint(),
                price / bluefin::library::base_uint(),
                is_buy
            ),
            tx_index
        );

        // Handle liquidator and insurance pool portions
        let liquidator_portion = bluefin::isolated_liquidation::liquidatorPortion(liquidation_response);
        let insurance_portion = bluefin::isolated_liquidation::insurancePoolPortion(liquidation_response);

        if (bluefin::signed_number::gt_uint(liquidator_portion, 0)) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                bank,
                perp_address,
                liquidator,
                bluefin::signed_number::value(liquidator_portion),
                2,
                tx_index
            );
        } else if (bluefin::signed_number::lt_uint(liquidator_portion, 0)) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                bank,
                liquidator,
                perp_address,
                bluefin::signed_number::value(liquidator_portion),
                1,
                tx_index
            );
        };

        if (bluefin::signed_number::gt_uint(insurance_portion, 0)) {
            bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(
                bank,
                perp_address,
                bluefin::perpetual::insurancePool_v2(perp),
                bluefin::signed_number::value(insurance_portion),
                2,
                tx_index
            );
        };

        // Transfer margins
        bluefin::margin_bank::transfer_trade_margin<CoinType>(
            bank,
            perp_address,
            liquidated_account,
            liquidator,
            bluefin::isolated_liquidation::makerFundsFlow(liquidation_response),
            bluefin::isolated_liquidation::takerFundsFlow(liquidation_response),
            tx_index
        );
    }
    
    entry fun remove_margin<CoinType>(
        clock: &sui::clock::Clock,
        perp: &mut bluefin::perpetual::PerpetualV2,
        bank: &mut bluefin::margin_bank::BankV2<CoinType>,
        sub_accounts: &bluefin::roles::SubAccountsV2,
        sequencer: &mut bluefin::roles::Sequencer,
        price_info: &pyth_network::price_info::PriceInfoObject,
        account: address,
        margin_amount: u128,
        tx_data: vector<u8>,
        ctx: &sui::tx_context::TxContext
    ) {
        assert!(bluefin::perpetual::get_version(perp) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        assert!(bluefin::margin_bank::get_version<CoinType>(bank) == bluefin::roles::get_version(), bluefin::error::object_version_mismatch());
        bluefin::roles::validate_sub_accounts_version(sub_accounts);

        let tx_index = bluefin::roles::validate_unique_tx_v2(sequencer, tx_data);
        let normalized_margin = margin_amount / bluefin::library::base_uint();
        bluefin::perpetual::update_oracle_price(perp, price_info, clock);

        let sender = sui::tx_context::sender(ctx);
        assert!(sender == account || bluefin::roles::is_sub_account_v2(sub_accounts, account, sender), bluefin::error::sender_does_not_have_permission_for_account(2));
        assert!(!bluefin::perpetual::delisted_v2(perp), bluefin::error::perpetual_is_delisted());
        assert!(normalized_margin > 0, bluefin::error::margin_amount_must_be_greater_than_zero());

        let oracle_price = bluefin::perpetual::priceOracle_v2(perp);
        assert!(sui::table::contains<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account), bluefin::error::user_has_no_position_in_table(2));

        let perp_id = sui::object::uid_to_inner(bluefin::perpetual::id_v2(perp));
        let position = sui::table::borrow_mut<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account);
        
        assert!(bluefin::position::qPos(*position) > 0, bluefin::error::user_position_size_is_zero(2));
        assert!(normalized_margin <= bluefin::margin_math::get_max_removeable_margin(*position, oracle_price), bluefin::error::margin_must_be_less_than_max_removable_margin());

        bluefin::margin_bank::transfer_margin_to_account_v2<CoinType>(bank, sui::object::id_to_address(&perp_id), account, normalized_margin, 2, tx_index);
        bluefin::position::set_margin(position, bluefin::position::margin(*position) - normalized_margin);
        
        apply_funding_rate<CoinType>(tx_index, bank, perp, account, account, 0, 2);
        
        let updated_position = *sui::table::borrow<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account);
        bluefin::position::verify_collat_checks(
            *sui::table::borrow<address, bluefin::position::UserPosition>(bluefin::perpetual::positions(perp), account),
            updated_position,
            bluefin::perpetual::imr_v2(perp),
            bluefin::perpetual::mmr_v2(perp),
            oracle_price,
            0,
            0
        );
        bluefin::position::emit_position_update_event(updated_position, sender, 2, tx_index);
    }
}

