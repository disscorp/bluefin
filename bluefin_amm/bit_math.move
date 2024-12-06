module bluefin::bit_math {
    public fun least_significant_bit(number: u256) : u8 {
        assert!(number > 0, 0);
        let max_bit = 255;
        let result = max_bit;
        
        if (number & (bluefin::constants::max_u128() as u256) > 0) {
            result = max_bit - 128;
        } else {
            number = number >> 128;
        };

        if (number & (bluefin::constants::max_u64() as u256) > 0) {
            result = result - 64;
        } else {
            number = number >> 64;
        };

        if (number & (bluefin::constants::max_u32() as u256) > 0) {
            result = result - 32;
        } else {
            number = number >> 32;
        };

        if (number & (bluefin::constants::max_u16() as u256) > 0) {
            result = result - 16;
        } else {
            number = number >> 16;
        };

        if (number & (bluefin::constants::max_u8() as u256) > 0) {
            result = result - 8;
        } else {
            number = number >> 8;
        };

        if (number & 15 > 0) {
            result = result - 4;
        } else {
            number = number >> 4;
        };

        if (number & 3 > 0) {
            result = result - 2;
        } else {
            number = number >> 2;
        };

        if (number & 1 > 0) {
            result = result - 1;
        };
        result
    }
    
    public fun most_significant_bit(number: u256) : u8 {
        assert!(number > 0, 0);
        let base = 0;
        let result = base;
        
        if (number >= 340282366920938463463374607431768211456) {
            number = number >> 128;
            result = base + 128;
        };

        if (number >= 18446744073709551616) {
            number = number >> 64;
            result = result + 64;
        };

        if (number >= 4294967296) {
            number = number >> 32;
            result = result + 32;
        };

        if (number >= 65536) {
            number = number >> 16;
            result = result + 16;
        };

        if (number >= 256) {
            number = number >> 8;
            result = result + 8;
        };

        if (number >= 16) {
            number = number >> 4;
            result = result + 4;
        };

        if (number >= 4) {
            number = number >> 2;
            result = result + 2;
        };

        if (number >= 2) {
            result = result + 1;
        };
        result
    }
}