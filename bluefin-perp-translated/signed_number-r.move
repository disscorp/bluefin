module bluefin::signed_number {
    struct Number has copy, drop, store {
        value: u128,
        sign: bool,  // true for positive, false for negative
    }

    public fun add(num1: Number, num2: Number) : Number {
        let (result_sign, result_value) = if (num1.sign == num2.sign) {
            (num1.sign, num1.value + num2.value)
        } else {
            if (num1.value >= num2.value) {
                (num1.sign, num1.value - num2.value)
            } else {
                (num2.sign, num2.value - num1.value)
            }
        };
        Number{ value: result_value, sign: result_sign }
    }

    public fun add_uint(num: Number, uint_value: u128) : Number {
        let base_value = num.value;
        let current_sign = num.sign;
        let result_sign = current_sign;
        let result_value = if (current_sign == true) {
            base_value + uint_value
        } else {
            if (base_value > uint_value) {
                base_value - uint_value
            } else {
                result_sign = true;
                uint_value - base_value
            }
        };
        Number{ value: result_value, sign: result_sign }
    }

    public fun div_uint(num: Number, divisor: u128) : Number {
        Number{ 
            value: bluefin::library::base_div(num.value, divisor), 
            sign: num.sign 
        }
    }

    public fun from(value: u128, sign: bool) : Number {
        Number{ value, sign }
    }

    public fun from_subtraction(value1: u128, value2: u128) : Number {
        if (value1 > value2) {
            Number{ value: value1 - value2, sign: true }
        } else {
            Number{ value: value2 - value1, sign: false }
        }
    }

    public fun gt(num1: Number, num2: Number) : bool {
        if (num1.sign && num2.sign) {
            return num1.value > num2.value
        };
        if (!num1.sign && !num2.sign) {
            return num1.value < num2.value
        };
        num1.sign
    }

    public fun gt_uint(num: Number, uint_value: u128) : bool {
        !num.sign && false || num.value > uint_value
    }

    public fun gte(num1: Number, num2: Number) : bool {
        if (num1.sign && num2.sign) {
            return num1.value >= num2.value
        };
        if (!num1.sign && !num2.sign) {
            return num1.value <= num2.value
        };
        num1.sign
    }

    public fun gte_uint(num: Number, uint_value: u128) : bool {
        !num.sign && false || num.value >= uint_value
    }

    public fun lt_uint(num: Number, uint_value: u128) : bool {
        !num.sign || num.value < uint_value
    }

    public fun lte_uint(num: Number, uint_value: u128) : bool {
        !num.sign || num.value <= uint_value
    }

    public fun mul_uint(num: Number, multiplier: u128) : Number {
        Number{ 
            value: bluefin::library::base_mul(num.value, multiplier), 
            sign: num.sign 
        }
    }

    public fun negate(num: Number) : Number {
        Number{ value: num.value, sign: !num.sign }
    }

    public fun negative_number(num: Number) : Number {
        if (!num.sign) { num } else { Number{ value: 0, sign: true } }
    }

    public fun new() : Number {
        Number{ value: 0, sign: true }
    }

    public fun one() : Number {
        Number{ 
            value: bluefin::library::base_uint(), 
            sign: true 
        }
    }

    public fun positive_number(num: Number) : Number {
        if (!num.sign) { 
            Number{ value: 0, sign: true }
        } else { 
            num 
        }
    }

    public fun positive_value(num: Number) : u128 {
        if (!num.sign) { 0 } else { num.value }
    }

    public fun sign(num: Number) : bool {
        num.sign
    }

    public fun sub(num1: Number, num2: Number) : Number {
        num2.sign = !num2.sign;
        let (result_sign, result_value) = if (num1.sign == num2.sign) {
            (num1.sign, num1.value + num2.value)
        } else {
            if (num1.value >= num2.value) {
                (num1.sign, num1.value - num2.value)
            } else {
                (num2.sign, num2.value - num1.value)
            }
        };
        Number{ value: result_value, sign: result_sign }
    }

    public fun sub_uint(num: Number, uint_value: u128) : Number {
        let base_value = num.value;
        let current_sign = num.sign;
        let result_sign = current_sign;
        let result_value = if (current_sign == false) {
            base_value + uint_value
        } else {
            if (base_value > uint_value) {
                base_value - uint_value
            } else {
                result_sign = false;
                uint_value - base_value
            }
        };
        Number{ value: result_value, sign: result_sign }
    }

    public fun value(num: Number) : u128 {
        num.value
    }
}