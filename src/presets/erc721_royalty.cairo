#[starknet::contract]
mod ERC721Royalty {
    // Starknet imports
    use starknet::{get_caller_address, ContractAddress, ClassHash};

    // Internal imports
    use cairo_erc_2981::components::upgradable::{upgradable as upgradable_component, IUpgradable};
    use cairo_erc_2981::components::ownable::{
        ownable as ownable_component, IOwnable, OwnableInternal
    };
    use cairo_erc_2981::components::introspection::{src5 as src5_component, ISRC5, SRC5Internal};
    use cairo_erc_2981::components::erc721::{erc721 as erc721_component, IERC721, ERC721Internal};
    use cairo_erc_2981::components::erc2981::{
        erc2981 as erc2981_component, IERC2981, ERC2981Internal
    };

    // Components
    component!(path: upgradable_component, storage: upgradable, event: UpgradableEvent);
    component!(path: ownable_component, storage: ownable, event: OwnableEvent);
    component!(path: src5_component, storage: src5, event: SRC5Event);
    component!(path: erc721_component, storage: erc721, event: ERC721Event);
    component!(path: erc2981_component, storage: erc2981, event: ERC2981Event);

    #[external(v0)]
    impl UpgradableImpl of IUpgradable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            // [Check] Only owner
            self.ownable.assert_only_owner();
            // [Effect] Upgrade
            let mut component = upgradable_component::unsafe_new_component_state::<ContractState>();
            upgradable_component::Upgradable::upgrade(ref component, new_class_hash);
        }
    }

    #[abi(embed_v0)]
    impl Ownable = ownable_component::OwnableImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5 = src5_component::SRC5Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721 = erc721_component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC2981 = erc2981_component::ERC2981Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        upgradable: upgradable_component::Storage,
        #[substorage(v0)]
        ownable: ownable_component::Storage,
        #[substorage(v0)]
        src5: src5_component::Storage,
        #[substorage(v0)]
        erc721: erc721_component::Storage,
        #[substorage(v0)]
        erc2981: erc2981_component::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        UpgradableEvent: upgradable_component::Event,
        OwnableEvent: ownable_component::Event,
        SRC5Event: src5_component::Event,
        ERC721Event: erc721_component::Event,
        ERC2981Event: erc2981_component::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        receiver: ContractAddress,
        fee_numerator: u256,
        fee_denominator: u256,
        owner: ContractAddress
    ) {
        self.initializer(receiver, fee_numerator, fee_denominator, owner);
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn initializer(
            ref self: ContractState,
            receiver: ContractAddress,
            fee_numerator: u256,
            fee_denominator: u256,
            owner: ContractAddress
        ) {
            // Ownable
            self.ownable.initializer(owner);

            // ERC721
            self.erc721.initializer();

            // ERC2981
            self.erc2981.initializer(receiver, fee_numerator, fee_denominator);
        }
    }
}
