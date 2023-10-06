use starknet::ContractAddress;

#[starknet::interface]
trait IOwnable<TContractState> {
    fn owner(self: @TContractState) -> ContractAddress;
    fn transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
    fn renounce_ownership(ref self: TContractState);
}

trait OwnableInternal<TContractState> {
    fn initializer(ref self: TContractState, owner: ContractAddress);
    fn assert_only_owner(self: @TContractState);
    fn _transfer_ownership(ref self: TContractState, new_owner: ContractAddress);
}

#[starknet::component]
mod ownable {
    // Starknet imports

    use starknet::ContractAddress;
    use starknet::get_caller_address;

    // Local imports

    use super::IOwnable;

    #[storage]
    struct Storage {
        ownable_owner: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        OwnershipTransferred: OwnershipTransferred
    }

    #[derive(Drop, starknet::Event)]
    struct OwnershipTransferred {
        previous_owner: ContractAddress,
        new_owner: ContractAddress,
    }

    mod errors {
        const NOT_OWNER: felt252 = 'Caller is not the owner';
        const ZERO_ADDRESS_CALLER: felt252 = 'Caller is the zero address';
        const ZERO_ADDRESS_OWNER: felt252 = 'New owner is the zero address';
    }

    #[embeddable_as(OwnableImpl)]
    impl Ownable<
        TContractState, +HasComponent<TContractState>
    > of IOwnable<ComponentState<TContractState>> {
        fn owner(self: @ComponentState<TContractState>) -> ContractAddress {
            self.ownable_owner.read()
        }

        fn transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            assert(!new_owner.is_zero(), errors::ZERO_ADDRESS_OWNER);
            self.assert_only_owner();
            self._transfer_ownership(new_owner);
        }

        fn renounce_ownership(ref self: ComponentState<TContractState>) {
            self.assert_only_owner();
            self._transfer_ownership(Zeroable::zero());
        }
    }

    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of super::OwnableInternal<ComponentState<TContractState>> {
        fn initializer(ref self: ComponentState<TContractState>, owner: ContractAddress) {
            self._transfer_ownership(owner);
        }

        fn assert_only_owner(self: @ComponentState<TContractState>) {
            let owner: ContractAddress = self.ownable_owner.read();
            let caller: ContractAddress = get_caller_address();
            assert(!caller.is_zero(), errors::ZERO_ADDRESS_CALLER);
            assert(caller == owner, errors::NOT_OWNER);
        }

        fn _transfer_ownership(
            ref self: ComponentState<TContractState>, new_owner: ContractAddress
        ) {
            let previous_owner: ContractAddress = self.ownable_owner.read();
            self.ownable_owner.write(new_owner);
            self.emit(OwnershipTransferred { previous_owner, new_owner });
        }
    }
}

#[cfg(test)]
mod test {
    // Starknet imports

    use starknet::testing;

    // Local imports

    use super::ownable;
    use ownable::{Ownable, InternalImpl};

    // Contract

    #[starknet::contract]
    mod contract {
        use super::ownable as ownable_component;

        component!(path: ownable_component, storage: ownable, event: OwnableEvent);
        impl Ownable = ownable_component::OwnableImpl<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            ownable: ownable_component::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            OwnableEvent: ownable_component::Event
        }
    }

    // State

    type State = ownable::ComponentState<contract::ContractState>;
    impl StateDefault of Default<State> {
        fn default() -> State {
            ownable::component_state_for_testing()
        }
    }

    // Constants

    fn ZERO() -> starknet::ContractAddress {
        starknet::contract_address_const::<0>()
    }

    fn OWNER() -> starknet::ContractAddress {
        starknet::contract_address_const::<'OWNER'>()
    }

    fn ANYONE() -> starknet::ContractAddress {
        starknet::contract_address_const::<'ANYONE'>()
    }

    // Tests

    #[test]
    #[available_gas(250_000)]
    fn test_ownable_initialize() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        assert(state.owner() == OWNER(), 'Ownable: wrong owner');
    }

    #[test]
    #[available_gas(250_000)]
    fn test_ownable_assert_only_owner() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        testing::set_caller_address(OWNER());
        state.assert_only_owner();
    }

    #[test]
    #[available_gas(250_000)]
    #[should_panic(expected: ('Caller is the zero address',))]
    fn test_ownable_assert_only_owner_revert_zero() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        testing::set_caller_address(ZERO());
        state.assert_only_owner();
    }

    #[test]
    #[available_gas(250_000)]
    #[should_panic(expected: ('Caller is not the owner',))]
    fn test_ownable_assert_only_owner_revert_not_owner() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        testing::set_caller_address(ANYONE());
        state.assert_only_owner();
    }

    #[test]
    #[available_gas(250_000)]
    fn test_ownable_transfer_ownership() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        testing::set_caller_address(OWNER());
        state.transfer_ownership(ANYONE());
        assert(state.owner() == ANYONE(), 'Ownable: wrong owner');
    }

    #[test]
    #[available_gas(250_000)]
    #[should_panic(expected: ('New owner is the zero address',))]
    fn test_ownable_transfer_ownership_revert_zero() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        state.transfer_ownership(ZERO());
    }

    #[test]
    #[available_gas(250_000)]
    fn test_ownable_renounce_ownership() {
        let mut state: State = Default::default();
        state.initializer(OWNER());
        testing::set_caller_address(OWNER());
        state.renounce_ownership();
        assert(state.owner() == ZERO(), 'Ownable: wrong owner');
    }
}
