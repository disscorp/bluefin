module 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::test {
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
        type_name: 0x1::type_name::TypeName,
        name: 0x1::ascii::String,
        addr: 0x1::ascii::String,
    }
    
    public entry fun hash(arg0: address, arg1: address) {
        let v0 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::get_serialized_order(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::pack_order(arg1, 24, 1000000000000000000, 1000000000000000000, 1000000000000000000, arg0, 1747984534000, 1668690862116));
        let v1 = OrderSerializedEvent{serialized_order: v0};
        0x2::event::emit<OrderSerializedEvent>(v1);
        let v2 = HashGeneratedEvent{hash: 0x1::hash::sha2_256(v0)};
        0x2::event::emit<HashGeneratedEvent>(v2);
    }
    
    public entry fun get_public_address(arg0: vector<u8>) {
        let v0 = PublicAddressGeneratedEvent{addr: 0x2::address::to_bytes(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_public_address(arg0))};
        0x2::event::emit<PublicAddressGeneratedEvent>(v0);
    }
    
    public entry fun verify_signature(arg0: vector<u8>, arg1: vector<u8>, arg2: vector<u8>) {
        let v0 = SignatureVerifiedEvent{is_verified: 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_result_status(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::verify_signature(arg0, arg1, arg2))};
        0x2::event::emit<SignatureVerifiedEvent>(v0);
    }
    
    public entry fun get_public_address_from_signed_order(arg0: address, arg1: address, arg2: u8, arg3: u128, arg4: u128, arg5: u128, arg6: u64, arg7: u128, arg8: vector<u8>, arg9: vector<u8>) {
        let v0 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::get_serialized_order(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::order::pack_order(arg0, arg2, arg3, arg4, arg5, arg1, arg6, arg7));
        let v1 = OrderSerializedEvent{serialized_order: v0};
        0x2::event::emit<OrderSerializedEvent>(v1);
        let v2 = HashGeneratedEvent{hash: 0x1::hash::sha2_256(v0)};
        0x2::event::emit<HashGeneratedEvent>(v2);
        let v3 = 0x2::hex::encode(v0);
        let v4 = EncodedOrder{order: v3};
        0x2::event::emit<EncodedOrder>(v4);
        let v5 = 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::verify_signature(arg8, arg9, v3);
        assert!(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_result_status(v5), 1000);
        let v6 = PublicAddressGeneratedEvent{addr: 0x2::address::to_bytes(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_public_address(0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::library::get_result_public_key(v5)))};
        0x2::event::emit<PublicAddressGeneratedEvent>(v6);
    }
    
    // decompiled from Move bytecode v6
}

