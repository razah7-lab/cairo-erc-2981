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
    // Local deps

    use super::upgradable as upgradable;

    // Contract

    #[starknet::contract]
    mod contract {
        use super::upgradable as upgradable;

        component!(path: upgradable, storage: upgradable, event: UpgradableEvent);
        impl Upgradable = upgradable::UpgradableImpl<ContractState>;

        #[storage]
        struct Storage {
            #[substorage(v0)]
            upgradable: upgradable::Storage
        }

        #[event]
        #[derive(Drop, starknet::Event)]
        enum Event {
            UpgradableEvent: upgradable::Event
        }
    }

    // Constants

    fn STATE() -> contract::ContractState {
        contract::unsafe_new_contract_state()
    }

    fn ZERO() -> starknet::ClassHash {
        starknet::class_hash_const::<0>()
    }

    // Tests

    #[test]
    #[available_gas(250_000)]
    fn test_upgrade() {
        // [Setup]
        let mut state = STATE();
        contract::Upgradable::upgrade(ref state, ZERO());
    }
}