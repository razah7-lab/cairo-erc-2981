use starknet::ClassHash;

#[starknet::interface]
trait IUpgradable<TContractState> {
    fn upgrade(ref self: TContractState, new_class_hash: ClassHash);
}

#[starknet::component]
mod upgradable {
    use starknet::ClassHash;
    use starknet::syscalls::replace_class_syscall;

    #[storage]
    struct Storage {
        current_implementation: ClassHash
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ContractUpgraded: ContractUpgraded
    }

    #[derive(Drop, starknet::Event)]
    struct ContractUpgraded {
        old_class_hash: ClassHash,
        new_class_hash: ClassHash
    }

    #[embeddable_as(UpgradableImpl)]
    impl Upgradable<
        TContractState, +HasComponent<TContractState>
    > of super::IUpgradable<ComponentState<TContractState>> {
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            replace_class_syscall(new_class_hash).unwrap();
            let old_class_hash = self.current_implementation.read();
            self.emit(ContractUpgraded { old_class_hash, new_class_hash });
            self.current_implementation.write(new_class_hash);
        }
    }
}

#[cfg(test)]
mod test {
    // Local imports

    use super::upgradable;
    use upgradable::Upgradable;

    // Contract

    #[starknet::contract]
    mod contract {
        use super::upgradable as upgradable_component;

        component!(path: upgradable_component, storage: upgradable, event: UpgradableEvent);
        impl Upgradable = upgradable_component::UpgradableImpl<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            upgradable: upgradable_component::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            UpgradableEvent: upgradable_component::Event
        }
    }

    // State

    type State = upgradable::ComponentState<contract::ContractState>;
    impl StateDefault of Default<State> {
        fn default() -> State {
            upgradable::component_state_for_testing()
        }
    }

    // Constants

    fn ZERO() -> starknet::ClassHash {
        starknet::class_hash_const::<0>()
    }

    // Tests

    #[test]
    #[available_gas(250_000)]
    fn test_upgrade() {
        let mut state: State = Default::default();
        state.upgrade(ZERO());
    }
}
