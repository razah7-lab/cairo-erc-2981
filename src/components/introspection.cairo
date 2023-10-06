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
        fn supports_interface(self: @ComponentState<TContractState>, interface_id: felt252) -> bool {
            if interface_id == super::ISRC5_ID {
                return true;
            }
            self.SRC5_supported_interfaces.read(interface_id)
        }
    }

    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of super::SRC5Internal<ComponentState<TContractState>>{
        fn register_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            self.SRC5_supported_interfaces.write(interface_id, true);
        }

        fn deregister_interface(ref self: ComponentState<TContractState>, interface_id: felt252) {
            assert(interface_id != super::ISRC5_ID, errors::INVALID_ID);
            self.SRC5_supported_interfaces.write(interface_id, false);
        }
    }
}

#[inline(always)]
fn unsafe_state<TContractState>() -> src5::ComponentState<TContractState> {
    src5::unsafe_new_component_state()
}