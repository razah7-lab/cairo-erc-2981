//! Component implementing IERC2981.

/// Starknet imports

use starknet::ContractAddress;

/// Constants

const IERC2981_ID: felt252 = 0x2a55205a;

/// IERC2981 interface.
#[starknet::interface]
trait IERC2981<TContractState> {
    /// Return the default royalty.
    ///
    /// # Returns
    ///
    /// * `receiver` - The royalty receiver address.
    /// * `fee_numerator` - The royalty rate numerator.
    /// * `fee_denominator` - The royalty rate denominator.
    fn default_royalty(self: @TContractState) -> (ContractAddress, u256, u256);
    /// Return the token royalty.
    ///
    /// # Arguments
    ///
    /// * `token_id` - The token identifier.
    ///
    /// # Returns
    ///
    /// * `receiver` - The royalty receiver address.
    /// * `fee_numerator` - The royalty rate numerator.
    /// * `fee_denominator` - The royalty rate denominator.
    fn token_royalty(self: @TContractState, token_id: u256) -> (ContractAddress, u256, u256);
    /// Return the royalty info with the specified token id and the sale price.
    ///
    /// Since royalty rate is lower than or equal to 1, royalty_amount is lower than or
    /// equal to sale_price, therefore result matches u256.
    ///
    /// # Arguments
    ///
    /// * `token_id` - The token identifier.
    /// * `sale_price` - The transaction price.
    ///
    /// # Returns
    ///
    /// * `receiver` - The royalty receiver address.
    /// * `royalty_amount` - The royalty amount.
    fn royalty_info(
        self: @TContractState, token_id: u256, sale_price: u256
    ) -> (ContractAddress, u256);
    /// Set the default royalty rate.
    ///
    /// Since float number can not be handled, the rate is managed by a numerator and a denominator.
    /// It fails if receiver is the null address.
    /// It fails if fee_denominator == 0 or fee_numerator > fee_denominator.
    ///
    /// # Arguments
    ///
    /// * `receiver` - The royalty receiver address.
    /// * `fee_numerator` - The royalty rate numerator.
    /// * `fee_denominator` - The royalty rate denominator.
    fn set_default_royalty(
        ref self: TContractState,
        receiver: ContractAddress,
        fee_numerator: u256,
        fee_denominator: u256
    );
    /// Set the token royalty rate.
    ///
    /// Since float number can not be handled, the rate is managed by a numerator and a denominator.
    /// It fails if receiver is the null address.
    /// It fails if fee_denominator == 0 or fee_numerator > fee_denominator.
    ///
    /// # Arguments
    ///
    /// * `token_id` - The token identifier.
    /// * `receiver` - The royalty receiver address.
    /// * `fee_numerator` - The royalty rate numerator.
    /// * `fee_denominator` - The royalty rate denominator.
    fn set_token_royalty(
        ref self: TContractState,
        token_id: u256,
        receiver: ContractAddress,
        fee_numerator: u256,
        fee_denominator: u256
    );
}

#[starknet::interface]
trait ERC2981Internal<TContractState> {
    fn initializer(
        ref self: TContractState,
        receiver: ContractAddress,
        fee_numerator: u256,
        fee_denominator: u256
    );
    fn _default_royalty_info(
        self: @TContractState, sale_price: u256
    ) -> (ContractAddress, u256);
    fn _token_royalty_info(
        self: @TContractState, token_id: u256, sale_price: u256
    ) -> (ContractAddress, u256);
}

/// ERC2981 component.
#[starknet::component]
mod erc2981 {
    // Starknet imports

    use starknet::ContractAddress;

    // Internal imports

    use cairo_erc_2981::components::introspection::{src5, SRC5Internal};

    // Local imports

    use super::{IERC2981_ID, IERC2981};

    #[storage]
    struct Storage {
        _receiver: ContractAddress,
        _token_receiver: LegacyMap<u256, ContractAddress>,
        _fee_numerator: u256,
        _token_fee_numerator: LegacyMap<u256, u256>,
        _fee_denominator: u256,
        _token_fee_denominator: LegacyMap<u256, u256>,
    }

    #[embeddable_as(ERC2981Impl)]
    impl ERC2981<
        TContractState,
        +HasComponent<TContractState>,
        +src5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of IERC2981<ComponentState<TContractState>> {
        fn default_royalty(self: @ComponentState<TContractState>) -> (ContractAddress, u256, u256) {
            (self._receiver.read(), self._fee_numerator.read(), self._fee_denominator.read())
        }

        fn token_royalty(self: @ComponentState<TContractState>, token_id: u256) -> (ContractAddress, u256, u256) {
            (
                self._token_receiver.read(token_id),
                self._token_fee_numerator.read(token_id),
                self._token_fee_denominator.read(token_id)
            )
        }

        fn royalty_info(
            self: @ComponentState<TContractState>, token_id: u256, sale_price: u256
        ) -> (ContractAddress, u256) {
            let receiver = self._token_receiver.read(token_id);
            if !receiver.is_zero() {
                return self._token_royalty_info(token_id, sale_price);
            }
            self._default_royalty_info(sale_price)
        }

        fn set_default_royalty(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            fee_numerator: u256,
            fee_denominator: u256
        ) {
            // [Check] Receiver is not zero
            assert(!receiver.is_zero(), 'Invalid receiver');

            // [Check] Fee denominator is not zero
            assert(fee_denominator != 0, 'Invalid fee denominator');

            // [Check] Fee is lower or equal to 1
            assert(fee_numerator <= fee_denominator, 'Invalid fee rate');

            // [Effect] Store values
            self._receiver.write(receiver);
            self._fee_numerator.write(fee_numerator);
            self._fee_denominator.write(fee_denominator);
        }

        fn set_token_royalty(
            ref self: ComponentState<TContractState>,
            token_id: u256,
            receiver: ContractAddress,
            fee_numerator: u256,
            fee_denominator: u256
        ) {
            // [Check] Receiver is not zero
            assert(!receiver.is_zero(), 'Invalid receiver');

            // [Check] Fee denominator is not zero
            assert(fee_denominator != 0, 'Invalid fee denominator');

            // [Check] Fee is lower or equal to 1
            assert(fee_numerator <= fee_denominator, 'Invalid fee rate');

            // [Effect] Store values
            self._token_receiver.write(token_id, receiver);
            self._token_fee_numerator.write(token_id, fee_numerator);
            self._token_fee_denominator.write(token_id, fee_denominator);
        }
    }

    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +src5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::ERC2981Internal<ComponentState<TContractState>> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            receiver: ContractAddress,
            fee_numerator: u256,
            fee_denominator: u256
        ) {
            // [Effect] Register interfaces
            let mut contract = self.get_contract_mut();
            let mut component = src5::HasComponent::<TContractState>::get_component_mut(ref contract);
            component.register_interface(IERC2981_ID);

            // [Effect] Update default royalty
            self.set_default_royalty(receiver, fee_numerator, fee_denominator);
        }
        
        fn _default_royalty_info(
            self: @ComponentState<TContractState>, sale_price: u256
        ) -> (ContractAddress, u256) {
            let (receiver, fee_numerator, fee_denominator) = self.default_royalty();
            (receiver, sale_price * fee_numerator / fee_denominator)
        }
        
        fn _token_royalty_info(
            self: @ComponentState<TContractState>, token_id: u256, sale_price: u256
        ) -> (ContractAddress, u256) {
            let (receiver, fee_numerator, fee_denominator) = self.token_royalty(token_id);
            (receiver, sale_price * fee_numerator / fee_denominator)
        }
    }
}

// #[cfg(test)]
// mod Test {
//     // Local deps
//     use super::erc2981;

//     // Constants

//     const FEE_NUMERATOR: u256 = 1;
//     const FEE_DENOMINATOR: u256 = 100;
//     const NEW_FEE_NUMERATOR: u256 = 2;
//     const NEW_FEE_DENOMINATOR: u256 = 101;
//     const TOKEN_ID: u256 = 1;
//     const SALE_PRICE: u256 = 1000000;

//     fn STATE() -> erc2981::ComponentState<()> {
//         erc2981::unsafe_new_component_state()
//     }

//     fn ZERO() -> starknet::ContractAddress {
//         starknet::contract_address_const::<0>()
//     }

//     fn RECEIVER() -> starknet::ContractAddress {
//         starknet::contract_address_const::<'RECEIVER'>()
//     }

//     fn NEW_RECEIVER() -> starknet::ContractAddress {
//         starknet::contract_address_const::<'NEW_RECEIVER'>()
//     }

//     #[test]
//     #[available_gas(250_000)]
//     fn test_initialization() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Assert] Default royalty
//         let (receiver, fee_numerator, fee_denominator) = erc2981::ERC2981::default_royalty(
//             @state
//         );
//         assert(receiver == RECEIVER(), 'Invalid receiver');
//         assert(fee_numerator == FEE_NUMERATOR, 'Invalid fee numerator');
//         assert(fee_denominator == FEE_DENOMINATOR, 'Invalid fee denominator');
//     }

//     #[test]
//     #[available_gas(105_000)]
//     #[should_panic(expected: ('Invalid receiver',))]
//     fn test_initialization_revert_invalid_receiver() {
//         // [Setup]
//         let mut state = STATE();
//         // [Revert] Initialization
//         erc2981::InternalImpl::initializer(ref state, ZERO(), FEE_NUMERATOR, FEE_DENOMINATOR);
//     }

//     #[test]
//     #[available_gas(105_000)]
//     #[should_panic(expected: ('Invalid fee denominator',))]
//     fn test_initialization_revert_invalid_fee_denominator() {
//         // [Setup]
//         let mut state = STATE();
//         // [Revert] Initialization
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, 0);
//     }

//     #[test]
//     #[available_gas(105_000)]
//     #[should_panic(expected: ('Invalid fee rate',))]
//     fn test_initialization_revert_invalid_fee_rate() {
//         // [Setup]
//         let mut state = STATE();
//         // [Revert] Initialization
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_DENOMINATOR, FEE_NUMERATOR);
//     }

//     #[test]
//     #[available_gas(380_000)]
//     fn test_default_royalty() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Assert] Default royalty info
//         let (receiver, royalty_amount) = erc2981::ERC2981::royalty_info(
//             @state, TOKEN_ID, SALE_PRICE
//         );
//         assert(receiver == RECEIVER(), 'Invalid receiver');
//         assert(
//             royalty_amount == SALE_PRICE * FEE_NUMERATOR / FEE_DENOMINATOR, 'Invalid royalty amount'
//         );
//     }

//     #[test]
//     #[available_gas(480_000)]
//     fn test_set_default_royalty() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Effect] Set default royalty
//         erc2981::ERC2981::set_default_royalty(
//             ref state, NEW_RECEIVER(), NEW_FEE_NUMERATOR, NEW_FEE_DENOMINATOR
//         );
//         // [Assert] Default royalty info
//         let (receiver, royalty_amount) = erc2981::ERC2981::royalty_info(
//             @state, TOKEN_ID, SALE_PRICE
//         );
//         assert(receiver == NEW_RECEIVER(), 'Invalid receiver');
//         assert(
//             royalty_amount == SALE_PRICE * NEW_FEE_NUMERATOR / NEW_FEE_DENOMINATOR,
//             'Invalid royalty amount'
//         );
//     }

//     #[test]
//     #[available_gas(760_000)]
//     fn test_set_token_royalty() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Effect] Set token royalty
//         erc2981::ERC2981::set_token_royalty(
//             ref state, TOKEN_ID, NEW_RECEIVER(), NEW_FEE_NUMERATOR, NEW_FEE_DENOMINATOR
//         );

//         // [Assert] Token royalty info
//         let (receiver, royalty_amount) = erc2981::ERC2981::royalty_info(
//             @state, TOKEN_ID, SALE_PRICE
//         );
//         assert(receiver == NEW_RECEIVER(), 'Invalid receiver');
//         assert(
//             royalty_amount == SALE_PRICE * NEW_FEE_NUMERATOR / NEW_FEE_DENOMINATOR,
//             'Invalid royalty amount'
//         );

//         // [Assert] Default royalty info
//         let (receiver, royalty_amount) = erc2981::ERC2981::royalty_info(@state, 0, SALE_PRICE);
//         assert(receiver == RECEIVER(), 'Invalid receiver');
//         assert(
//             royalty_amount == SALE_PRICE * FEE_NUMERATOR / FEE_DENOMINATOR, 'Invalid royalty amount'
//         );
//     }

//     #[test]
//     #[available_gas(250_000)]
//     #[should_panic(expected: ('Invalid receiver',))]
//     fn test_set_token_royalty_revert_invalid_receiver() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Revert] Set token royalty
//         erc2981::ERC2981::set_token_royalty(
//             ref state, TOKEN_ID, ZERO(), NEW_FEE_NUMERATOR, NEW_FEE_DENOMINATOR
//         );
//     }

//     #[test]
//     #[available_gas(250_000)]
//     #[should_panic(expected: ('Invalid fee denominator',))]
//     fn test_set_token_royalty_revert_invalid_fee_denominator() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Revert] Set token royalty
//         erc2981::ERC2981::set_token_royalty(
//             ref state, TOKEN_ID, NEW_RECEIVER(), NEW_FEE_NUMERATOR, 0
//         );
//     }

//     #[test]
//     #[available_gas(250_000)]
//     #[should_panic(expected: ('Invalid fee rate',))]
//     fn test_set_token_royalty_revert_invalid_fee_rate() {
//         // [Setup]
//         let mut state = STATE();
//         erc2981::InternalImpl::initializer(ref state, RECEIVER(), FEE_NUMERATOR, FEE_DENOMINATOR);
//         // [Revert] Set token royalty
//         erc2981::ERC2981::set_token_royalty(
//             ref state, TOKEN_ID, NEW_RECEIVER(), NEW_FEE_DENOMINATOR, NEW_FEE_NUMERATOR
//         );
//     }
// }