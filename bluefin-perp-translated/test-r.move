module bluefin::test {
    struct SignatureVerifiedEvent has copy, drop {
        is_verified: bool,
    }
    
    struct PublicKeyRecoveredEvent has copy, drop {
        public_key: vector<u8>,
    }
    
    struct HashGeneratedEvent has copy, drop {
        hash: vector<u8>,
    }
    
    struct OrderSerializedEvent has copy, drop {
        serialized_order: vector<u8>,
    }
    
    struct PublicAddressGeneratedEvent has copy, drop {
        addr: vector<u8>,
    }
    
    struct EncodedOrder has copy, drop {
        order: vector<u8>,
    }
    
    struct CoinValue has copy, drop {
        value: u64,
        type_name: std::type_name::TypeName,
        name: std::ascii::String,
        addr: std::ascii::String,
    }
    
    public entry fun hash(maker: address, taker: address) {
        let serialized_order = bluefin::order::get_serialized_order(
            bluefin::order::pack_order(
                taker, 
                24, 
                1000000000000000000, 
                1000000000000000000, 
                1000000000000000000, 
                maker, 
                1747984534000, 
                1668690862116
            )
        );
        let order_event = OrderSerializedEvent { serialized_order };
        sui::event::emit<OrderSerializedEvent>(order_event);
        
        let hash_event = HashGeneratedEvent { hash: std::hash::sha2_256(serialized_order) };
        sui::event::emit<HashGeneratedEvent>(hash_event);
    }
    
    public entry fun get_public_address(public_key: vector<u8>) {
        let address_event = PublicAddressGeneratedEvent {
            addr: sui::address::to_bytes(bluefin::library::get_public_address(public_key))
        };
        sui::event::emit<PublicAddressGeneratedEvent>(address_event);
    }
    
    public entry fun verify_signature(
        signature: vector<u8>, 
        public_key: vector<u8>, 
        message: vector<u8>
    ) {
        let verify_event = SignatureVerifiedEvent {
            is_verified: bluefin::library::get_result_status(
                bluefin::library::verify_signature(signature, public_key, message)
            )
        };
        sui::event::emit<SignatureVerifiedEvent>(verify_event);
    }
    
    public entry fun get_public_address_from_signed_order(
        maker: address,
        taker: address,
        order_type: u8,
        price: u128,
        quantity: u128,
        leverage: u128,
        expiration: u64,
        salt: u128,
        signature: vector<u8>,
        public_key: vector<u8>
    ) {
        let serialized_order = bluefin::order::get_serialized_order(
            bluefin::order::pack_order(
                maker,
                order_type,
                price,
                quantity,
                leverage,
                taker,
                expiration,
                salt
            )
        );
        
        let order_event = OrderSerializedEvent { serialized_order };
        sui::event::emit<OrderSerializedEvent>(order_event);
        
        let hash_event = HashGeneratedEvent { hash: std::hash::sha2_256(serialized_order) };
        sui::event::emit<HashGeneratedEvent>(hash_event);
        
        let encoded_order = sui::hex::encode(serialized_order);
        let encoded_event = EncodedOrder { order: encoded_order };
        sui::event::emit<EncodedOrder>(encoded_event);
        
        let verification_result = bluefin::library::verify_signature(signature, public_key, encoded_order);
        assert!(bluefin::library::get_result_status(verification_result), 1000);
        
        let address_event = PublicAddressGeneratedEvent {
            addr: sui::address::to_bytes(
                bluefin::library::get_public_address(
                    bluefin::library::get_result_public_key(verification_result)
                )
            )
        };
        sui::event::emit<PublicAddressGeneratedEvent>(address_event);
    }
}