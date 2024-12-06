module 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::position {
    struct AccountPositionUpdateEvent has copy, drop {
        position: UserPosition,
        sender: address,
        action: u8,
    }
    
    struct PositionClosedEvent has copy, drop {
        perpID: 0x2::object::ID,
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
        perpID: 0x2::object::ID,
        account: address,
        amount: u128,
    }
    
    struct UserPosition has copy, drop, store {
        user: address,
        perpID: 0x2::object::ID,
        isPosPositive: bool,
        qPos: u128,
        margin: u128,
        oiOpen: u128,
        mro: u128,
        index: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::funding_rate::FundingIndex,
    }
    
    public fun compute_average_entry_price(arg0: UserPosition) : u128 {
        if (arg0.qPos == 0) {
            0
        } else {
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_div(arg0.oiOpen, arg0.qPos)
        }
    }
    
    public fun compute_margin_ratio(arg0: UserPosition, arg1: u128) : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number {
        let v0 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::one();
        let v1 = v0;
        if (arg0.qPos == 0) {
            return v0
        };
        let v2 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_mul(arg1, arg0.qPos);
        if (arg0.isPosPositive) {
            if (v2 > 0) {
                v1 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::sub(v0, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::div_uint(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::from_subtraction(arg0.oiOpen, arg0.margin), v2));
            };
        } else {
            if (v2 > 0) {
                v1 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::from_subtraction(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_div(arg0.oiOpen + arg0.margin, v2), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::base_uint());
            };
        };
        v1
    }
    
    public fun compute_pnl_per_unit(arg0: UserPosition, arg1: u128) : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::Number {
        if (arg0.isPosPositive) {
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::from_subtraction(arg1, compute_average_entry_price(arg0))
        } else {
            0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::from_subtraction(compute_average_entry_price(arg0), arg1)
        }
    }
    
    public(friend) fun create_position(arg0: 0x2::object::ID, arg1: &mut 0x2::table::Table<address, UserPosition>, arg2: address) {
        if (!0x2::table::contains<address, UserPosition>(arg1, arg2)) {
            0x2::table::add<address, UserPosition>(arg1, arg2, initialize(arg0, arg2));
        };
    }
    
    public(friend) fun emit_position_closed_event(arg0: 0x2::object::ID, arg1: address, arg2: u128, arg3: u128) {
        let v0 = PositionClosedEventV2{
            tx_index : arg3, 
            perpID   : arg0, 
            account  : arg1, 
            amount   : arg2,
        };
        0x2::event::emit<PositionClosedEventV2>(v0);
    }
    
    public(friend) fun emit_position_update_event(arg0: UserPosition, arg1: address, arg2: u8, arg3: u128) {
        let v0 = AccountPositionUpdateEventV2{
            tx_index : arg3, 
            position : arg0, 
            sender   : arg1, 
            action   : arg2,
        };
        0x2::event::emit<AccountPositionUpdateEventV2>(v0);
    }
    
    public fun index(arg0: UserPosition) : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::funding_rate::FundingIndex {
        arg0.index
    }
    
    public(friend) fun initialize(arg0: 0x2::object::ID, arg1: address) : UserPosition {
        UserPosition{
            user          : arg1, 
            perpID        : arg0, 
            isPosPositive : false, 
            qPos          : 0, 
            margin        : 0, 
            oiOpen        : 0, 
            mro           : 0, 
            index         : 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::funding_rate::initialize_index(0),
        }
    }
    
    public fun isPosPositive(arg0: UserPosition) : bool {
        arg0.isPosPositive
    }
    
    public fun is_undercollat(arg0: UserPosition, arg1: u128, arg2: u128) : bool {
        0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::lt_uint(compute_margin_ratio(arg0, arg1), arg2)
    }
    
    public fun margin(arg0: UserPosition) : u128 {
        arg0.margin
    }
    
    public fun mro(arg0: UserPosition) : u128 {
        arg0.mro
    }
    
    public fun oiOpen(arg0: UserPosition) : u128 {
        arg0.oiOpen
    }
    
    public fun qPos(arg0: UserPosition) : u128 {
        arg0.qPos
    }
    
    public(friend) fun remove_empty_positions(arg0: &mut 0x2::table::Table<address, UserPosition>, arg1: vector<address>, arg2: u64) {
        let v0 = 0;
        while (v0 < 0x1::vector::length<address>(&arg1)) {
            let v1 = *0x1::vector::borrow<address>(&arg1, v0);
            v0 = v0 + 1;
            if (0x2::table::contains<address, UserPosition>(arg0, v1)) {
                let v2 = 0x2::table::borrow<address, UserPosition>(arg0, v1);
                if (v2.qPos == 0 && arg2 - 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::funding_rate::index_timestamp(v2.index) > 604800000) {
                    0x2::table::remove<address, UserPosition>(arg0, v1);
                    continue
                };
                continue
            };
        };
    }
    
    public(friend) fun set_index(arg0: &mut UserPosition, arg1: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::funding_rate::FundingIndex) {
        arg0.index = arg1;
    }
    
    public(friend) fun set_isPosPositive(arg0: &mut UserPosition, arg1: bool) {
        arg0.isPosPositive = arg1;
    }
    
    public(friend) fun set_margin(arg0: &mut UserPosition, arg1: u128) {
        arg0.margin = arg1;
    }
    
    public(friend) fun set_mro(arg0: &mut UserPosition, arg1: u128) {
        if (arg0.qPos == 0) {
            arg0.mro = 0;
        } else {
            arg0.mro = arg1;
        };
    }
    
    public(friend) fun set_oiOpen(arg0: &mut UserPosition, arg1: u128) {
        arg0.oiOpen = arg1;
    }
    
    public(friend) fun set_qPos(arg0: &mut UserPosition, arg1: u128) {
        arg0.qPos = arg1;
        if (arg1 == 0) {
            set_isPosPositive(arg0, false);
            set_mro(arg0, 0);
        };
    }
    
    public fun user(arg0: UserPosition) : address {
        arg0.user
    }
    
    public fun verify_collat_checks(arg0: UserPosition, arg1: UserPosition, arg2: u128, arg3: u128, arg4: u128, arg5: u8, arg6: u64) {
        let v0 = compute_margin_ratio(arg1, arg4);
        if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gte_uint(v0, arg2)) {
            return
        };
        assert!(arg1.isPosPositive == arg0.isPosPositive && arg0.qPos > 0, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::mr_less_than_imr_can_not_open_or_flip_position(arg6));
        assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gte(v0, compute_margin_ratio(arg0, arg4)), 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::mr_less_than_imr_mr_must_improve(arg6));
        let v1 = if (0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gt_uint(v0, arg3)) {
            true
        } else {
            let v2 = arg0.qPos >= arg1.qPos && arg0.isPosPositive == arg1.isPosPositive;
            v2
        };
        assert!(v1, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::mr_less_than_imr_position_can_only_reduce(arg6));
        assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::signed_number::gte_uint(v0, 0) || arg5 == 2 || arg5 == 3, 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::error::mr_less_than_zero(arg6));
    }
    
    // decompiled from Move bytecode v6
}

