module rocket100_dao::tr100_token_escrow {
    use std::signer;
    use std::error;
    use std::vector;
    use aptos_framework::coin::{Self, Coin};
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    
    const E_NOT_AUTHORIZED: u64 = 1;
    const E_ESCROW_ALREADY_EXISTS: u64 = 2;
    const E_ESCROW_NOT_INITIALIZED: u64 = 3;
    const E_INSUFFICIENT_FUNDS: u64 = 4;
    const E_NO_DEPOSIT: u64 = 5;
    
    struct TokenEscrow<phantom CoinType> has key {
        deposits: Coin<CoinType>,
        deposit_records: vector<DepositRecord>,
        deposit_events: event::EventHandle<DepositEvent>,
        withdraw_events: event::EventHandle<WithdrawEvent>,
    }
    
    struct DepositRecord has store, drop, copy {
        user: address,
        amount: u64,
    }
    
    struct DepositEvent has drop, store {
        user: address,
        amount: u64,
        timestamp: u64,
    }
    
    struct WithdrawEvent has drop, store {
        user: address,
        amount: u64,
        timestamp: u64,
    }
    
    public fun initialize_escrow<CoinType>(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        
        assert!(!exists<TokenEscrow<CoinType>>(deployer_addr), error::already_exists(E_ESCROW_ALREADY_EXISTS));
        
        move_to(deployer, TokenEscrow<CoinType> {
            deposits: coin::zero<CoinType>(),
            deposit_records: vector::empty<DepositRecord>(),
            deposit_events: account::new_event_handle<DepositEvent>(deployer),
            withdraw_events: account::new_event_handle<WithdrawEvent>(deployer),
        });
    }
    
    public fun deposit<CoinType>(
        user: &signer,
        amount: u64,
        dao_addr: address
    ) acquires TokenEscrow {
        let user_addr = signer::address_of(user);
        
        assert!(exists<TokenEscrow<CoinType>>(dao_addr), error::not_found(E_ESCROW_NOT_INITIALIZED));
        
        let user_balance = coin::balance<CoinType>(user_addr);
        assert!(user_balance >= amount, error::invalid_argument(E_INSUFFICIENT_FUNDS));
        
        let tokens = coin::withdraw<CoinType>(user, amount);
        
        let escrow = borrow_global_mut<TokenEscrow<CoinType>>(dao_addr);
        coin::merge(&mut escrow.deposits, tokens);
        
        vector::push_back(&mut escrow.deposit_records, DepositRecord {
            user: user_addr,
            amount,
        });
        
        event::emit_event(
            &mut escrow.deposit_events,
            DepositEvent {
                user: user_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            }
        );
    }
    
    public fun withdraw<CoinType>(
        user: address,
        amount: u64,
        dao_addr: address
    ): Coin<CoinType> acquires TokenEscrow {
        assert!(exists<TokenEscrow<CoinType>>(dao_addr), error::not_found(E_ESCROW_NOT_INITIALIZED));
        
        let escrow = borrow_global_mut<TokenEscrow<CoinType>>(dao_addr);
        
        let escrow_balance = coin::value(&escrow.deposits);
        assert!(escrow_balance >= amount, error::invalid_state(E_INSUFFICIENT_FUNDS));
        
        event::emit_event(
            &mut escrow.withdraw_events,
            WithdrawEvent {
                user,
                amount,
                timestamp: timestamp::now_seconds(),
            }
        );
        
        coin::extract(&mut escrow.deposits, amount)
    }
    
    public fun return_tokens_to_user<CoinType>(
        user: address,
        tokens: Coin<CoinType>
    ) {
        if (coin::value(&tokens) > 0) {
            coin::deposit(user, tokens);
        } else {
            coin::destroy_zero(tokens);
        }
    }
    
    public fun has_deposit<CoinType>(
        user: address,
        dao_addr: address
    ): bool acquires TokenEscrow {
        if (!exists<TokenEscrow<CoinType>>(dao_addr)) {
            return false
        };
        
        let escrow = borrow_global<TokenEscrow<CoinType>>(dao_addr);
        
        let i = 0;
        let len = vector::length(&escrow.deposit_records);
        
        while (i < len) {
            let record = vector::borrow(&escrow.deposit_records, i);
            if (record.user == user && record.amount > 0) {
                return true
            };
            i = i + 1;
        };
        
        false
    }
    
    #[view]
    public fun get_deposit_amount<CoinType>(
        user: address,
        dao_addr: address
    ): u64 acquires TokenEscrow {
        if (!exists<TokenEscrow<CoinType>>(dao_addr)) {
            return 0
        };
        
        let escrow = borrow_global<TokenEscrow<CoinType>>(dao_addr);
        
        let i = 0;
        let len = vector::length(&escrow.deposit_records);
        let total_deposit = 0;
        
        while (i < len) {
            let record = vector::borrow(&escrow.deposit_records, i);
            if (record.user == user) {
                total_deposit = total_deposit + record.amount;
            };
            i = i + 1;
        };
        
        total_deposit
    }
    
    #[view]
    public fun get_total_deposits<CoinType>(dao_addr: address): u64 acquires TokenEscrow {
        if (!exists<TokenEscrow<CoinType>>(dao_addr)) {
            return 0
        };
        
        let escrow = borrow_global<TokenEscrow<CoinType>>(dao_addr);
        coin::value(&escrow.deposits)
    }
    
    public entry fun deposit_entry<CoinType>(
        user: &signer,
        amount: u64,
        dao_addr: address
    ) acquires TokenEscrow {
        deposit<CoinType>(user, amount, dao_addr);
    }
}