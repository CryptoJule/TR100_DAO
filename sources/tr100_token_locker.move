module rocket100_dao::tr100_token_locker {
    use std::signer;
    use std::error;
    use aptos_framework::event;
    use aptos_framework::account;
    use aptos_framework::timestamp;
    use aptos_framework::coin::{Self};
    
    use rocket100_dao::tr100_token_escrow;
    
    const DAO_DEPLOYER: address = @0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166;
    
    const E_INSUFFICIENT_TOKENS: u64 = 1;
    const E_INSUFFICIENT_LOCKED_TOKENS: u64 = 2;
    const E_NO_LOCKED_TOKENS: u64 = 3;
    const E_TOKENS_LOCKED_IN_VOTE: u64 = 4;
    const E_NOT_REGISTERED_FOR_TOKEN: u64 = 5;
    const E_NO_LOCK_STATUS: u64 = 6;
    const E_NOT_AUTHORIZED: u64 = 7;
    
    struct UserLockStatus<phantom CoinType> has key {
        total_locked: u64,
        tokens_in_votes: u64,
        lock_events: event::EventHandle<LockEvent>,
        unlock_events: event::EventHandle<UnlockEvent>,
    }
    
    struct LockEvent has drop, store {
        user: address,
        amount: u64,
        timestamp: u64,
    }
    
    struct UnlockEvent has drop, store {
        user: address,
        amount: u64,
        timestamp: u64,
    }

    public fun initialize_lock_status<CoinType>(user: &signer) {
        let user_addr = signer::address_of(user);
        
        if (!exists<UserLockStatus<CoinType>>(user_addr)) {
            move_to(user, UserLockStatus<CoinType> {
                total_locked: 0,
                tokens_in_votes: 0,
                lock_events: account::new_event_handle<LockEvent>(user),
                unlock_events: account::new_event_handle<UnlockEvent>(user),
            });
        };
    }
    
    public fun lock_tokens<CoinType>(
        user: &signer,
        amount: u64
    ): u64 acquires UserLockStatus {
        let user_addr = signer::address_of(user);
        
        assert!(coin::is_account_registered<CoinType>(user_addr), error::invalid_state(E_NOT_REGISTERED_FOR_TOKEN));
        
        let balance = coin::balance<CoinType>(user_addr);
        assert!(balance >= amount, error::invalid_argument(E_INSUFFICIENT_TOKENS));
        
        if (!exists<UserLockStatus<CoinType>>(user_addr)) {
            initialize_lock_status<CoinType>(user);
        };
        
        tr100_token_escrow::deposit<CoinType>(user, amount, DAO_DEPLOYER);
        
        let lock_status = borrow_global_mut<UserLockStatus<CoinType>>(user_addr);
        lock_status.total_locked = lock_status.total_locked + amount;
        
        event::emit_event(
            &mut lock_status.lock_events,
            LockEvent {
                user: user_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            }
        );
        
        lock_status.total_locked
    }
    
    public fun unlock_tokens<CoinType>(
        user: &signer,
        amount: u64
    ): u64 acquires UserLockStatus {
        let user_addr = signer::address_of(user);
        
        assert!(exists<UserLockStatus<CoinType>>(user_addr), error::not_found(E_NO_LOCK_STATUS));
        
        let lock_status = borrow_global_mut<UserLockStatus<CoinType>>(user_addr);
        
        assert!(lock_status.total_locked >= amount, error::invalid_argument(E_INSUFFICIENT_LOCKED_TOKENS));
        
        let available_tokens = lock_status.total_locked - lock_status.tokens_in_votes;
        assert!(available_tokens >= amount, error::invalid_state(E_TOKENS_LOCKED_IN_VOTE));
        
        let tokens = tr100_token_escrow::withdraw<CoinType>(user_addr, amount, DAO_DEPLOYER);
        
        tr100_token_escrow::return_tokens_to_user<CoinType>(user_addr, tokens);
        
        lock_status.total_locked = lock_status.total_locked - amount;
        
        event::emit_event(
            &mut lock_status.unlock_events,
            UnlockEvent {
                user: user_addr,
                amount,
                timestamp: timestamp::now_seconds(),
            }
        );
        
        lock_status.total_locked
    }
    
    public fun reserve_tokens_for_vote<CoinType>(
        user: address,
        amount: u64
    ) acquires UserLockStatus {
        assert!(exists<UserLockStatus<CoinType>>(user), error::not_found(E_NO_LOCK_STATUS));
        
        let lock_status = borrow_global_mut<UserLockStatus<CoinType>>(user);
        
        let available_tokens = lock_status.total_locked - lock_status.tokens_in_votes;
        assert!(available_tokens >= amount, error::invalid_state(E_INSUFFICIENT_LOCKED_TOKENS));
        
        lock_status.tokens_in_votes = lock_status.tokens_in_votes + amount;
    }
    
    public fun release_tokens_from_vote<CoinType>(
        user: address,
        amount: u64
    ) acquires UserLockStatus {
        assert!(exists<UserLockStatus<CoinType>>(user), error::not_found(E_NO_LOCK_STATUS));
        
        let lock_status = borrow_global_mut<UserLockStatus<CoinType>>(user);
        
        assert!(lock_status.tokens_in_votes >= amount, error::invalid_state(E_INSUFFICIENT_LOCKED_TOKENS));
        
        lock_status.tokens_in_votes = lock_status.tokens_in_votes - amount;
    }
    
    public entry fun lock_tokens_entry<CoinType>(
        user: &signer,
        amount: u64
    ) acquires UserLockStatus {
        lock_tokens<CoinType>(user, amount);
    }
    
    public entry fun unlock_tokens_entry<CoinType>(
        user: &signer,
        amount: u64
    ) acquires UserLockStatus {
        unlock_tokens<CoinType>(user, amount);
    }
    
    #[view]
    public fun get_locked_tokens<CoinType>(user: address): u64 acquires UserLockStatus {
        if (!exists<UserLockStatus<CoinType>>(user)) {
            return 0
        };
        
        let lock_status = borrow_global<UserLockStatus<CoinType>>(user);
        lock_status.total_locked
    }
    
    #[view]
    public fun get_voting_power<CoinType>(user: address): u64 acquires UserLockStatus {
        if (!exists<UserLockStatus<CoinType>>(user)) {
            return 0
        };
        
        let lock_status = borrow_global<UserLockStatus<CoinType>>(user);
        lock_status.total_locked
    }
    
    #[view]
    public fun get_tokens_in_votes<CoinType>(user: address): u64 acquires UserLockStatus {
        if (!exists<UserLockStatus<CoinType>>(user)) {
            return 0
        };
        
        let lock_status = borrow_global<UserLockStatus<CoinType>>(user);
        lock_status.tokens_in_votes
    }
    
    #[view]
    public fun get_available_tokens<CoinType>(user: address): u64 acquires UserLockStatus {
        if (!exists<UserLockStatus<CoinType>>(user)) {
            return 0
        };
        
        let lock_status = borrow_global<UserLockStatus<CoinType>>(user);
        lock_status.total_locked - lock_status.tokens_in_votes
    }
    
    #[view]
    public fun verify_escrow_balance<CoinType>(user: address): bool {
        tr100_token_escrow::has_deposit<CoinType>(user, DAO_DEPLOYER)
    }
    
    public entry fun initialize_token_escrow<CoinType>(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        
        assert!(deployer_addr == DAO_DEPLOYER, error::permission_denied(E_NOT_AUTHORIZED));
        
        tr100_token_escrow::initialize_escrow<CoinType>(deployer);
    }
}