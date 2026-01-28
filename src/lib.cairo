

#[starknet::interface]
trait IVoting<TContractState> {
    fn add_candidate(ref self: TContractState, name: felt252) -> u32;
    fn start_election(ref self: TContractState);
    fn end_election(ref self: TContractState);
    fn vote(ref self: TContractState, candidate_id: u32);

    fn get_votes(self: @TContractState, candidate_id: u32) -> u32;
    fn candidates_count(self: @TContractState) -> u32;
    fn get_state(self: @TContractState) -> (bool, bool);
}

#[starknet::contract]
mod Voting {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        owner: ContractAddress,
        started: bool,
        ended: bool,

        candidate_count: u32,
        candidate_names: Map<u32, felt252>,
        votes: Map<u32, u32>,
        has_voted: Map<ContractAddress, bool>,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.owner.write(owner);
        self.started.write(false);
        self.ended.write(false);
        self.candidate_count.write(0);
    }

    #[abi(embed_v0)]
    impl VotingImpl of super::IVoting<ContractState> {
        fn add_candidate(ref self: ContractState, name: felt252) -> u32 {
            assert(self.started.read() == false, 'ALREADY_STARTED');

            let mut count = self.candidate_count.read();
            count = count + 1;
            let id = count - 1;

            self.candidate_names.write(id, name);
            self.votes.write(id, 0);
            self.candidate_count.write(count);

            // Auto-start at 5 candidates
            if count == 5 {
                self.started.write(true);
                self.ended.write(false);
            }

            id
        }

        fn start_election(ref self: ContractState) {
            self.started.write(true);
            self.ended.write(false);
        }

        fn end_election(ref self: ContractState) {
            self.ended.write(true);
        }

        fn vote(ref self: ContractState, candidate_id: u32) {
            assert(self.started.read() == true, 'NOT_STARTED');
            assert(self.ended.read() == false, 'ENDED');

            let caller = get_caller_address();
            let already = self.has_voted.read(caller);
            assert(already == false, 'ALREADY_VOTED');

            let v = self.votes.read(candidate_id);
            self.votes.write(candidate_id, v + 1);
            self.has_voted.write(caller, true);
        }

        fn get_votes(self: @ContractState, candidate_id: u32) -> u32 {
            self.votes.read(candidate_id)
        }

        fn candidates_count(self: @ContractState) -> u32 {
            self.candidate_count.read()
        }

        fn get_state(self: @ContractState) -> (bool, bool) {
            (self.started.read(), self.ended.read())
        }
    }
}
