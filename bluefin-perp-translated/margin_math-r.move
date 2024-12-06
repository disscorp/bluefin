module bluefin::margin_math {
    public(friend) fun get_margin_left(position: bluefin::position::UserPosition, current_price: u128, max_margin: u128) : u128 {
        let open_interest = bluefin::position::oiOpen(position);
        let margin_left = if (bluefin::position::isPosPositive(position)) {
            bluefin::library::sub(
                bluefin::position::margin(position) + open_interest * current_price / bluefin::position::compute_average_entry_price(position),
                open_interest
            )
        } else {
            bluefin::library::sub(
                bluefin::position::margin(position) + open_interest,
                open_interest * current_price / bluefin::position::compute_average_entry_price(position)
            )
        };
        bluefin::library::min(margin_left, max_margin)
    }
    
    public(friend) fun get_max_removeable_margin(position: bluefin::position::UserPosition, current_price: u128) : u128 {
        let current_margin = bluefin::position::margin(position);
        if (bluefin::position::isPosPositive(position)) {
            bluefin::library::min(
                current_margin,
                bluefin::signed_number::positive_value(
                    bluefin::signed_number::add_uint(
                        bluefin::signed_number::from_subtraction(current_margin, bluefin::position::oiOpen(position)),
                        bluefin::library::base_mul(
                            bluefin::library::base_mul(bluefin::position::qPos(position), current_price),
                            bluefin::library::base_uint() - bluefin::position::mro(position)
                        )
                    )
                )
            )
        } else {
            bluefin::library::min(
                current_margin,
                bluefin::library::sub(
                    current_margin + bluefin::position::oiOpen(position),
                    bluefin::library::base_mul(
                        bluefin::library::base_mul(bluefin::position::qPos(position), current_price),
                        bluefin::library::base_uint() + bluefin::position::mro(position)
                    )
                )
            )
        }
    }
    
    public(friend) fun get_target_margin(position: bluefin::position::UserPosition, leverage: u128, current_price: u128) : u128 {
        let position_value = bluefin::library::base_mul(bluefin::position::qPos(position), current_price);
        if (bluefin::position::isPosPositive(position)) {
            bluefin::library::sub(
                bluefin::library::base_div(position_value, leverage) + bluefin::position::oiOpen(position),
                position_value
            )
        } else {
            bluefin::library::sub(
                bluefin::library::base_div(position_value, leverage) + position_value,
                bluefin::position::oiOpen(position)
            )
        }
    }
}
