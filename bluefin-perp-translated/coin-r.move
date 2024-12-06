module bluefin::coin {
    struct COIN has drop {
        dummy_field: bool,
    }
    
    public entry fun burn(treasury_cap: &mut sui::coin::TreasuryCap<COIN>, coin: sui::coin::Coin<COIN>) {
        sui::coin::burn<COIN>(treasury_cap, coin);
    }
    
    fun init(coin: COIN, ctx: &mut sui::tx_context::TxContext) {
        let (treasury_cap, metadata) = sui::coin::create_currency<COIN>(
            coin,
            6,
            b"TUSDCTEST",
            b"Test USDC",
            b"USDC for testing",
            std::option::none<sui::url::Url>(),
            ctx
        );
        sui::transfer::public_freeze_object<sui::coin::CoinMetadata<COIN>>(metadata);
        sui::transfer::public_transfer<sui::coin::TreasuryCap<COIN>>(treasury_cap, sui::tx_context::sender(ctx));
    }
    
    public entry fun mint(
		treasury_cap: &mut sui::coin::TreasuryCap<COIN>,
		amount: u64,
		recipient: address,
		ctx: &mut sui::tx_context::TxContext
	) {
        sui::coin::mint_and_transfer<COIN>(treasury_cap, amount, recipient, ctx);
    }
}
