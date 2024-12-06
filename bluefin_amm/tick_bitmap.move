module bluefin::tick_bitmap {
    public fun cast_to_u8(tick_index: math_library::i32::I32) : u8 {
        assert!(math_library::i32::abs_u32(tick_index) < 256, 0);
        (math_library::i32::abs_u32(math_library::i32::add(tick_index, math_library::i32::from(256))) & 255) as u8
    }
    
    public(friend) fun flip_tick(
        bitmap: &mut 0x2::table::Table<math_library::i32::I32, u256>,
        tick: math_library::i32::I32,
        tick_spacing: u32
    ) {
        assert!(math_library::i32::abs_u32(tick) % tick_spacing == 0, 0);
        let (word_pos, bit_pos) = position(math_library::i32::div(tick, math_library::i32::from(tick_spacing)));
        let word = get_mutable_tick_word(bitmap, word_pos);
        *word = *word ^ 1 << bit_pos;
    }
    
    fun get_immutable_tick_word(
        bitmap: &0x2::table::Table<math_library::i32::I32, u256>,
        word_pos: math_library::i32::I32
    ) : u256 {
        if (!0x2::table::contains<math_library::i32::I32, u256>(bitmap, word_pos)) {
            0
        } else {
            *0x2::table::borrow<math_library::i32::I32, u256>(bitmap, word_pos)
        }
    }
    
    fun get_mutable_tick_word(
        bitmap: &mut 0x2::table::Table<math_library::i32::I32, u256>,
        word_pos: math_library::i32::I32
    ) : &mut u256 {
        if (!0x2::table::contains<math_library::i32::I32, u256>(bitmap, word_pos)) {
            0x2::table::add<math_library::i32::I32, u256>(bitmap, word_pos, 0);
        };
        0x2::table::borrow_mut<math_library::i32::I32, u256>(bitmap, word_pos)
    }
    
    public fun next_initialized_tick_within_one_word(
        bitmap: &0x2::table::Table<math_library::i32::I32, u256>,
        tick: math_library::i32::I32,
        tick_spacing: u32,
        lte: bool
    ) : (math_library::i32::I32, bool) {
        let spacing = math_library::i32::from(tick_spacing);
        let compressed = math_library::i32::div(tick, spacing);
        let word_pos = compressed;

        if (math_library::i32::is_neg(tick) && math_library::i32::abs_u32(tick) % tick_spacing != 0) {
            word_pos = math_library::i32::sub(compressed, math_library::i32::from(1));
        };

        if (lte) {
            let (pos, bit) = position(word_pos);
            let mask = get_immutable_tick_word(bitmap, pos) & (1 << bit) - 1 + (1 << bit);
            let next_tick = if (mask != 0) {
                math_library::i32::mul(
                    math_library::i32::sub(
                        word_pos,
                        math_library::i32::sub(
                            math_library::i32::from(bit as u32),
                            math_library::i32::from(bluefin::bit_math::most_significant_bit(mask) as u32)
                        )
                    ),
                    spacing
                )
            } else {
                math_library::i32::mul(
                    math_library::i32::sub(word_pos, math_library::i32::from(bit as u32)),
                    spacing
                )
            };
            (next_tick, mask != 0)
        } else {
            let (pos, bit) = position(math_library::i32::add(word_pos, math_library::i32::from(1)));
            let mask = get_immutable_tick_word(bitmap, pos) & ((1 << bit) - 1 ^ bluefin::constants::max_u256());
            let next_tick = if (mask != 0) {
                math_library::i32::mul(
                    math_library::i32::add(
                        math_library::i32::add(word_pos, math_library::i32::from(1)),
                        math_library::i32::from((bluefin::bit_math::least_significant_bit(mask) as u32) - (bit as u32))
                    ),
                    spacing
                )
            } else {
                math_library::i32::mul(
                    math_library::i32::add(
                        math_library::i32::add(word_pos, math_library::i32::from(1)),
                        math_library::i32::from((bluefin::constants::max_u8() as u32) - (bit as u32))
                    ),
                    spacing
                )
            };
            (next_tick, mask != 0)
        }
    }
    
    fun position(tick: math_library::i32::I32) : (math_library::i32::I32, u8) {
        (
            math_library::i32::shr(tick, 8),
            cast_to_u8(math_library::i32::mod(tick, math_library::i32::from(256)))
        )
    }
}