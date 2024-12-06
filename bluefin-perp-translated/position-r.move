module bluefin::position {
    struct AccountPositionUpdateEvent has copy, drop {
        position: UserPosition,
        sender: address,
        action: u8,
    }
    
    struct PositionClosedEvent has copy, drop {
        perpID: sui::object::ID,
        account: address,
        amount: u128,
    }
    
    struct AccountPositionUpdateEventV2 has copy, drop {
        tx_index: u128,
        position: UserPosition,
        sender: address,
        action: u8,
    }
    
    struct PositionClosedEventV2 has copy, drop {
        tx_index: u128,
        perpID: sui::object::ID,
        account: address,
        amount: u128,
    }
    
    struct UserPosition has copy, drop, store {
        user: address,
        perpID: sui::object::ID,
        isPosPositive: bool,
        qPos: u128,
        margin: u128,
        oiOpen: u128,
        mro: u128,
        index: bluefin::funding_rate::FundingIndex,
    }
    
    public fun compute_average_entry_price(position: UserPosition) : u128 {
        if (position.qPos == 0) {
            0
        } else {
            bluefin::library::base_div(position.oiOpen, position.qPos)
        }
    }
    
    public fun compute_margin_ratio(position: UserPosition, price: u128) : bluefin::signed_number::Number {
        let one = bluefin::signed_number::one();
        let margin_ratio = one;
        if (position.qPos == 0) {
            return one
        };
        let position_value = bluefin::library::base_mul(price, position.qPos);
        if (position.isPosPositive) {
            if (position_value > 0) {
                margin_ratio = bluefin::signed_number::sub(
                    one, 
                    bluefin::signed_number::div_uint(
                        bluefin::signed_number::from_subtraction(position.oiOpen, position.margin), 
                        position_value
                    )
                );
            };
        } else {
            if (position_value > 0) {
                margin_ratio = bluefin::signed_number::from_subtraction(
                    bluefin::library::base_div(position.oiOpen + position.margin, position_value),
                    bluefin::library::base_uint()
                );
            };
        };
        margin_ratio
    }
    
    public fun compute_pnl_per_unit(position: UserPosition, current_price: u128) : bluefin::signed_number::Number {
        if (position.isPosPositive) {
            bluefin::signed_number::from_subtraction(current_price, compute_average_entry_price(position))
        } else {
            bluefin::signed_number::from_subtraction(compute_average_entry_price(position), current_price)
        }
    }
    
    public(friend) fun create_position(perp_id: sui::object::ID, positions_table: &mut sui::table::Table<address, UserPosition>, user_addr: address) {
        if (!sui::table::contains<address, UserPosition>(positions_table, user_addr)) {
            sui::table::add<address, UserPosition>(positions_table, user_addr, initialize(perp_id, user_addr));
        };
    }
    
    public(friend) fun emit_position_closed_event(perp_id: sui::object::ID, user_addr: address, position_size: u128, tx_index: u128) {
        let event = PositionClosedEventV2{
            tx_index,
            perpID: perp_id,
            account: user_addr,
            amount: position_size,
        };
        sui::event::emit<PositionClosedEventV2>(event);
    }
    
    public(friend) fun emit_position_update_event(position: UserPosition, sender_addr: address, action_type: u8, tx_index: u128) {
        let event = AccountPositionUpdateEventV2{
            tx_index,
            position,
            sender: sender_addr,
            action: action_type,
        };
        sui::event::emit<AccountPositionUpdateEventV2>(event);
    }
    
    public fun index(position: UserPosition) : bluefin::funding_rate::FundingIndex {
        position.index
    }

    public(friend) fun initialize(perp_id: sui::object::ID, user_addr: address) : UserPosition {
        UserPosition{
            user          : user_addr,
            perpID        : perp_id,
            isPosPositive : false,
            qPos          : 0,
            margin        : 0,
            oiOpen        : 0,
            mro           : 0,
            index         : bluefin::funding_rate::initialize_index(0),
        }
    }

    public fun isPosPositive(position: UserPosition) : bool {
        position.isPosPositive
    }

    public fun is_undercollat(position: UserPosition, price: u128, maintenance_margin_ratio: u128) : bool {
        bluefin::signed_number::lt_uint(compute_margin_ratio(position, price), maintenance_margin_ratio)
    }

    public fun margin(position: UserPosition) : u128 {
        position.margin
    }

    public fun mro(position: UserPosition) : u128 {
        position.mro
    }

    public fun oiOpen(position: UserPosition) : u128 {
        position.oiOpen
    }

    public fun qPos(position: UserPosition) : u128 {
        position.qPos
    }
    
    public(friend) fun remove_empty_positions(positions_table: &mut sui::table::Table<address, UserPosition>, addresses: vector<address>, current_timestamp: u64) {
        let i = 0;
        while (i < std::vector::length<address>(&addresses)) {
            let addr = *std::vector::borrow<address>(&addresses, i);
            i = i + 1;
            if (sui::table::contains<address, UserPosition>(positions_table, addr)) {
                let position = sui::table::borrow<address, UserPosition>(positions_table, addr);
                if (position.qPos == 0 && current_timestamp - bluefin::funding_rate::index_timestamp(position.index) > 604800000) {
                    sui::table::remove<address, UserPosition>(positions_table, addr);
                    continue
                };
                continue
            };
        };
    }
    
    public(friend) fun set_index(position: &mut UserPosition, new_index: bluefin::funding_rate::FundingIndex) {
        position.index = new_index;
    }

    public(friend) fun set_isPosPositive(position: &mut UserPosition, is_positive: bool) {
        position.isPosPositive = is_positive;
    }

    public(friend) fun set_margin(position: &mut UserPosition, margin_amount: u128) {
        position.margin = margin_amount;
    }

    public(friend) fun set_mro(position: &mut UserPosition, maintenance_margin_ratio: u128) {
        if (position.qPos == 0) {
            position.mro = 0;
        } else {
            position.mro = maintenance_margin_ratio;
        };
    }

    public(friend) fun set_oiOpen(position: &mut UserPosition, open_interest: u128) {
        position.oiOpen = open_interest;
    }

    public(friend) fun set_qPos(position: &mut UserPosition, position_size: u128) {
        position.qPos = position_size;
        if (position_size == 0) {
            set_isPosPositive(position, false);
            set_mro(position, 0);
        };
    }

    public fun user(position: UserPosition) : address {
        position.user
    }
    
    public fun verify_collat_checks(
        old_position: UserPosition, 
        new_position: UserPosition, 
        initial_margin_ratio: u128, 
        maintenance_margin_ratio: u128, 
        mark_price: u128, 
        action_type: u8, 
        error_code: u64
    ) {
        let new_margin_ratio = compute_margin_ratio(new_position, mark_price);
        if (bluefin::signed_number::gte_uint(new_margin_ratio, initial_margin_ratio)) {
            return
        };
        assert!(
            new_position.isPosPositive == old_position.isPosPositive && old_position.qPos > 0, 
            bluefin::error::mr_less_than_imr_can_not_open_or_flip_position(error_code)
        );
        assert!(
            bluefin::signed_number::gte(new_margin_ratio, compute_margin_ratio(old_position, mark_price)),
            bluefin::error::mr_less_than_imr_mr_must_improve(error_code)
        );
        let is_valid = if (bluefin::signed_number::gt_uint(new_margin_ratio, maintenance_margin_ratio)) {
            true
        } else {
            let is_position_reduced = old_position.qPos >= new_position.qPos && 
                                    old_position.isPosPositive == new_position.isPosPositive;
            is_position_reduced
        };
        assert!(is_valid, bluefin::error::mr_less_than_imr_position_can_only_reduce(error_code));
        assert!(
            bluefin::signed_number::gte_uint(new_margin_ratio, 0) || action_type == 2 || action_type == 3,
            bluefin::error::mr_less_than_zero(error_code)
        );
    }
}