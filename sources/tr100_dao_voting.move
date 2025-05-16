module rocket100_dao::tr100_dao_voting {
    use std::string::{Self, String};
    use std::vector;
    use std::error;
    use std::signer;
    use aptos_framework::timestamp;
    use aptos_framework::account;
    use aptos_framework::event;
    
    use rocket100_dao::tr100_token_locker;
    
    const DAO_DEPLOYER: address = @0x40e690b806284656dcf6e101039e89fddc12541fa5c18e893b9266ac0dc2c166;
    
    const E_NOT_AUTHORIZED: u64 = 101;
    const E_POLL_NOT_FOUND: u64 = 102;
    const E_POLL_NOT_ACTIVE: u64 = 103;
    const E_POLL_ALREADY_ENDED: u64 = 104;
    const E_POLL_NOT_STARTED: u64 = 105;
    const E_POLL_NOT_ENDED: u64 = 106;
    const E_NO_VOTING_POWER: u64 = 107;
    const E_ALREADY_VOTED: u64 = 108;
    const E_INVALID_OPTION: u64 = 109;
    const E_INVALID_TIMES: u64 = 110;
    
    struct DAOVoting has key {
        poll_count: u64,
        poll_ids: vector<u64>,
        poll_creation_events: event::EventHandle<PollCreationEvent>,
    }
    
    struct Poll has key {
        id: u64,
        title: String,
        start_time: u64,
        end_time: u64,
        votes_option_0: u64,
        votes_option_1: u64,
        voters: vector<address>,
        voter_powers: vector<VoterPower>,
        is_ended: bool,
        vote_events: event::EventHandle<VoteEvent>,
        poll_ended_events: event::EventHandle<PollEndedEvent>,
    }
    
    struct VoterPower has store, drop, copy {
        voter: address,
        power: u64,
    }
    
    struct UserVotingHistory has key {
        participated_polls: vector<u64>,
        participation_events: event::EventHandle<ParticipationEvent>,
    }
    
    struct PollCreationEvent has drop, store {
        poll_id: u64,
        title: String,
        creator: address,
        start_time: u64,
        end_time: u64,
        creation_time: u64,
    }
    
    struct VoteEvent has drop, store {
        poll_id: u64,
        voter: address,
        option: u8,
        voting_power: u64,
        vote_time: u64,
    }
    
    struct PollEndedEvent has drop, store {
        poll_id: u64,
        votes_option_0: u64,
        votes_option_1: u64,
        end_time: u64,
    }
    
    struct ParticipationEvent has drop, store {
        poll_id: u64,
        voter: address,
        vote_time: u64,
    }
    
    public entry fun initialize(deployer: &signer) {
        let deployer_addr = signer::address_of(deployer);
        
        assert!(deployer_addr == DAO_DEPLOYER, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(!exists<DAOVoting>(deployer_addr), error::already_exists(0));
        
        move_to(deployer, DAOVoting {
            poll_count: 0,
            poll_ids: vector::empty<u64>(),
            poll_creation_events: account::new_event_handle<PollCreationEvent>(deployer),
        });
    }
    
    public fun initialize_voting_history(user: &signer) {
        let user_addr = signer::address_of(user);
        
        if (!exists<UserVotingHistory>(user_addr)) {
            move_to(user, UserVotingHistory {
                participated_polls: vector::empty<u64>(),
                participation_events: account::new_event_handle<ParticipationEvent>(user),
            });
        };
    }
    
    public fun create_poll(
        creator: &signer,
        title: String,
        start_time: u64,
        end_time: u64
    ): u64 acquires DAOVoting {
        let creator_addr = signer::address_of(creator);
        
        assert!(creator_addr == DAO_DEPLOYER, error::permission_denied(E_NOT_AUTHORIZED));
        assert!(end_time > start_time, error::invalid_argument(E_INVALID_TIMES));
        
        let dao_voting = borrow_global_mut<DAOVoting>(DAO_DEPLOYER);
        
        let poll_id = dao_voting.poll_count + 1;
        dao_voting.poll_count = poll_id;
        
        vector::push_back(&mut dao_voting.poll_ids, poll_id);
        
        let poll = Poll {
            id: poll_id,
            title,
            start_time,
            end_time,
            votes_option_0: 0,
            votes_option_1: 0,
            voters: vector::empty<address>(),
            voter_powers: vector::empty<VoterPower>(),
            is_ended: false,
            vote_events: account::new_event_handle<VoteEvent>(creator),
            poll_ended_events: account::new_event_handle<PollEndedEvent>(creator),
        };
        
        move_to(creator, poll);
        
        event::emit_event(
            &mut dao_voting.poll_creation_events,
            PollCreationEvent {
                poll_id,
                title,
                creator: creator_addr,
                start_time,
                end_time,
                creation_time: timestamp::now_seconds(),
            }
        );
        
        poll_id
    }
    
    public fun vote<CoinType>(
        voter: &signer,
        poll_id: u64,
        option: u8
    ) acquires Poll, UserVotingHistory {
        let voter_addr = signer::address_of(voter);
        
        assert!(exists<Poll>(DAO_DEPLOYER), error::not_found(E_POLL_NOT_FOUND));
        
        let poll = borrow_global_mut<Poll>(DAO_DEPLOYER);
        
        assert!(poll.id == poll_id, error::invalid_argument(E_POLL_NOT_FOUND));
        
        let current_time = timestamp::now_seconds();
        assert!(current_time >= poll.start_time, error::invalid_state(E_POLL_NOT_STARTED));
        assert!(current_time <= poll.end_time, error::invalid_state(E_POLL_ALREADY_ENDED));
        assert!(!poll.is_ended, error::invalid_state(E_POLL_ALREADY_ENDED));
        
        assert!(option == 0 || option == 1, error::invalid_argument(E_INVALID_OPTION));
        
        assert!(!vector::contains(&poll.voters, &voter_addr), error::already_exists(E_ALREADY_VOTED));
        
        let voting_power = tr100_token_locker::get_available_tokens<CoinType>(voter_addr);
        
        assert!(voting_power > 0, error::invalid_state(E_NO_VOTING_POWER));
        
        tr100_token_locker::reserve_tokens_for_vote<CoinType>(voter_addr, voting_power);
        
        if (option == 0) {
            poll.votes_option_0 = poll.votes_option_0 + voting_power;
        } else {
            poll.votes_option_1 = poll.votes_option_1 + voting_power;
        };
        
        vector::push_back(&mut poll.voters, voter_addr);
        
        vector::push_back(&mut poll.voter_powers, VoterPower { voter: voter_addr, power: voting_power });
        
        event::emit_event(
            &mut poll.vote_events,
            VoteEvent {
                poll_id,
                voter: voter_addr,
                option,
                voting_power,
                vote_time: current_time,
            }
        );
        
        if (!exists<UserVotingHistory>(voter_addr)) {
            initialize_voting_history(voter);
        };
        
        let user_history = borrow_global_mut<UserVotingHistory>(voter_addr);
        
        vector::push_back(&mut user_history.participated_polls, poll_id);
        
        event::emit_event(
            &mut user_history.participation_events,
            ParticipationEvent {
                poll_id,
                voter: voter_addr,
                vote_time: current_time,
            }
        );
    }
    
    public fun end_poll<CoinType>(poll_id: u64) acquires Poll {
        assert!(exists<Poll>(DAO_DEPLOYER), error::not_found(E_POLL_NOT_FOUND));
        
        let poll = borrow_global_mut<Poll>(DAO_DEPLOYER);
        
        assert!(poll.id == poll_id, error::invalid_argument(E_POLL_NOT_FOUND));
        
        assert!(!poll.is_ended, error::invalid_state(E_POLL_ALREADY_ENDED));
        
        let current_time = timestamp::now_seconds();
        assert!(current_time >= poll.end_time, error::invalid_state(E_POLL_NOT_ENDED));
        
        poll.is_ended = true;
        
        let voters_len = vector::length(&poll.voters);
        let i = 0;
        
        while (i < voters_len) {
            let voter = *vector::borrow(&poll.voters, i);
            let voter_power = vector::borrow(&poll.voter_powers, i);
            
            tr100_token_locker::release_tokens_from_vote<CoinType>(voter, voter_power.power);
            
            i = i + 1;
        };
        
        event::emit_event(
            &mut poll.poll_ended_events,
            PollEndedEvent {
                poll_id,
                votes_option_0: poll.votes_option_0,
                votes_option_1: poll.votes_option_1,
                end_time: current_time,
            }
        );
    }
    
    public entry fun create_poll_entry(
        creator: &signer,
        title: vector<u8>,
        start_time: u64,
        end_time: u64
    ) acquires DAOVoting {
        create_poll(creator, string::utf8(title), start_time, end_time);
    }
    
    public entry fun vote_entry<CoinType>(
        voter: &signer,
        poll_id: u64,
        option: u8
    ) acquires Poll, UserVotingHistory {
        vote<CoinType>(voter, poll_id, option);
    }
    
    public entry fun check_and_end_poll_entry<CoinType>(poll_id: u64) acquires Poll {
        assert!(exists<Poll>(DAO_DEPLOYER), error::not_found(E_POLL_NOT_FOUND));
        
        let poll = borrow_global<Poll>(DAO_DEPLOYER);
        
        assert!(poll.id == poll_id, error::invalid_argument(E_POLL_NOT_FOUND));
        
        let current_time = timestamp::now_seconds();
        if (!poll.is_ended && current_time >= poll.end_time) {
            end_poll<CoinType>(poll_id);
        };
    }
    
    #[view]
    public fun is_poll_active(poll_id: u64): bool acquires Poll {
        if (!exists<Poll>(DAO_DEPLOYER)) {
            return false
        };
        
        let poll = borrow_global<Poll>(DAO_DEPLOYER);
        
        if (poll.id != poll_id) {
            return false
        };
        
        let current_time = timestamp::now_seconds();
        current_time >= poll.start_time && current_time <= poll.end_time && !poll.is_ended
    }
    
    #[view]
    public fun get_poll_status(poll_id: u64): (bool, bool, u64, u64, u64, u64) acquires Poll {
        if (!exists<Poll>(DAO_DEPLOYER)) {
            return (false, false, 0, 0, 0, 0)
        };
        
        let poll = borrow_global<Poll>(DAO_DEPLOYER);
        
        if (poll.id != poll_id) {
            return (false, false, 0, 0, 0, 0)
        };
        
        let current_time = timestamp::now_seconds();
        let is_started = current_time >= poll.start_time;
        let is_active = is_started && current_time <= poll.end_time && !poll.is_ended;
        
        (is_started, is_active, poll.start_time, poll.end_time, poll.votes_option_0, poll.votes_option_1)
    }
    
    #[view]
    public fun get_poll_result(poll_id: u64): (bool, u64, u64, u8) acquires Poll {
        if (!exists<Poll>(DAO_DEPLOYER)) {
            return (false, 0, 0, 0)
        };
        
        let poll = borrow_global<Poll>(DAO_DEPLOYER);
        
        if (poll.id != poll_id) {
            return (false, 0, 0, 0)
        };
        
        let winner = if (poll.votes_option_0 > poll.votes_option_1) {
            0
        } else if (poll.votes_option_1 > poll.votes_option_0) {
            1
        } else {
            2
        };
        
        (poll.is_ended, poll.votes_option_0, poll.votes_option_1, winner)
    }
    
    #[view]
    public fun get_user_voting_history(user: address): vector<u64> acquires UserVotingHistory {
        if (!exists<UserVotingHistory>(user)) {
            return vector::empty<u64>()
        };
        
        let user_history = borrow_global<UserVotingHistory>(user);
        user_history.participated_polls
    }
    
    #[view]
    public fun has_user_voted(user: address, poll_id: u64): bool acquires Poll {
        if (!exists<Poll>(DAO_DEPLOYER)) {
            return false
        };
        
        let poll = borrow_global<Poll>(DAO_DEPLOYER);
        
        if (poll.id != poll_id) {
            return false
        };
        
        vector::contains(&poll.voters, &user)
    }
}