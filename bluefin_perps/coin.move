module 0xc9ba51116d85cfbb401043f5e0710ab582c4b9b04a139b7df223f8f06bb66fa5::coin {
    struct COIN has drop {
        dummy_field: bool,
    }
    
    public entry fun burn(arg0: &mut 0x2::coin::TreasuryCap<COIN>, arg1: 0x2::coin::Coin<COIN>) {
        0x2::coin::burn<COIN>(arg0, arg1);
    }
    
    fun init(arg0: COIN, arg1: &mut 0x2::tx_context::TxContext) {
        let (v0, v1) = 0x2::coin::create_currency<COIN>(arg0, 6, b"TUSDCTEST", b"Test USDC", b"USDC for testing", 0x1::option::none<0x2::url::Url>(), arg1);
        0x2::transfer::public_freeze_object<0x2::coin::CoinMetadata<COIN>>(v1);
        0x2::transfer::public_transfer<0x2::coin::TreasuryCap<COIN>>(v0, 0x2::tx_context::sender(arg1));
    }
    
    public entry fun mint(arg0: &mut 0x2::coin::TreasuryCap<COIN>, arg1: u64, arg2: address, arg3: &mut 0x2::tx_context::TxContext) {
        0x2::coin::mint_and_transfer<COIN>(arg0, arg1, arg2, arg3);
    }
    
    // decompiled from Move bytecode v6
}

