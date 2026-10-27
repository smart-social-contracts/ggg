export const idlFactory = ({ IDL }) => {
  const ProposalAction = IDL.Variant({
    'Call' : IDL.Record({ 'arg' : IDL.Vec(IDL.Nat8), 'method' : IDL.Text }),
    'Code' : IDL.Record({ 'url' : IDL.Text, 'checksum' : IDL.Text }),
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
    'InvalidArgument' : IDL.Text,
    'Unavailable' : IDL.Text,
    'Forbidden' : IDL.Record({
      'permission' : IDL.Opt(IDL.Text),
      'message' : IDL.Text,
    }),
    'Unauthenticated' : IDL.Null,
    'Conflict' : IDL.Text,
  });
  const ProposalGetArgs = IDL.Record({
    'id' : IDL.Text,
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const Timestamp = IDL.Nat64;
  const VoteChoice = IDL.Variant({
    'No' : IDL.Null,
    'Yes' : IDL.Null,
    'Abstain' : IDL.Null,
  });
  const Vote = IDL.Record({
    'id' : IDL.Text,
    'voter' : IDL.Principal,
    'cast_at' : Timestamp,
    'cast_by' : IDL.Opt(IDL.Principal),
    'proposal' : IDL.Text,
    'choice' : VoteChoice,
  });
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
  const ProposalResult = IDL.Variant({
    'Error' : IDL.Text,
    'Reply' : IDL.Vec(IDL.Nat8),
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
    'result' : IDL.Opt(ProposalResult),
    'tally' : Tally,
    'title' : IDL.Text,
    'action' : ProposalAction,
    'threshold' : IDL.Nat,
    'description' : IDL.Text,
    'deadline' : IDL.Opt(Timestamp),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'proposer' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
    'quorum' : IDL.Nat,
  });
  const ProposalDetail = IDL.Record({
    'votes' : IDL.Vec(Vote),
    'next' : IDL.Opt(IDL.Text),
    'proposal' : Proposal,
  });
  const ProposalListArgs = IDL.Record({
    'status' : IDL.Opt(ProposalStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const ProposalPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Proposal),
  });
  const ProposalVoteArgs = IDL.Record({
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'proposal' : IDL.Text,
    'choice' : VoteChoice,
  });
  const RealmStatus = IDL.Variant({
    'Setup' : IDL.Null,
    'Terminated' : IDL.Null,
    'Production' : IDL.Null,
    'Beta' : IDL.Null,
    'Alpha' : IDL.Null,
    'Deprecation' : IDL.Null,
  });
  const Realm = IDL.Record({
    'id' : IDL.Text,
    'status' : RealmStatus,
    'require_marketplace_approval' : IDL.Bool,
    'is_quarter' : IDL.Bool,
    'name' : IDL.Text,
    'manifesto' : IDL.Text,
    'network' : IDL.Text,
    'federation_codex' : IDL.Opt(IDL.Text),
    'quarter_join_mode' : IDL.Opt(IDL.Text),
    'is_capital' : IDL.Bool,
    'calendar' : IDL.Opt(IDL.Text),
    'logo_url' : IDL.Opt(IDL.Text),
    'open_registration' : IDL.Bool,
    'trusted_principals' : IDL.Vec(IDL.Principal),
    'federation_realm_id' : IDL.Opt(IDL.Text),
    'accounting_currency_decimals' : IDL.Opt(IDL.Nat8),
    'welcome_message' : IDL.Text,
    'trusted_approvers' : IDL.Vec(IDL.Text),
    'background_image_url' : IDL.Opt(IDL.Text),
    'installed_version' : IDL.Text,
    'treasury' : IDL.Opt(IDL.Text),
    'accounting_currency' : IDL.Opt(IDL.Text),
  });
  const MemberStatus = IDL.Variant({
    'Inactive' : IDL.Null,
    'Active' : IDL.Null,
    'Suspended' : IDL.Null,
    'Banned' : IDL.Null,
  });
  const Member = IDL.Record({
    'id' : IDL.Text,
    'status' : MemberStatus,
    'user' : IDL.Principal,
    'joined_at' : IDL.Opt(Timestamp),
  });
  const User = IDL.Record({
    'id' : IDL.Principal,
    'private_data' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'nickname' : IDL.Opt(IDL.Text),
    'home_quarter' : IDL.Opt(IDL.Text),
    'profiles' : IDL.Vec(IDL.Text),
    'avatar' : IDL.Opt(IDL.Text),
  });
  const UserEntry = IDL.Record({ 'member' : IDL.Opt(Member), 'user' : User });
  const ListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const UserPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(UserEntry),
  });
  return IDL.Service({
    'ggg_proposal_create' : IDL.Func(
        [ProposalCreateArgs],
        [IDL.Variant({ 'Ok' : IDL.Text, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_get' : IDL.Func(
        [ProposalGetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(ProposalDetail), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_proposal_list' : IDL.Func(
        [ProposalListArgs],
        [IDL.Variant({ 'Ok' : ProposalPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_proposal_vote' : IDL.Func(
        [ProposalVoteArgs],
        [IDL.Variant({ 'Ok' : Vote, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_info' : IDL.Func([], [Realm], ['query']),
    'ggg_user_get' : IDL.Func(
        [IDL.Principal],
        [IDL.Variant({ 'Ok' : IDL.Opt(UserEntry), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_user_list' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : UserPage, 'Err' : GggError })],
        ['query'],
      ),
    'icrc10_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text }))],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
