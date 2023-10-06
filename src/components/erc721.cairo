//! Component implementing IERC2981.

/// Starknet imports

use starknet::ContractAddress;

/// Constants

const IERC721_ID: felt252 = 0x33eb2f84c309543403fd69f0d0f363781ef06ef6faeb0131ff16ea3175bd943;
const IERC721_RECEIVER_ID: felt252 =
    0x3a0dff5f70d80458ad14ae37bb182a728e3c8cdda0402a5daa86620bdf910bc;

/// IERC721 interface.
#[starknet::interface]
trait IERC721<TContractState> {
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn transfer_from(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn safe_transfer_from(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn set_approval_for_all(ref self: TContractState, operator: ContractAddress, approved: bool);
    fn get_approved(self: @TContractState, token_id: u256) -> ContractAddress;
    fn is_approved_for_all(
        self: @TContractState, owner: ContractAddress, operator: ContractAddress
    ) -> bool;
}

trait ERC721Internal<TContractState> {
    fn initializer(ref self: TContractState);
    fn _owner_of(self: @TContractState, token_id: u256) -> ContractAddress;
    fn _exists(self: @TContractState, token_id: u256) -> bool;
    fn _is_approved_or_owner(
        self: @TContractState, spender: ContractAddress, token_id: u256
    ) -> bool;

    fn _approve(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn _set_approval_for_all(
        ref self: TContractState, owner: ContractAddress, operator: ContractAddress, approved: bool
    );
    fn _mint(ref self: TContractState, to: ContractAddress, token_id: u256);
    fn _transfer(
        ref self: TContractState, from: ContractAddress, to: ContractAddress, token_id: u256
    );
    fn _burn(ref self: TContractState, token_id: u256);
    fn _safe_mint(
        ref self: TContractState, to: ContractAddress, token_id: u256, data: Span<felt252>
    );

    fn _safe_transfer(
        ref self: TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    );
    fn _check_on_erc721_received(
        self: @TContractState,
        from: ContractAddress,
        to: ContractAddress,
        token_id: u256,
        data: Span<felt252>
    ) -> bool;
}

/// ERC2981 component.
#[starknet::component]
mod erc721 {
    // Starknet imports

    use starknet::ContractAddress;
    use starknet::get_caller_address;

    // Internal imports

    use cairo_erc_2981::components::introspection::{src5, SRC5Internal};

    #[storage]
    struct Storage {
        _erc721_name: felt252,
        _erc721_symbol: felt252,
        _erc721_owners: LegacyMap<u256, ContractAddress>,
        _erc721_balances: LegacyMap<ContractAddress, u256>,
        _erc721_token_approvals: LegacyMap<u256, ContractAddress>,
        _erc721_operator_approvals: LegacyMap<(ContractAddress, ContractAddress), bool>,
        _erc721_token_uri: LegacyMap<u256, felt252>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Transfer: Transfer,
        Approval: Approval,
        ApprovalForAll: ApprovalForAll
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        #[key]
        from: ContractAddress,
        #[key]
        to: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        #[key]
        owner: ContractAddress,
        #[key]
        approved: ContractAddress,
        #[key]
        token_id: u256
    }

    #[derive(Drop, starknet::Event)]
    struct ApprovalForAll {
        #[key]
        owner: ContractAddress,
        #[key]
        operator: ContractAddress,
        approved: bool
    }

    mod errors {
        const INVALID_TOKEN_ID: felt252 = 'ERC721: invalid token ID';
        const INVALID_ACCOUNT: felt252 = 'ERC721: invalid account';
        const UNAUTHORIZED: felt252 = 'ERC721: unauthorized caller';
        const APPROVAL_TO_OWNER: felt252 = 'ERC721: approval to owner';
        const SELF_APPROVAL: felt252 = 'ERC721: self approval';
        const INVALID_RECEIVER: felt252 = 'ERC721: invalid receiver';
        const ALREADY_MINTED: felt252 = 'ERC721: token already minted';
        const WRONG_SENDER: felt252 = 'ERC721: wrong sender';
        const SAFE_MINT_FAILED: felt252 = 'ERC721: safe mint failed';
        const SAFE_TRANSFER_FAILED: felt252 = 'ERC721: safe transfer failed';
    }

    #[embeddable_as(ERC721Impl)]
    impl ERC721<
        TContractState,
        +HasComponent<TContractState>,
        +src5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::IERC721<ComponentState<TContractState>> {
        fn balance_of(self: @ComponentState<TContractState>, account: ContractAddress) -> u256 {
            assert(!account.is_zero(), errors::INVALID_ACCOUNT);
            self._erc721_balances.read(account)
        }

        fn owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            self._owner_of(token_id)
        }

        fn get_approved(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            assert(self._exists(token_id), errors::INVALID_TOKEN_ID);
            self._erc721_token_approvals.read(token_id)
        }

        fn is_approved_for_all(
            self: @ComponentState<TContractState>, owner: ContractAddress, operator: ContractAddress
        ) -> bool {
            self._erc721_operator_approvals.read((owner, operator))
        }

        fn approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);

            let caller = get_caller_address();
            assert(
                owner == caller || self.is_approved_for_all(owner, caller), errors::UNAUTHORIZED
            );
            self._approve(to, token_id);
        }

        fn set_approval_for_all(
            ref self: ComponentState<TContractState>, operator: ContractAddress, approved: bool
        ) {
            self._set_approval_for_all(get_caller_address(), operator, approved)
        }

        fn transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), errors::UNAUTHORIZED
            );
            self._transfer(from, to, token_id);
        }

        fn safe_transfer_from(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            assert(
                self._is_approved_or_owner(get_caller_address(), token_id), errors::UNAUTHORIZED
            );
            self._safe_transfer(from, to, token_id, data);
        }
    }

    impl InternalImpl<
        TContractState,
        +HasComponent<TContractState>,
        +src5::HasComponent<TContractState>,
        +Drop<TContractState>
    > of super::ERC721Internal<ComponentState<TContractState>> {
        fn initializer(ref self: ComponentState<TContractState>) {
            // [Effect] Register interfaces
            let mut contract = self.get_contract_mut();
            let mut component = src5::HasComponent::<
                TContractState
            >::get_component_mut(ref contract);
            component.register_interface(super::IERC721_ID);
        }

        fn _owner_of(self: @ComponentState<TContractState>, token_id: u256) -> ContractAddress {
            let owner = self._erc721_owners.read(token_id);
            match owner.is_zero() {
                bool::False(()) => owner,
                bool::True(()) => panic_with_felt252(errors::INVALID_TOKEN_ID)
            }
        }

        fn _exists(self: @ComponentState<TContractState>, token_id: u256) -> bool {
            !self._erc721_owners.read(token_id).is_zero()
        }

        fn _is_approved_or_owner(
            self: @ComponentState<TContractState>, spender: ContractAddress, token_id: u256
        ) -> bool {
            let owner = self._owner_of(token_id);
            let is_approved_for_all = self.is_approved_for_all(owner, spender);
            owner == spender || is_approved_for_all || spender == self.get_approved(token_id)
        }

        fn _approve(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            let owner = self._owner_of(token_id);
            assert(owner != to, errors::APPROVAL_TO_OWNER);

            self._erc721_token_approvals.write(token_id, to);
            self.emit(Approval { owner, approved: to, token_id });
        }

        fn _set_approval_for_all(
            ref self: ComponentState<TContractState>,
            owner: ContractAddress,
            operator: ContractAddress,
            approved: bool
        ) {
            assert(owner != operator, errors::SELF_APPROVAL);
            self._erc721_operator_approvals.write((owner, operator), approved);
            self.emit(ApprovalForAll { owner, operator, approved });
        }

        fn _mint(ref self: ComponentState<TContractState>, to: ContractAddress, token_id: u256) {
            assert(!to.is_zero(), errors::INVALID_RECEIVER);
            assert(!self._exists(token_id), errors::ALREADY_MINTED);

            self._erc721_balances.write(to, self._erc721_balances.read(to) + 1);
            self._erc721_owners.write(token_id, to);

            self.emit(Transfer { from: Zeroable::zero(), to, token_id });
        }

        fn _transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256
        ) {
            assert(!to.is_zero(), errors::INVALID_RECEIVER);
            let owner = self._owner_of(token_id);
            assert(from == owner, errors::WRONG_SENDER);

            // Implicit clear approvals, no need to emit an event
            self._erc721_token_approvals.write(token_id, Zeroable::zero());

            self._erc721_balances.write(from, self._erc721_balances.read(from) - 1);
            self._erc721_balances.write(to, self._erc721_balances.read(to) + 1);
            self._erc721_owners.write(token_id, to);

            self.emit(Transfer { from, to, token_id });
        }

        fn _burn(ref self: ComponentState<TContractState>, token_id: u256) {
            let owner = self._owner_of(token_id);

            // Implicit clear approvals, no need to emit an event
            self._erc721_token_approvals.write(token_id, Zeroable::zero());

            self._erc721_balances.write(owner, self._erc721_balances.read(owner) - 1);
            self._erc721_owners.write(token_id, Zeroable::zero());

            self.emit(Transfer { from: owner, to: Zeroable::zero(), token_id });
        }

        fn _safe_mint(
            ref self: ComponentState<TContractState>,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._mint(to, token_id);
            assert(
                self._check_on_erc721_received(Zeroable::zero(), to, token_id, data),
                errors::SAFE_MINT_FAILED
            );
        }

        fn _safe_transfer(
            ref self: ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) {
            self._transfer(from, to, token_id);
            assert(
                self._check_on_erc721_received(from, to, token_id, data),
                errors::SAFE_TRANSFER_FAILED
            );
        }

        fn _check_on_erc721_received(
            self: @ComponentState<TContractState>,
            from: ContractAddress,
            to: ContractAddress,
            token_id: u256,
            data: Span<felt252>
        ) -> bool {
            true
        }
    }
}
