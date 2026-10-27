export const idlFactory = ({ IDL }) => {
  const Value = IDL.Rec();
  Value.fill(
    IDL.Variant({
      'Int' : IDL.Int,
      'Map' : IDL.Vec(IDL.Tuple(IDL.Text, Value)),
      'Nat' : IDL.Nat,
      'Blob' : IDL.Vec(IDL.Nat8),
      'Text' : IDL.Text,
      'Array' : IDL.Vec(Value),
    })
  );
  const ProposalAction = IDL.Variant({
    'Code' : IDL.Record({ 'url' : IDL.Text, 'checksum' : IDL.Text }),
    'Operation' : IDL.Record({ 'op' : IDL.Text, 'args' : Value }),
    'Motion' : IDL.Null,
  });
  const ProposalCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'action' : ProposalAction,
    'description' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'department' : IDL.Opt(IDL.Text),
  });
  const GggError = IDL.Variant({
    'GenericError' : IDL.Record({
      'message' : IDL.Text,
      'error_code' : IDL.Nat,
    }),
    'NotFound' : IDL.Null,
    'Unsupported' : IDL.Text,
    'InvalidArgument' : IDL.Text,
    'Unavailable' : IDL.Text,
    'Forbidden' : IDL.Record({
      'permission' : IDL.Opt(IDL.Text),
      'message' : IDL.Text,
    }),
    'Unauthenticated' : IDL.Null,
    'Conflict' : IDL.Text,
  });
  const ProposalCreateResult = IDL.Variant({
    'Ok' : IDL.Text,
    'Err' : GggError,
  });
  const Timestamp = IDL.Nat64;
  const ProposalStatus = IDL.Variant({
    'Failed' : IDL.Null,
    'Withdrawn' : IDL.Null,
    'Draft' : IDL.Null,
    'Rejected' : IDL.Null,
    'Executed' : IDL.Null,
    'Voting' : IDL.Null,
    'Accepted' : IDL.Null,
    'Expired' : IDL.Null,
  });
  const Tally = IDL.Record({
    'no' : IDL.Nat,
    'yes' : IDL.Nat,
    'abstain' : IDL.Nat,
    'eligible' : IDL.Opt(IDL.Nat),
  });
  const Proposal = IDL.Record({
    'id' : IDL.Text,
    'opens_at' : IDL.Opt(Timestamp),
    'status' : ProposalStatus,
    'result' : IDL.Opt(Value),
    'tally' : Tally,
    'title' : IDL.Text,
    'action' : ProposalAction,
    'description' : IDL.Text,
    'deadline' : IDL.Opt(Timestamp),
    'quorum_bps' : IDL.Nat,
    'threshold_bps' : IDL.Nat,
    'proposer' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
  });
  const ProposalGetResult = IDL.Variant({
    'Ok' : IDL.Opt(Proposal),
    'Err' : GggError,
  });
  const ProposalListArgs = IDL.Record({
    'status' : IDL.Opt(ProposalStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const ProposalSummary = IDL.Record({
    'id' : IDL.Text,
    'status' : ProposalStatus,
    'title' : IDL.Text,
    'deadline' : IDL.Opt(Timestamp),
    'proposer' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
  });
  const ProposalPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(ProposalSummary),
  });
  const ProposalListResult = IDL.Variant({
    'Ok' : ProposalPage,
    'Err' : GggError,
  });
  const VoteChoice = IDL.Variant({
    'No' : IDL.Null,
    'Yes' : IDL.Null,
    'Abstain' : IDL.Null,
  });
  const ProposalVoteArgs = IDL.Record({
    'proposal_id' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'choice' : VoteChoice,
  });
  const Vote = IDL.Record({
    'id' : IDL.Text,
    'voter' : IDL.Principal,
    'cast_at' : Timestamp,
    'cast_by' : IDL.Opt(IDL.Principal),
    'proposal_id' : IDL.Text,
    'choice' : VoteChoice,
  });
  const ProposalVoteResult = IDL.Variant({ 'Ok' : Vote, 'Err' : GggError });
  const ProposalVotesArgs = IDL.Record({
    'voter' : IDL.Opt(IDL.Principal),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'proposal_id' : IDL.Text,
  });
  const VotePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Vote),
  });
  const ProposalVotesResult = IDL.Variant({
    'Ok' : VotePage,
    'Err' : GggError,
  });
  const RealmStatus = IDL.Variant({
    'Setup' : IDL.Null,
    'Terminated' : IDL.Null,
    'Production' : IDL.Null,
    'Beta' : IDL.Null,
    'Alpha' : IDL.Null,
    'Deprecation' : IDL.Null,
  });
  const Implementation = IDL.Record({
    'url' : IDL.Opt(IDL.Text),
    'name' : IDL.Text,
    'version' : IDL.Text,
  });
  const Currency = IDL.Record({ 'decimals' : IDL.Nat8, 'symbol' : IDL.Text });
  const Realm = IDL.Record({
    'status' : RealmStatus,
    'name' : IDL.Text,
    'implementation' : Implementation,
    'manifesto' : IDL.Text,
    'is_capital' : IDL.Bool,
    'logo_url' : IDL.Opt(IDL.Text),
    'open_registration' : IDL.Bool,
    'welcome_message' : IDL.Text,
    'member_count' : IDL.Opt(IDL.Nat),
    'background_image_url' : IDL.Opt(IDL.Text),
    'accounting_currency' : IDL.Opt(Currency),
  });
  const MemberStatus = IDL.Variant({
    'Inactive' : IDL.Null,
    'Active' : IDL.Null,
    'Suspended' : IDL.Null,
    'Banned' : IDL.Null,
  });
  const Member = IDL.Record({
    'id' : IDL.Principal,
    'status' : MemberStatus,
    'nickname' : IDL.Opt(IDL.Text),
    'home_quarter' : IDL.Opt(IDL.Text),
    'joined_at' : IDL.Opt(Timestamp),
    'profiles' : IDL.Vec(IDL.Text),
    'avatar' : IDL.Opt(IDL.Text),
  });
  const UserGetResult = IDL.Variant({
    'Ok' : IDL.Opt(Member),
    'Err' : GggError,
  });
  const ListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const MemberPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Member),
  });
  const UserListResult = IDL.Variant({ 'Ok' : MemberPage, 'Err' : GggError });
  const SupportedStandard = IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text });
  return IDL.Service({
    'ggg1_proposal_create' : IDL.Func(
        [ProposalCreateArgs],
        [ProposalCreateResult],
        [],
      ),
    'ggg1_proposal_get' : IDL.Func([IDL.Text], [ProposalGetResult], ['query']),
    'ggg1_proposal_list' : IDL.Func(
        [ProposalListArgs],
        [ProposalListResult],
        ['query'],
      ),
    'ggg1_proposal_vote' : IDL.Func(
        [ProposalVoteArgs],
        [ProposalVoteResult],
        [],
      ),
    'ggg1_proposal_votes' : IDL.Func(
        [ProposalVotesArgs],
        [ProposalVotesResult],
        ['query'],
      ),
    'ggg1_realm_info' : IDL.Func([], [Realm], ['query']),
    'ggg1_user_get' : IDL.Func([IDL.Principal], [UserGetResult], ['query']),
    'ggg1_user_list' : IDL.Func([ListArgs], [UserListResult], ['query']),
    'icrc10_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(SupportedStandard)],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
