// The 'pledge_vote' program.
program pledge_vote.aleo {

    struct Proposal {
        id: u64,
        title: field,
        proposer: address,
        summary: field,
        body: field,
        // staked_token_id: u64,
        dao_id: u64,
        created: u64,
        duration: u64,
        // 0<=proposal_type<8  0、Create DAO 1、Protocol Upgrade 2、Documentation and Education Resources 3、Fund Allocation 4、Governance Process 5、Community Development 6、New Project / Collaboration    7、Parameter Adjustment
        proposal_type: u8,
        // participating_tokens_amount: u64,
        adopt: u64,
        reject: u64,
        // 0<=status<4    0、未开始   1、进行中   2、通过     3、不通过     4、无效
        status: u8,
    }

    struct Profile {
        name: field,
        avatar: field,
        bio: field,
    }

    struct DAOSchema {
        name: field,
        // 0<=daoType<7  0、Finance 1、Governance 2、Community 3、Investment 4、Creative 5、Charity 6、Education
        dao_type: u8,
        creater: address,
        icon: field,
        description: field,
        official_link: field,
    }

    struct DAO {
        id: u64,
        name: field,
        // 0<=daoType<7  0、Finance 1、Governance 2、Community 3、Investment 4、Creative 5、Charity 6、Education
        dao_type: u8,
        creator: address,
        token_info_id: u64,
        icon: field,
        description: field,
        official_link: field,
        proposal_count: u64,
        pass_proposal_count: u64,
        vote_count: u64,
        passed_votes_proportion: u64,  // passed_votes_proportion<=100
        passed_tokens_proportion: u64,  // passed_tokens_proportion<=100
    }
    
    record Token {
        // id: u64,
        owner: address,
        gates: u64,
        token_info_id: u64,
        amount: u64,
        // is_staked: bool, 
        // staked_stage等于质押时最新提案ID,使用质押代币Token对提案Proposal投票时，若Token.staked_stage<Proposal.id,无法对其投票
        // staked_stage: u64,  // staked_stage=0:未质押状态    staked_stage>0:在投票周期为staked_stage时质押
        // staked: u64,    // staked=0:未质押状态    staked>0:时间戳为staked时质押
        expires: u64,
        staked_at: u64,     // 提案ID

    }

    struct HoldToken {
        // id: u64,
        token_owner: field,
        amount: u64,
        // staked: u64,
        token_info_id: u64,
    }

    struct TokenInfo {
        id: u64,
        name: field,
        symbol: field,
        supply: u64,
        decimals: u8,
        max_mint_amount: u64,
        minted_amount: u64,
        dao_id: u64,
        only_creator_can_mint: bool,
        // contract: field,
    }

    struct TokenInfoSchema {
        name: field,
        symbol: field,
        supply: u64,
        decimals: u8,
        max_mint_amount: u64,
        // contract: field,
    }

    struct Vote {
        voter: field,
        proposal_id: u64,
        // token_id: u64,
        is_agreed: bool,
        time: u64,
        amount: u64,
    }

    // key:0、timestamp    1、TokenInfo_id     2、Proposal_id      3、DAO_id     4、vote_id        5、
    mapping auto_increment: u8 => u64; 

    mapping profiles: address => Profile;

    mapping daos: u64 => DAO;        

    mapping token_infos: u64 => TokenInfo;

    // mapping hold_tokens: u64 => HoldToken;

    // key:field(owner+token_info_id)
    mapping balances: field => HoldToken;

    // key:field(owner+token_info_id)
    mapping stake_amounts: field => HoldToken;

    mapping proposals: u64 => Proposal;

    mapping votes: u64 => Vote;

    // key:token_id value:timestamp
    mapping extend_pledge_period: u64 => u64;

    transition mint(amount: u64, token_info_id: u64) -> Token {
        let owner: address = self.caller;
        return Token {
            owner: owner,
            gates: 0u64,
            amount: amount,
            // staked: 0u64,
            expires: 0u64,
            token_info_id: token_info_id,
            staked_at: 0u64,
        } then finalize (owner, amount, token_info_id);
    }

    finalize mint(owner: address, amount: u64, token_info_id: u64) {
        // 条件：1、amount小于单次最多铸币金额 2、是否仅仅允许创建者铸币  3、是否达到供应量上限
        let token_info: TokenInfo = Mapping::get(token_infos, token_info_id);
        assert(amount <= token_info.max_mint_amount);
        if token_info.only_creator_can_mint {
            let dao: DAO = Mapping::get(daos, token_info.dao_id);
            assert_eq(dao.creator, owner);
        }
        let minted_amount: u64 = token_info.minted_amount + amount;
        assert(minted_amount <= token_info.supply);
        let new_token_info: TokenInfo = TokenInfo {
            id: token_info.id,
            name: token_info.name,
            symbol: token_info.symbol,
            supply: token_info.supply,
            decimals: token_info.decimals,
            max_mint_amount: token_info.max_mint_amount,
            minted_amount: minted_amount,
            dao_id: token_info.dao_id,
            only_creator_can_mint: token_info.only_creator_can_mint,
        };
        Mapping::set(token_infos, token_info.id, new_token_info);
        let hash_owner: field = BHP256::hash(owner);
        let hash_id: field = BHP256::hash(token_info_id);
        let k: field = hash_owner + hash_id;
        let hold_token: HoldToken = Mapping::get_or_init(balances, k, HoldToken{
            token_owner: hash_owner,
            amount: 0u64,
            token_info_id: token_info_id,
        });
        let new_hold_token: HoldToken = HoldToken {
            token_owner: hash_owner,
            amount: hold_token.amount+amount,
            token_info_id: token_info_id,
        };
        Mapping::set(balances, k, new_hold_token);
    }

    transition stake(token: Token, amount: u64, expires: u64) -> (Token, Token) {
        is_available(token);

        // Compute the hash of the token owner.
        let hash: field = BHP256::hash(token.owner);
        let difference: u64 = token.amount - amount;

        let t1: Token = Token {
            owner: token.owner,
            gates: 0u64,
            amount: difference,
            // staked: 0u64,
            expires: 0u64,
            staked_at: 0u64,
            token_info_id: token.token_info_id,
        };

        let t2: Token = Token {
            owner: token.owner,
            gates: token.gates,
            amount: amount,
            // staked: staked,
            expires: expires,
            staked_at: 0u64,
            token_info_id: token.token_info_id,
        };

        return (t1, t2) then finalize (hash, amount, token.token_info_id);
    }

    finalize stake(public hash_owner: field, public amount: u64, token_info_id: u64) {
        let hash_id: field = BHP256::hash(token_info_id);
        let k: field = hash_owner + hash_id;
        let hold_token: HoldToken = Mapping::get_or_init(stake_amounts, k, HoldToken {token_owner: hash_owner, amount: 0u64, token_info_id: token_info_id});
        let new_hold_token: HoldToken = HoldToken {
            token_owner: hash_owner,
            amount: hold_token.amount + amount,
            token_info_id: token_info_id,
        };
        Mapping::set(stake_amounts, k, new_hold_token);
    }

    transition unstake(deposited_token: Token) -> Token {
        let hash: field = BHP256::hash(deposited_token.owner);
        assert_neq(deposited_token.expires, 0u64);
        let t: Token = Token {
            owner: deposited_token.owner,
            gates: deposited_token.gates,
            amount: deposited_token.amount,
            // staked: 0u64,
            expires: 0u64,
            staked_at: 0u64,
            token_info_id: deposited_token.token_info_id,
        };
        return t then finalize(self.caller, hash, deposited_token.amount, deposited_token.token_info_id, deposited_token.expires, deposited_token.staked_at);
    }

    finalize unstake(public caller: address, public hash_owner: field, public amount: u64, public token_info_id: u64, public expires: u64, public staked_at: u64) {
        // 条件：1、考虑提案不通过延长质押  2、质押期限已到
        let timestamp: u64 = Mapping::get(auto_increment, 0u8);
        assert(expires<=timestamp);
        //  以下if代码存在问题
        // if staked_at >= 1u64 {
        //     let proposal: Proposal = Mapping::get(proposals, staked_at);
        //     if (proposal.status != 2u8) && (proposal.proposer == caller) {
        //         let end: u64 = Mapping::get(extend_pledge_period, staked_at);
        //         assert(end<=timestamp);
        //     }
        // }
        let hash_id: field = BHP256::hash(token_info_id);
        let k: field = hash_owner + hash_id;
        let hold_token: HoldToken = Mapping::get(stake_amounts, k);
        let new_hold_token: HoldToken = HoldToken {
            token_owner: hash_owner,
            amount: hold_token.amount - amount,
            token_info_id: token_info_id,
        };
        Mapping::set(stake_amounts, k, new_hold_token);
    }

    /* Transfer */
    transition transfer(token: Token, receiver: address, amount: u64) -> (Token, Token) {
        // Transfer the tokens publicly, by invoking the computation on-chain.
        is_available(token);
        let difference: u64 = token.amount - amount;

        let t1: Token = Token {
            owner: token.owner,
            gates: token.gates,
            amount: difference,
            expires: token.expires,
            staked_at: token.staked_at,
            token_info_id: token.token_info_id,
        };

        let t2: Token = Token {
            owner: receiver,
            gates: 0u64,
            amount: amount,
            expires: 0u64,
            staked_at: 0u64,
            token_info_id: token.token_info_id,
        };
        return (t1, t2) then finalize(self.caller, receiver, amount, token.token_info_id);
    }

    finalize transfer(sender: address, receiver: address, amount: u64, token_info_id: u64) {     
        let sender_hash: field = BHP256::hash(sender);
        let receiver_hash: field = BHP256::hash(receiver);
        let hash_id: field = BHP256::hash(token_info_id);
        let k1: field = sender_hash + hash_id;
        let hold_token1: HoldToken = Mapping::get_or_init(balances, k1, HoldToken{
            token_owner: sender_hash,
            amount: 0u64,
            token_info_id: token_info_id,
        });
        let new_hold_token1: HoldToken = HoldToken {
            token_owner: sender_hash,
            amount: hold_token1.amount-amount,
            token_info_id: token_info_id,
        };
        Mapping::set(balances, k1, new_hold_token1);
        let k2: field = receiver_hash + hash_id;
        let hold_token2: HoldToken = Mapping::get_or_init(balances, k2, HoldToken{
            token_owner: receiver_hash,
            amount: 0u64,
            token_info_id: token_info_id,
        });
        let new_hold_token2: HoldToken = HoldToken {
            token_owner: receiver_hash,
            amount: hold_token2.amount+amount,
            token_info_id: token_info_id,
        };
        Mapping::set(balances, k2, new_hold_token2);
    }

    transition join(t0: Token, t1: Token) -> Token {
        is_available(t0);
        assert_eq(t0.token_info_id, t1.token_info_id);
        let sum: u64 = t0.amount + t1.amount;
        let t2: Token = Token {
            owner: t0.owner,
            gates: t0.gates+t1.gates,
            amount: sum,
            expires: 0u64,
            staked_at: 0u64,
            token_info_id: t0.token_info_id,
        };
        return t2;
    }

    transition split(t0: Token, amount: u64) -> (Token, Token) {
        is_available(t0);
        let difference: u64 = t0.amount - amount;
        let t1: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: difference,
            expires: t0.expires,
            staked_at: t0.staked_at,
            token_info_id: t0.token_info_id,
        };

        let t2: Token = Token {
            owner: t0.owner,
            gates: 0u64,
            amount: amount,
            expires: 0u64,
            staked_at: 0u64,
            token_info_id: t0.token_info_id,
        };

        return (t1, t2);
    }

    transition fee(t0: Token, amount: u64) -> Token {
        is_available(t0);
        let difference: u64 = t0.amount - amount;
        let t1: Token = Token {
            owner: t0.owner,
            gates: t0.gates,
            amount: difference,
            expires: t0.expires,
            staked_at: t0.staked_at,
            token_info_id: t0.token_info_id,
        };

        return t1 then finalize(t0.owner, amount, t0.token_info_id);
    }

    finalize fee(owner: address, amount: u64, token_info_id: u64) {
        let token_info: TokenInfo = Mapping::get(token_infos, token_info_id);
        let minted_amount: u64 = token_info.minted_amount - amount;
        assert(minted_amount <= token_info.supply);
        let new_token_info: TokenInfo = TokenInfo {
            id: token_info.id,
            name: token_info.name,
            symbol: token_info.symbol,
            supply: token_info.supply,
            decimals: token_info.decimals,
            max_mint_amount: token_info.max_mint_amount,
            minted_amount: minted_amount,
            dao_id: token_info.dao_id,
            only_creator_can_mint: token_info.only_creator_can_mint,
        };
        Mapping::set(token_infos, token_info.id, new_token_info);
        let hash_owner: field = BHP256::hash(owner);
        let hash_id: field = BHP256::hash(token_info_id);
        let k: field = hash_owner + hash_id;
        let hold_token: HoldToken = Mapping::get_or_init(balances, k, HoldToken{
            token_owner: hash_owner,
            amount: 0u64,
            token_info_id: token_info_id,
        });
        let new_hold_token: HoldToken = HoldToken {
            token_owner: hash_owner,
            amount: hold_token.amount-amount,
            token_info_id: token_info_id,
        };
        Mapping::set(balances, k, new_hold_token);
    }

    transition update_profile (public name: field, public avatar: field, public bio: field) {
        return then finalize(self.caller, name, avatar, bio);
    }

    finalize update_profile (public caller: address, public name: field, public avatar: field, public bio: field) {
        let profile: Profile = Profile {
            name: name,
            avatar: avatar,
            bio: bio,
        };
        Mapping::set(profiles, caller, profile);
    }

    transition update_time (public timestamp: u64) {
        is_admin();
        return then finalize(timestamp);
    }

    finalize update_time (public timestamp: u64) {
        Mapping::set(auto_increment, 0u8, timestamp);
    }

    transition create_dao (public dao_name: field, public dao_type: u8, public icon: field, public description: field, public official_link: field, public passed_votes_proportion: u64, public passed_tokens_proportion: u64, 
        public token_name: field, public symbol: field, public supply: u64, public decimals: u8, public max_mint_amount: u64, public only_creator_can_mint: bool,
        public proposal_id: u64) {
        return then finalize(self.caller, dao_name, dao_type, icon, description, official_link, passed_votes_proportion, passed_tokens_proportion,
        token_name, symbol, supply, decimals, max_mint_amount, only_creator_can_mint,
        proposal_id);
    }

    finalize create_dao (public caller: address, public dao_name: field, public dao_type: u8, public icon: field, public description: field, public official_link: field, public passed_votes_proportion: u64, public passed_tokens_proportion: u64,
        public token_name: field, public symbol: field, public supply: u64, public decimals: u8, public max_mint_amount: u64, public only_creator_can_mint: bool,
        public proposal_id: u64) {
        let proposal: Proposal = Mapping::get(proposals, proposal_id);
        assert_eq(proposal.proposer, caller);
        assert_eq(proposal.dao_id, 0u64);
        assert_eq(proposal.status, 2u8);
        assert_eq(proposal.proposal_type, 0u8);
        assert(passed_votes_proportion<=100u64);
        assert(passed_tokens_proportion<=100u64);
        let dao_id: u64 = Mapping::get(auto_increment, 3u8);
        let token_info_id: u64 = Mapping::get_or_init(auto_increment, 1u8, 0u64);
        Mapping::set(auto_increment, 3u8, dao_id+1u64);
        Mapping::set(auto_increment, 1u8, token_info_id+1u64);
        let dao: DAO = DAO {
            id: dao_id,
            name: dao_name,
            // 0<=daoType<7  0、Finance 1、Governance 2、Community 3、Investment 4、Creative 5、Charity 6、Education
            dao_type: dao_type,
            creator: caller,
            token_info_id: token_info_id,
            icon: icon,
            description: description,
            official_link: official_link,
            proposal_count: 0u64,
            pass_proposal_count: 0u64,
            vote_count: 0u64,
            passed_votes_proportion: passed_votes_proportion,
            passed_tokens_proportion: passed_tokens_proportion,
        };
        let token_info: TokenInfo = TokenInfo {
            id: token_info_id,
            name: token_name,
            symbol: symbol,
            supply: supply,
            decimals: decimals,
            max_mint_amount: max_mint_amount,
            minted_amount: 0u64,
            dao_id: dao_id,
            only_creator_can_mint: only_creator_can_mint,
        };
        Mapping::set(daos, dao_id, dao);
        Mapping::set(token_infos, token_info_id, token_info);
    }

    transition update_dao (public dao_id: u64, public dao_name: field, public dao_type: u8, public icon: field, public description: field, public official_link: field) {
        return then finalize(self.caller, dao_id, dao_name, dao_type, icon, description, official_link);
    }

    finalize update_dao (public caller: address, public dao_id: u64,public dao_name: field, public dao_type: u8, public icon: field, public description: field, public official_link: field) {
        let dao: DAO = Mapping::get(daos, dao_id);
        assert_eq(dao.creator, caller);
        let new_dao: DAO = DAO {
            id: dao_id,
            name: dao_name,
            dao_type: dao_type,
            creator: dao.creator,
            token_info_id: dao.token_info_id,
            icon: icon,
            description: description,
            official_link: official_link,
            proposal_count: dao.proposal_count,
            pass_proposal_count: dao.pass_proposal_count,
            vote_count: dao.vote_count,
            passed_votes_proportion: dao.passed_votes_proportion,
            passed_tokens_proportion: dao.passed_tokens_proportion,
        };
        Mapping::set(daos, dao_id, new_dao);
    }

    transition create_proposal (public title: field, public summary: field, public body: field, public dao_id: u64, public proposal_type: u8) {
        return then finalize(self.caller, title, summary, body, dao_id, proposal_type);
    }

    finalize create_proposal (public caller: address, public title: field, public summary: field, public body: field, public dao_id: u64, public proposal_type: u8) {
        let proposal_id: u64 = Mapping::get_or_init(auto_increment, 2u8, 1u64);
        Mapping::set(auto_increment, 2u8, proposal_id+1u64);
        let proposal: Proposal = Proposal {
            id: proposal_id,
            title: title,
            proposer: caller,
            summary: summary,
            body: body,
            dao_id: dao_id,
            created: 0u64,
            duration: 0u64,
            proposal_type: proposal_type,
            // participating_tokens_amount: 0u64,
            adopt: 0u64,
            reject: 0u64,
            // 0<=status<4    0、未开始   1、进行中   2、通过     3、不通过
            status: 0u8,
        };
        Mapping::set(proposals, proposal_id, proposal);
    }

    transition start_proposal (public proposal_id: u64, public duration: u64, public token: Token) -> Token {
        // - 条件：
        // - 需要质押代币|代币质押时间为提案持续时间
        // - 题案通过返回代币|
        // - 题案不通过有惩罚|延长代币质押时间
        assert(token.amount>=1000u64);
        assert_neq(token.expires, 0u64);
        let t: Token = Token {
            owner: token.owner,
            gates: token.gates,
            token_info_id: token.token_info_id,
            amount: token.amount,
            expires: token.expires,
            staked_at: proposal_id,
        };
        return t then finalize(self.caller, proposal_id, duration, token.expires);
    }

    finalize start_proposal (public caller: address, public proposal_id: u64, public duration: u64, public expires: u64) {
        let created: u64 = Mapping::get(auto_increment, 0u8);
        let proposal: Proposal = Mapping::get(proposals, proposal_id);
        assert_eq(proposal.proposer, caller);
        assert(duration>=86400u64);
        assert(created+duration<=expires);
        let new_proposal: Proposal = Proposal {
            id: proposal_id,
            title: proposal.title,
            proposer: caller,
            summary: proposal.summary,
            body: proposal.body,
            dao_id: proposal.dao_id,
            created: created,
            duration: duration,
            proposal_type: proposal.proposal_type,
            // participating_tokens_amount: 0u64,
            adopt: 0u64,
            reject: 0u64,
            // 0<=status<4    0、未开始   1、进行中   2、通过     3、不通过
            status: 1u8,
        };
        Mapping::set(proposals, proposal_id, new_proposal);
    }

    transition vote (public proposal_id: u64, token: Token, public is_agree: u8) -> Token {
        // - 投票条件：
        //     - 持有组织的治理代币
        //     - 质押组织的治理代币
        // - 投票权重：
        //     - 代币质押量加权
        // - 投票规则：
        //     - 每个账号可以对同一个提案进行多次投票
        //     - 未质押部分的代币：
        //         - 不可参加投票
        //     - 质押部分的代币：
        //         - 条件：质押起止时间段全包含了投票起止时间段
        //         - 可选择任意数量
        //         - 能进行多次投票
        //         - 投票过的代币无法再选择
        assert(is_agree<2u8);
        assert_neq(token.expires, 0u64);
        assert_eq(token.staked_at, 0u64);
        let t: Token = Token {
            owner: token.owner,
            gates: token.gates,
            token_info_id: token.token_info_id,
            amount: token.amount,
            expires: token.expires,
            staked_at: proposal_id,
        };
        let hash_owner: field = BHP256::hash(token.owner);
        return t then finalize(proposal_id, hash_owner, token.expires, token.amount, token.token_info_id, is_agree);
    }

    finalize vote (proposal_id: u64, hash_owner: field, expires: u64, amount: u64, token_info_id: u64, public is_agree: u8) {
        let proposal: Proposal = Mapping::get(proposals, proposal_id);
        assert(proposal.created+proposal.duration<=expires);
        let token_info: TokenInfo = Mapping::get(token_infos, token_info_id);
        assert_eq(proposal.dao_id, token_info.dao_id);
        let agree: bool = is_agree==1u8 ? true : false;
        let p1: Proposal = Proposal{
            id: proposal_id,
            title: proposal.title,
            proposer: proposal.proposer,
            summary: proposal.summary,
            body: proposal.body,
            dao_id: proposal.dao_id,
            created: proposal.created,
            duration: proposal.duration,
            proposal_type: proposal.proposal_type,
            // participating_tokens_amount: proposal.participating_tokens_amount+amount,
            adopt: proposal.adopt+amount,
            reject: proposal.reject,
            status: proposal.status,
        };
        let p2: Proposal = Proposal{
            id: proposal_id,
            title: proposal.title,
            proposer: proposal.proposer,
            summary: proposal.summary,
            body: proposal.body,
            dao_id: proposal.dao_id,
            created: proposal.created,
            duration: proposal.duration,
            proposal_type: proposal.proposal_type,
            // participating_tokens_amount: proposal.participating_tokens_amount+amount,
            adopt: proposal.adopt,
            reject: proposal.reject+amount,
            status: proposal.status,
        };
        let new_proposal: Proposal = agree ? p1 : p2;
        Mapping::set(proposals, proposal_id, new_proposal);
        let dao: DAO = Mapping::get(daos, proposal.dao_id);
        let new_dao: DAO = DAO {
            id: dao.id,
            name: dao.name,
            dao_type: dao.dao_type,
            creator: dao.creator,
            token_info_id: dao.token_info_id,
            icon: dao.icon,
            description: dao.description,
            official_link: dao.official_link,
            proposal_count: dao.proposal_count,
            pass_proposal_count: dao.pass_proposal_count,
            vote_count: dao.vote_count+1u64,
            passed_votes_proportion: dao.passed_votes_proportion,
            passed_tokens_proportion: dao.passed_tokens_proportion,
        };
        Mapping::set(daos, dao.id, new_dao);

        let time: u64 = Mapping::get(auto_increment, 0u8);
        let vote_id: u64 = Mapping::get_or_init(auto_increment, 4u8, 1u64);
        Mapping::set(auto_increment, 4u8, vote_id+1u64);
        let v: Vote = Vote {
            voter: hash_owner,
            proposal_id: proposal_id,
            is_agreed: agree,
            time: time,
            amount: amount,
        };
        Mapping::set(votes, vote_id, v);
    }

    transition close_proposal (public proposal_id: u64) {
        // - 投票结果判定：
        //     - 当 *投票质押代币总额* ≥ *组织内代币总额* 的3%时：以投票结果为准
        //     - 当 *投票质押代币总额* < *组织内代币总额* 的3%时：拒绝    延长代币质押时间
        return then finalize(self.caller, proposal_id);
    }

    finalize close_proposal (public caller: address, public proposal_id: u64) {
        let proposal: Proposal = Mapping::get(proposals, proposal_id);
        assert_eq(caller, proposal.proposer);
        let timestamp: u64 = Mapping::get(auto_increment, 0u8);
        let end: u64 = proposal.created+proposal.duration;
        assert(end<timestamp);
        let dao: DAO = Mapping::get(daos, proposal.dao_id);
        let token_info: TokenInfo = Mapping::get(token_infos, dao.token_info_id);
        let participating_tokens_amount: u64 = proposal.adopt+proposal.reject;
        let status: u8 = proposal.status;
        let pass_proposal_count: u64 = dao.pass_proposal_count;
        if token_info.minted_amount*dao.passed_tokens_proportion/100u64<participating_tokens_amount && proposal.adopt/participating_tokens_amount>dao.passed_votes_proportion/100u64 {
            status = 2u8;
            pass_proposal_count = pass_proposal_count+1u64;
        } else {
            status = 3u8;
            Mapping::set(extend_pledge_period, proposal_id, end + 2592000u64);
        }
        let new_proposal: Proposal = Proposal{
            id: proposal_id,
            title: proposal.title,
            proposer: proposal.proposer,
            summary: proposal.summary,
            body: proposal.body,
            dao_id: proposal.dao_id,
            created: proposal.created,
            duration: proposal.duration,
            proposal_type: proposal.proposal_type,
            // participating_tokens_amount: proposal.participating_tokens_amount+amount,
            adopt: proposal.adopt,
            reject: proposal.reject,
            status: status,
        };
        let new_dao: DAO = DAO {
            id: dao.id,
            name: dao.name,
            dao_type: dao.dao_type,
            creator: dao.creator,
            token_info_id: dao.token_info_id,
            icon: dao.icon,
            description: dao.description,
            official_link: dao.official_link,
            proposal_count: dao.proposal_count+1u64,
            pass_proposal_count: pass_proposal_count,
            vote_count: dao.vote_count,
            passed_votes_proportion: dao.passed_votes_proportion,
            passed_tokens_proportion: dao.passed_tokens_proportion,
        };
        Mapping::set(proposals, proposal_id, new_proposal);
        Mapping::set(daos, dao.id, new_dao);
    }

    transition init (public timestamp: u64) {
        is_admin();
        return then finalize(self.caller, timestamp);
    }

    finalize init (public creator: address, public timestamp: u64) {
        Mapping::set(auto_increment, 0u8, timestamp);
        let dao_id: u64 = 0u64;
        let token_info_id: u64 = 0u64;
        Mapping::set(auto_increment, 2u8, 1u64);
        Mapping::set(auto_increment, 1u8, 1u64);
        Mapping::set(auto_increment, 3u8, 1u64);
        Mapping::set(auto_increment, 4u8, 1u64);
        let dao: DAO = DAO {
            id: dao_id,
            name: 8320234725348491599field,     //swiftDAO
            // 0<=daoType<7  0、Finance 1、Governance 2、Community 3、Investment 4、Creative 5、Charity 6、Education
            dao_type: 1u8,
            creator: creator,
            token_info_id: token_info_id,
            icon: 8320234725348491599field,
            description: 8320234725348491599field,
            official_link: 8320234725348491599field,
            proposal_count: 0u64,
            pass_proposal_count: 0u64,
            vote_count: 0u64,
            passed_votes_proportion: 50u64,
            passed_tokens_proportion: 3u64,
        };
        let token_info: TokenInfo = TokenInfo {
            id: token_info_id,
            name: 495924635252field,
            symbol: 495924635252field,
            supply: 100000000000u64,
            decimals: 2u8,
            max_mint_amount: 100000000000u64,
            minted_amount: 0u64,
            dao_id: dao_id,
            only_creator_can_mint: true,
        };
        Mapping::set(daos, dao_id, dao);
        Mapping::set(token_infos, token_info_id, token_info);
    }

    transition test () -> (Token, Token) {
        let t1: Token = Token {
            owner: aleo1jht08tf8gr52zhv93k7r0hxh30zjyv4ku4y5h4gz2dfjyksmvy8qtwydvd,
            gates: 0u64,
            amount: 50000000000u64,
            expires: 800000u64,
            staked_at: 0u64,
            token_info_id: 0u64,
        };
        let t2: Token = Token {
            owner: aleo1jht08tf8gr52zhv93k7r0hxh30zjyv4ku4y5h4gz2dfjyksmvy8qtwydvd,
            gates: 0u64,
            amount: 40000000000u64,
            expires: 800000u64,
            staked_at: 0u64,
            token_info_id: 0u64,
        };

        return (t1, t2) then finalize(self.caller, 10u64, t1.token_info_id);
    }

    finalize test (public creator: address, public timestamp: u64, public token_info_id: u64) {
        let hash_owner: field = BHP256::hash(creator);
        let hash_id: field = BHP256::hash(token_info_id);
        let k: field = hash_owner + hash_id;
        let new_hold_token: HoldToken = HoldToken {
            token_owner: hash_owner,
            amount: 90000000000u64,
            token_info_id: token_info_id,
        };
        Mapping::set(stake_amounts, k, new_hold_token);
        Mapping::set(balances, k, new_hold_token);
        Mapping::set(auto_increment, 0u8, timestamp);
        let dao_id: u64 = 0u64;
        // let token_info_id: u64 = 0u64;
        Mapping::set(auto_increment, 2u8, 1u64);
        Mapping::set(auto_increment, 1u8, 1u64);
        Mapping::set(auto_increment, 3u8, 1u64);
        let dao: DAO = DAO {
            id: dao_id,
            name: 8320234725348491599field,     //swiftDAO
            // 0<=daoType<7  0、Finance 1、Governance 2、Community 3、Investment 4、Creative 5、Charity 6、Education
            dao_type: 1u8,
            creator: creator,
            token_info_id: token_info_id,
            icon: 8320234725348491599field,
            description: 8320234725348491599field,
            official_link: 8320234725348491599field,
            proposal_count: 0u64,
            pass_proposal_count: 0u64,
            vote_count: 0u64,
            passed_votes_proportion: 50u64,
            passed_tokens_proportion: 3u64,
        };
        let token_info: TokenInfo = TokenInfo {
            id: token_info_id,
            name: 495924635252field,
            symbol: 495924635252field,
            supply: 100000000000u64,
            decimals: 2u8,
            max_mint_amount: 100000000000u64,
            minted_amount: 0u64,
            dao_id: dao_id,
            only_creator_can_mint: true,
        };
        Mapping::set(daos, dao_id, dao);
        Mapping::set(token_infos, token_info_id, token_info);
        let p: Proposal = Proposal {
            id: 1u64,
            title: 0field,
            proposer: creator,
            summary: 0field,
            body: 0field,
            dao_id: 0u64,
            created: 1u64,
            duration: 2u64,
            proposal_type: 0u8,
            // participating_tokens_amount: 0u64,
            adopt: 50000000000u64,
            reject: 0u64,
            // 0<=status<4    0、未开始   1、进行中   2、通过     3、不通过
            status: 1u8,
        };
        Mapping::set(proposals, 1u64, p);
        Mapping::set(extend_pledge_period, 0u64, 0u64);
    }

    

    inline is_available(token: Token) {
        assert_eq(token.expires, 0u64);
    }

    inline is_admin() {
        assert_eq(self.caller, aleo1jht08tf8gr52zhv93k7r0hxh30zjyv4ku4y5h4gz2dfjyksmvy8qtwydvd);
    }
}
