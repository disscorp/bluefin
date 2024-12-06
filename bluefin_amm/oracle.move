module bluefin::oracle {
    struct ObservationManager has copy, drop, store {
        observations: vector<Observation>,
        observation_index: u64,
        observation_cardinality: u64,
        observation_cardinality_next: u64,
    }
    
    struct Observation has copy, drop, store {
        timestamp: u64,
        tick_cumulative: math_library::i64::I64,
        seconds_per_liquidity_cumulative: u256,
        initialized: bool,
    }
    
    public(friend) fun update(
        manager: &mut ObservationManager,
        current_tick: math_library::i32::I32,
        liquidity: u128,
        timestamp: u64
    ) {
        let current_observation = 0x1::vector::borrow<Observation>(&manager.observations, manager.observation_index);
        if (current_observation.timestamp == timestamp) {
            return
        };

        let cardinality = if (manager.observation_cardinality_next > manager.observation_cardinality && 
            manager.observation_index == manager.observation_cardinality - 1) {
            manager.observation_cardinality_next
        } else {
            manager.observation_cardinality
        };

        let next_index = (manager.observation_index + 1) % cardinality;
        *0x1::vector::borrow_mut<Observation>(&mut manager.observations, next_index) = 
            transform(current_observation, timestamp, current_tick, liquidity);
        manager.observation_index = next_index;
        manager.observation_cardinality = cardinality;
    }
    
    public fun binary_search(manager: &ObservationManager, target_timestamp: u64) : (Observation, Observation) {
        let first_index = (manager.observation_index + 1) % manager.observation_cardinality;
        let left = first_index;
        let right = first_index + manager.observation_cardinality - 1;
        let observation_before;
        let observation_after;

        loop {
            let mid = (left + right) / 2;
            observation_before = get_observation(manager, mid % manager.observation_cardinality);
            
            if (!observation_before.initialized) {
                left = mid + 1;
                continue
            };

            observation_after = get_observation(manager, (mid + 1) % manager.observation_cardinality);
            
            if (observation_before.timestamp <= target_timestamp && target_timestamp <= observation_after.timestamp) {
                break
            };

            if (observation_before.timestamp < target_timestamp) {
                left = mid + 1;
                continue
            };
            right = mid - 1;
        };

        (observation_before, observation_after)
    }
    
    public fun default_observation() : Observation {
        Observation{
            timestamp: 0,
            tick_cumulative: math_library::i64::zero(),
            seconds_per_liquidity_cumulative: 0,
            initialized: false,
        }
    }
    
    fun get_observation(manager: &ObservationManager, index: u64) : Observation {
        if (index > 0x1::vector::length<Observation>(&manager.observations) - 1) {
            default_observation()
        } else {
            *0x1::vector::borrow<Observation>(&manager.observations, index)
        }
    }
    
    public fun get_surrounding_observations(
        manager: &ObservationManager,
        target_timestamp: u64,
        tick: math_library::i32::I32,
        liquidity: u128
    ) : (Observation, Observation) {
        let observation = get_observation(manager, manager.observation_index);
        
        if (observation.timestamp <= target_timestamp) {
            if (observation.timestamp == target_timestamp) {
                return (observation, default_observation())
            };
            return (observation, transform(&observation, target_timestamp, tick, liquidity))
        };

        observation = get_observation(manager, (manager.observation_index + 1) % manager.observation_cardinality);
        if (!observation.initialized) {
            observation = *0x1::vector::borrow<Observation>(&manager.observations, 0);
        };

        assert!(observation.timestamp <= target_timestamp, bluefin::errors::invalid_observation_timestamp());
        binary_search(manager, target_timestamp)
    }
    
    public fun initialize_manager(timestamp: u64) : ObservationManager {
        let manager = ObservationManager{
            observations: 0x1::vector::empty<Observation>(),
            observation_index: 0,
            observation_cardinality: 1,
            observation_cardinality_next: 1,
        };
        let initial_observation = default_observation();
        initial_observation.timestamp = timestamp;
        initial_observation.initialized = true;
        0x1::vector::push_back<Observation>(&mut manager.observations, initial_observation);
        manager
    }
    
    public fun observe_single(
        manager: &ObservationManager,
        current_timestamp: u64,
        seconds_ago: u64,
        current_tick: math_library::i32::I32,
        current_liquidity: u128
    ) : (math_library::i64::I64, u256) {
        if (seconds_ago == 0) {
            let observation = get_observation(manager, manager.observation_index);
            if (observation.timestamp != current_timestamp) {
                observation = transform(&observation, current_timestamp, current_tick, current_liquidity);
            };
            return (observation.tick_cumulative, observation.seconds_per_liquidity_cumulative)
        };

        let target_timestamp = current_timestamp - seconds_ago;
        let (before_observation, after_observation) = get_surrounding_observations(manager, target_timestamp, current_tick, current_liquidity);
        
        if (target_timestamp == before_observation.timestamp) {
            (before_observation.tick_cumulative, before_observation.seconds_per_liquidity_cumulative)
        } else {
            let (tick_cumulative, seconds_per_liquidity) = if (target_timestamp == after_observation.timestamp) {
                (after_observation.tick_cumulative, after_observation.seconds_per_liquidity_cumulative)
            } else {
                let time_delta = after_observation.timestamp - before_observation.timestamp;
                let target_delta = target_timestamp - before_observation.timestamp;
                (
                    math_library::i64::add(
                        before_observation.tick_cumulative,
                        math_library::i64::mul(
                            math_library::i64::div(
                                math_library::i64::sub(after_observation.tick_cumulative, before_observation.tick_cumulative),
                                math_library::i64::from(time_delta)
                            ),
                            math_library::i64::from(target_delta)
                        )
                    ),
                    before_observation.seconds_per_liquidity_cumulative + 
                        (after_observation.seconds_per_liquidity_cumulative - before_observation.seconds_per_liquidity_cumulative) * 
                        (target_delta as u256) / (time_delta as u256)
                )
            };
            (tick_cumulative, seconds_per_liquidity)
        }
    }
    
    public fun transform(
        observation: &Observation,
        timestamp: u64,
        tick: math_library::i32::I32,
        liquidity: u128
    ) : Observation {
        let tick_i64 = if (math_library::i32::is_neg(tick)) {
            math_library::i64::neg_from(math_library::i32::abs_u32(tick) as u64)
        } else {
            math_library::i64::from(math_library::i32::abs_u32(tick) as u64)
        };

        let time_delta = timestamp - observation.timestamp;
        let effective_liquidity = if (liquidity == 0) { 1 } else { liquidity };

        Observation{
            timestamp,
            tick_cumulative: math_library::i64::add(
                observation.tick_cumulative,
                math_library::i64::mul(tick_i64, math_library::i64::from(time_delta))
            ),
            seconds_per_liquidity_cumulative: bluefin::utils::overflow_add(
                observation.seconds_per_liquidity_cumulative,
                ((time_delta as u256) << 128) / (effective_liquidity as u256)
            ),
            initialized: true,
        }
    }
}