// Constants

const ISRC5_ID: felt252 = 0x3f918d17e5ee77373b56385708f855659a07f75997f365cf87748628532a055;

#[starknet::interface]
trait ISRC5<TContractState> {
    fn supports_interface(self: @TContractState, interface_id: felt252) -> bool;
}

#[starknet::interface]
trait SRC5Internal<TContractState> {
    fn register_interface(ref self: TContractState, interface_id: felt252);
    fn deregister_interface(ref self: TContractState, interface_id: felt252);
}

#[starknet::component]
mod src5 {
    #[storage]
    struct Storage {
        SRC5_supported_interfaces: LegacyMap<felt252, bool>
    }

    mod errors {
        const INVALID_ID: felt252 = 'SRC5: invalid id';
    }

    #[embeddable_as(SRC5Impl)]
    impl SRC5<
        TContractState, +HasComponent<TContractState>
    > of super::ISRC5<ComponentState<TContractState>> {
        fn supports_interface(
            self: @ComponentState<TContractState>, interface_id: felt252
        ) -> bool {
            if interface_id == super::ISRC5_ID {
                return true;
            }
            self.SRC5_supported_interfaces.read(interface_id)
        }
    }

    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of super::SRC5Internal<ComponentState<TContractState>> {
        fn register_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            self.SRC5_supported_interfaces.write(interface_id, true);
        }

        fn deregister_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            assert(interface_id != super::ISRC5_ID, errors::INVALID_ID);
            self.SRC5_supported_interfaces.write(interface_id, false);
        }
    }
}

#[cfg(test)]
mod test {
    // Starknet imports

    use cairo_erc_2981::components::introspection::SRC5Internal;
    use starknet::testing;

    // Local imports

    use super::{src5, ISRC5_ID};
    use src5::{SRC5, InternalImpl};

    // Contract

    #[starknet::contract]
    mod contract {
        use super::src5 as src5_component;

        component!(path: src5_component, storage: src5, event: SRC5Event);
        impl SRC5 = src5_component::SRC5Impl::<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            src5: src5_component::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            SRC5Event: src5_component::Event
        }
    }

    // State

    type State = src5::ComponentState<contract::ContractState>;
    impl StateDefault of Default<State> {
        fn default() -> State {
            src5::component_state_for_testing()
        }
    }

    // Constants

    const INTERFACE: felt252 = 'INTERFACE';
    const NEW_INTERFACE: felt252 = 'NEW_INTERFACE';

    // Tests

    #[test]
    #[available_gas(250_000)]
    fn test_src5_initialization() {
        let mut state: State = Default::default();
        assert(state.supports_interface(ISRC5_ID), 'SRC5: wrong supports interface');
    }

    #[test]
    #[available_gas(250_000)]
    fn test_src5_register_interface() {
        let mut state: State = Default::default();
        state.register_interface(INTERFACE);
        assert(state.supports_interface(INTERFACE), 'SRC5: wrong supports interface');
    }

    #[test]
    #[available_gas(250_000)]
    fn test_src5_register_interfaces() {
        let mut state: State = Default::default();
        state.register_interface(INTERFACE);
        state.register_interface(NEW_INTERFACE);
        assert(state.supports_interface(INTERFACE), 'SRC5: wrong supports interface');
        assert(state.supports_interface(NEW_INTERFACE), 'SRC5: wrong supports interface');
    }

    #[test]
    #[available_gas(250_000)]
    fn test_src5_deregister_interface() {
        let mut state: State = Default::default();
        state.register_interface(INTERFACE);
        state.register_interface(NEW_INTERFACE);
        state.deregister_interface(NEW_INTERFACE);
        assert(state.supports_interface(INTERFACE), 'SRC5: wrong supports interface');
        assert(!state.supports_interface(NEW_INTERFACE), 'SRC5: wrong supports interface');
    }

    #[test]
    #[available_gas(250_000)]
    #[should_panic(expected: ('SRC5: invalid id',))]
    fn test_src5_deregister_interface_isrc5() {
        let mut state: State = Default::default();
        state.deregister_interface(ISRC5_ID);
    }
}

