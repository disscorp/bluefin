module bluefin::library {
    struct VerificationResult has copy, drop {
        is_verified: bool,
        public_key: vector<u8>,
    }
    
    public entry fun get_price_identifier(price_info_object: &pyth_network::price_info::PriceInfoObject) : vector<u8> {
        let price_info = pyth_network::price_info::get_price_info_from_price_info_object(price_info_object);
        let price_identifier = pyth_network::price_info::get_price_identifier(&price_info);
        pyth_network::price_identifier::get_bytes(&price_identifier)
    }
    
    public fun base_div(numerator: u128, denominator: u128) : u128 {
        numerator * 1000000000 / denominator
    }
    
    public fun base_mul(value1: u128, value2: u128) : u128 {
        value1 * value2 / 1000000000
    }
    
    public fun base_uint() : u128 {
        1000000000
    }
    
    public fun ceil(value: u128, multiple: u128) : u128 {
        (value + multiple - 1) / multiple * multiple
    }
    
    public fun compute_mro(leverage: u128) : u128 {
        base_div(base_uint(), leverage)
    }
    
    public fun convert_usdc_to_base_decimals(amount: u128) : u128 {
        amount * 1000
    }
    
    public fun get_hash(data: vector<u8>) : vector<u8> {
        std::hash::sha2_256(data)
    }
    
    public entry fun get_oracle_base(price_info_object: &pyth_network::price_info::PriceInfoObject) : u128 {
        abort bluefin::error::method_depricated()
    }
    
    public(friend) fun get_oracle_base_v2(price_info_object: &pyth_network::price_info::PriceInfoObject, clock: &sui::clock::Clock) : u128 {
        let price = pyth_network::pyth::get_price_no_older_than(price_info_object, clock, 600);
        let exponent = pyth_network::price::get_expo(&price);
        (pyth_network::i64::get_magnitude_if_negative(&exponent) as u128)
    }
    
    public entry fun get_oracle_price(price_info_object: &pyth_network::price_info::PriceInfoObject) : u128 {
        abort bluefin::error::method_depricated()
    }
    
    public(friend) fun get_oracle_price_v2(price_info_object: &pyth_network::price_info::PriceInfoObject, clock: &sui::clock::Clock) : u128 {
        let price = pyth_network::pyth::get_price_no_older_than(price_info_object, clock, 600);
        let price_value = pyth_network::price::get_price(&price);
        (pyth_network::i64::get_magnitude_if_positive(&price_value) as u128)
    }
    
    public fun get_public_address(public_key_bytes: vector<u8>) : address {
        let hash = sui::hash::blake2b256(&public_key_bytes);
        let address_bytes = std::vector::empty<u8>();
        let index = 0;
        while (index < 32) {
            std::vector::push_back<u8>(&mut address_bytes, *std::vector::borrow<u8>(&hash, index));
            index = index + 1;
        };
        sui::address::from_bytes(address_bytes)
    }
    
    public fun get_result_public_key(result: VerificationResult) : vector<u8> {
        result.public_key
    }
    
    public fun get_result_status(result: VerificationResult) : bool {
        result.is_verified
    }
    
    public fun half_base_uint() : u128 {
        500000000
    }
    
    public fun min(value1: u128, value2: u128) : u128 {
        if (value1 < value2) {
            value1
        } else {
            value2
        }
    }
    
    public fun round(value: u128, step_size: u128) : u128 {
        let rounded_value = value + step_size * 5 / 10;
        rounded_value - rounded_value % step_size
    }
    
    public fun round_down(value: u128) : u128 {
        value / base_uint() * base_uint()
    }
    
    public fun sub(value1: u128, value2: u128) : u128 {
        if (value1 > value2) {
            value1 - value2
        } else {
            0
        }
    }
    
    public fun to_1x9_vec(values: vector<u128>) : vector<u128> {
        let scaled_values = std::vector::empty<u128>();
        let index = 0;
        while (index < std::vector::length<u128>(&values)) {
            std::vector::push_back<u128>(&mut scaled_values, *std::vector::borrow<u128>(&values, index) / 1000000000);
            index = index + 1;
        };
        scaled_values
    }
    
    public fun verify_signature(message: vector<u8>, signature: vector<u8>, data_hash: vector<u8>) : VerificationResult {
        let signature_type = std::vector::pop_back<u8>(&mut message);
        let verification_result = VerificationResult{
            is_verified : false,
            public_key  : signature,
        };
        
        if (signature_type == 0) {
            verification_result.is_verified = sui::ecdsa_k1::secp256k1_verify(&message, &signature, &data_hash, 1);
            std::vector::insert<u8>(&mut verification_result.public_key, 1, 0);
        } else if (signature_type == 1) {
            let hashed_data = get_hash(data_hash);
            verification_result.is_verified = sui::ed25519::ed25519_verify(&message, &signature, &hashed_data);
            std::vector::insert<u8>(&mut verification_result.public_key, 0, 0);
        } else if (signature_type == 2) {
            let hashed_data = get_hash(data_hash);
            let composite_data = std::vector::empty<u8>();
            std::vector::push_back<u8>(&mut composite_data, 3);
            std::vector::push_back<u8>(&mut composite_data, 0);
            std::vector::push_back<u8>(&mut composite_data, 0);
            std::vector::append<u8>(&mut composite_data, sui::bcs::to_bytes<vector<u8>>(&hashed_data));
            let blake2b_hash = sui::hash::blake2b256(&composite_data);
            verification_result.is_verified = sui::ed25519::ed25519_verify(&message, &signature, &blake2b_hash);
            std::vector::insert<u8>(&mut verification_result.public_key, 0, 0);
        } else if (signature_type == 3) {
            verification_result.is_verified = true;
        };
        verification_result
    }
}
