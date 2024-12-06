module bluefin::config {
    struct GlobalConfig has store, key {
        id: 0x2::object::UID,
        min_tick: math_library::i32::I32,
        max_tick: math_library::i32::I32,
        version: u64,
        reward_managers: vector<address>,
    }
    
    public fun get_tick_range(config: &GlobalConfig) : (math_library::i32::I32, math_library::i32::I32) {
        (config.min_tick, config.max_tick)
    }
    
    fun init(ctx: &mut 0x2::tx_context::TxContext) {
        let config = GlobalConfig{
            id: 0x2::object::new(ctx),
            min_tick: cetus::tick_math::min_tick(),
            max_tick: cetus::tick_math::max_tick(),
            version: 1,
            reward_managers: 0x1::vector::empty<address>(),
        };
        0x2::transfer::share_object<GlobalConfig>(config);
    }
    
    public(friend) fun set_reward_manager(config: &mut GlobalConfig, manager_address: address) {
        0x1::vector::push_back<address>(&mut config.reward_managers, manager_address);
    }
    
    public fun verify_reward_manager(config: &GlobalConfig, address: address) : bool {
        let index = 0;
        while (index < 0x1::vector::length<address>(&config.reward_managers)) {
            if (*0x1::vector::borrow<address>(&config.reward_managers, index) == address) {
                return true
            };
            index = index + 1;
        };
        false
    }
    
    public fun verify_version(config: &GlobalConfig) {
        assert!(config.version == 1, bluefin::errors::version_mismatch());
    }
}