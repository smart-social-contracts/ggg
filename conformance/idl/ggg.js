export const idlFactory = ({ IDL }) => {
  const Value = IDL.Rec();
  const Allocation = IDL.Record({ 'fund' : IDL.Text, 'share' : IDL.Nat });
  const AllocationRuleDraftArgs = IDL.Record({
    'source_fund' : IDL.Text,
    'rules' : IDL.Vec(Allocation),
  });
  const Governed = IDL.Variant({
    'Done' : IDL.Opt(IDL.Text),
    'Proposed' : IDL.Text,
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
  const PenaltyKind = IDL.Variant({
    'CommunityService' : IDL.Null,
    'Fine' : IDL.Null,
    'Injunction' : IDL.Null,
    'Termination' : IDL.Null,
    'Suspension' : IDL.Null,
    'Freeze' : IDL.Null,
    'Restitution' : IDL.Null,
    'Revocation' : IDL.Null,
  });
  const Ref = IDL.Record({ 'id' : IDL.Text, 'kind' : IDL.Text });
  const Timestamp = IDL.Nat64;
  const PenaltyTerms = IDL.Record({
    'kind' : PenaltyKind,
    'target' : Ref,
    'due_at' : IDL.Opt(Timestamp),
    'amount' : IDL.Opt(IDL.Nat),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const AppealDecideArgs = IDL.Record({
    'decision' : IDL.Opt(IDL.Text),
    'granted' : IDL.Bool,
    'appeal' : IDL.Text,
    'reasoning_ref' : IDL.Opt(IDL.Text),
    'penalties' : IDL.Vec(PenaltyTerms),
  });
  const AppealStatus = IDL.Variant({
    'UnderReview' : IDL.Null,
    'Granted' : IDL.Null,
    'Withdrawn' : IDL.Null,
    'Filed' : IDL.Null,
    'Denied' : IDL.Null,
  });
  const Appeal = IDL.Record({
    'id' : IDL.Text,
    'status' : AppealStatus,
    'decision' : IDL.Opt(IDL.Text),
    'case' : IDL.Text,
    'court' : IDL.Text,
    'grounds_ref' : IDL.Opt(IDL.Text),
    'verdict' : IDL.Text,
    'new_verdict' : IDL.Opt(IDL.Text),
    'appellant' : IDL.Principal,
  });
  const AppealFileArgs = IDL.Record({
    'court' : IDL.Opt(IDL.Text),
    'grounds_ref' : IDL.Opt(IDL.Text),
    'verdict' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const AppointArgs = IDL.Record({
    'supervisor' : IDL.Opt(IDL.Principal),
    'agent' : IDL.Bool,
    'user' : IDL.Principal,
    'position' : IDL.Text,
  });
  const AuthorityGrantArgs = IDL.Record({
    'target' : Ref,
    'operations' : IDL.Vec(IDL.Text),
    'department' : IDL.Text,
  });
  const BidScoreArgs = IDL.Record({
    'bid' : IDL.Text,
    'scores' : IDL.Vec(
      IDL.Record({ 'score' : IDL.Nat, 'criterion' : IDL.Text })
    ),
  });
  const Bid = IDL.Record({
    'id' : IDL.Text,
    'sealed' : IDL.Bool,
    'score' : IDL.Opt(IDL.Nat),
    'vendor' : IDL.Text,
    'payload_ref' : IDL.Text,
    'price' : IDL.Opt(IDL.Nat),
    'tender' : IDL.Text,
    'submitted_at' : Timestamp,
    'payload_hash' : IDL.Text,
  });
  const BidSubmitArgs = IDL.Record({
    'vendor' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'payload_ref' : IDL.Text,
    'tender' : IDL.Text,
    'payload_hash' : IDL.Text,
  });
  const BidWithdrawArgs = IDL.Record({
    'bid' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const BidOpening = IDL.Record({
    'bid' : IDL.Text,
    'nonce' : IDL.Text,
    'price' : IDL.Nat,
  });
  const BidsRevealArgs = IDL.Record({
    'tender' : IDL.Text,
    'openings' : IDL.Vec(BidOpening),
  });
  const BudgetAmendArgs = IDL.Record({
    'planned' : IDL.Nat,
    'budget' : IDL.Text,
  });
  const BudgetDraftArgs = IDL.Record({
    'period' : IDL.Text,
    'fund' : IDL.Text,
    'kind' : IDL.Opt(IDL.Text),
    'planned' : IDL.Nat,
    'category' : IDL.Text,
  });
  const CaseAssignArgs = IDL.Record({ 'case' : IDL.Text, 'judge' : IDL.Text });
  const CaseStatus = IDL.Variant({
    'VerdictIssued' : IDL.Null,
    'Closed' : IDL.Null,
    'Transferred' : IDL.Null,
    'Dismissed' : IDL.Null,
    'Filed' : IDL.Null,
    'InProgress' : IDL.Null,
    'Appealed' : IDL.Null,
    'Assigned' : IDL.Null,
  });
  const Sealed = IDL.Record({ 'ref' : IDL.Text, 'hash' : IDL.Text });
  const Case = IDL.Record({
    'id' : IDL.Text,
    'judges' : IDL.Vec(IDL.Text),
    'status' : CaseStatus,
    'title' : IDL.Text,
    'closed_at' : IDL.Opt(Timestamp),
    'court' : IDL.Text,
    'filed_at' : Timestamp,
    'defendant' : Ref,
    'evidence' : IDL.Vec(Sealed),
    'dispute' : IDL.Opt(IDL.Text),
    'plaintiff' : Ref,
  });
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
  const CodexSource = IDL.Variant({
    'Package' : IDL.Record({ 'source' : IDL.Text, 'manifest' : Value }),
    'Registry' : IDL.Record({ 'codex' : IDL.Text, 'version' : IDL.Text }),
  });
  const ListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const SigningPolicy = IDL.Record({
    'supervision' : IDL.Variant({
      'Required' : IDL.Null,
      'Optional' : IDL.Null,
    }),
    'agents' : IDL.Vec(IDL.Text),
    'delegable' : IDL.Vec(IDL.Text),
  });
  const CodexView = IDL.Record({
    'signing' : SigningPolicy,
    'next' : IDL.Opt(IDL.Text),
    'history' : IDL.Vec(IDL.Text),
    'healthy' : IDL.Bool,
    'checksum' : IDL.Opt(IDL.Text),
  });
  const ContractCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'mandate' : IDL.Opt(IDL.Text),
    'starts_at' : IDL.Opt(Timestamp),
    'value' : IDL.Nat,
    'ends_at' : IDL.Opt(Timestamp),
    'terms_hash' : IDL.Text,
    'terms_ref' : IDL.Text,
    'parties' : IDL.Vec(Ref),
    'symbol' : IDL.Text,
  });
  const ContractStatus = IDL.Variant({
    'Disputed' : IDL.Null,
    'Terminated' : IDL.Null,
    'Active' : IDL.Null,
    'Draft' : IDL.Null,
    'Fulfilled' : IDL.Null,
  });
  const Contract = IDL.Record({
    'id' : IDL.Text,
    'status' : ContractStatus,
    'title' : IDL.Text,
    'mandate' : IDL.Opt(IDL.Text),
    'starts_at' : IDL.Opt(Timestamp),
    'value' : IDL.Nat,
    'ends_at' : IDL.Opt(Timestamp),
    'terms_hash' : IDL.Text,
    'terms_ref' : IDL.Text,
    'parties' : IDL.Vec(Ref),
    'symbol' : IDL.Text,
  });
  const CourtLevel = IDL.Variant({
    'Supreme' : IDL.Null,
    'Specialized' : IDL.Null,
    'FirstInstance' : IDL.Null,
    'Appellate' : IDL.Null,
  });
  const CourtCreateArgs = IDL.Record({
    'operator' : Ref,
    'name' : IDL.Text,
    'level' : IDL.Opt(CourtLevel),
    'jurisdiction' : IDL.Opt(IDL.Text),
    'parent' : IDL.Opt(IDL.Text),
  });
  const CredentialIssueArgs = IDL.Record({
    'prepared_by' : IDL.Opt(IDL.Principal),
    'subject' : IDL.Opt(IDL.Text),
    'schema' : IDL.Text,
    'fields' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
    'payload_ref' : IDL.Opt(IDL.Text),
    'organization' : IDL.Text,
    'holder' : IDL.Principal,
    'expires_at' : IDL.Opt(Timestamp),
    'payload_hash' : IDL.Opt(IDL.Text),
  });
  const CredentialIssued = IDL.Record({
    'token_id' : IDL.Nat,
    'header' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
  });
  const CredentialRevokeArgs = IDL.Record({
    'token_id' : IDL.Nat,
    'schema' : IDL.Text,
    'organization' : IDL.Text,
    'reason' : IDL.Text,
  });
  const CredentialVerifyArgs = IDL.Record({
    'frozen' : IDL.Bool,
    'header' : IDL.Vec(IDL.Tuple(IDL.Text, IDL.Text)),
  });
  const CredentialCheck = IDL.Record({
    'revoked' : IDL.Bool,
    'expired' : IDL.Bool,
    'valid' : IDL.Bool,
    'licensed' : IDL.Bool,
    'ours' : IDL.Bool,
  });
  const AccessArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'scope' : IDL.Text,
  });
  const PrincipalPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(IDL.Principal),
  });
  const KeyEnvelope = IDL.Record({
    'at' : Timestamp,
    'id' : IDL.Text,
    'principal' : IDL.Principal,
    'scope' : IDL.Text,
    'granted_by' : IDL.Principal,
    'wrapped_dek' : IDL.Vec(IDL.Nat8),
  });
  const WrappedKey = IDL.Record({
    'principal' : IDL.Principal,
    'wrapped_dek' : IDL.Vec(IDL.Nat8),
  });
  const KeyGrantArgs = IDL.Record({
    'keys' : IDL.Vec(WrappedKey),
    'scope' : IDL.Text,
  });
  const KeyRevokeArgs = IDL.Record({
    'scope' : IDL.Text,
    'principals' : IDL.Vec(IDL.Principal),
  });
  const ScopePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(IDL.Text),
  });
  const DelegableOperation = IDL.Record({
    'permission' : IDL.Text,
    'operation' : IDL.Text,
  });
  const DelegationStatus = IDL.Variant({
    'Active' : IDL.Null,
    'Declined' : IDL.Null,
    'Revoked' : IDL.Null,
    'Expired' : IDL.Null,
    'Pending' : IDL.Null,
  });
  const Delegation = IDL.Record({
    'id' : IDL.Text,
    'status' : DelegationStatus,
    'starts_at' : IDL.Opt(Timestamp),
    'accepted_at' : IDL.Opt(Timestamp),
    'delegate' : IDL.Principal,
    'description' : IDL.Text,
    'label' : IDL.Text,
    'revoked_at' : IDL.Opt(Timestamp),
    'revoked_by' : IDL.Opt(IDL.Principal),
    'grantor' : IDL.Principal,
    'scope' : IDL.Vec(IDL.Text),
    'granted_by' : IDL.Principal,
    'requires_acceptance' : IDL.Bool,
    'expires_at' : Timestamp,
  });
  const DelegationGrantArgs = IDL.Record({
    'starts_at' : IDL.Opt(Timestamp),
    'delegate' : IDL.Principal,
    'description' : IDL.Text,
    'label' : IDL.Text,
    'scope' : IDL.Vec(IDL.Text),
    'expires_at' : Timestamp,
  });
  const DelegationListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'role' : IDL.Variant({ 'Delegate' : IDL.Null, 'Grantor' : IDL.Null }),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const DelegationRequest = IDL.Record({
    'id' : IDL.Text,
    'starts_at' : IDL.Opt(Timestamp),
    'delegate' : IDL.Principal,
    'description' : IDL.Text,
    'label' : IDL.Text,
    'grantor' : IDL.Principal,
    'scope' : IDL.Vec(IDL.Text),
    'request_expires_at' : Timestamp,
    'expires_at' : Timestamp,
  });
  const DelegationPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'requests' : IDL.Vec(DelegationRequest),
    'items' : IDL.Vec(Delegation),
  });
  const DelegationRequestArgs = IDL.Record({
    'starts_at' : IDL.Opt(Timestamp),
    'description' : IDL.Text,
    'label' : IDL.Text,
    'grantor' : IDL.Principal,
    'scope' : IDL.Vec(IDL.Text),
    'expires_at' : Timestamp,
  });
  const DelegationDecideArgs = IDL.Record({
    'request' : IDL.Text,
    'approve' : IDL.Bool,
    'scope' : IDL.Opt(IDL.Vec(IDL.Text)),
    'expires_at' : IDL.Opt(Timestamp),
  });
  const ChartArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'department' : IDL.Opt(IDL.Text),
  });
  const Policy = IDL.Record({
    'm' : IDL.Nat,
    'n' : IDL.Nat,
    'veto' : IDL.Vec(IDL.Principal),
    'quorum' : IDL.Nat,
  });
  const Department = IDL.Record({
    'id' : IDL.Text,
    'is_root' : IDL.Bool,
    'fund' : IDL.Opt(IDL.Text),
    'head' : IDL.Opt(IDL.Principal),
    'description' : IDL.Text,
    'target_policy' : IDL.Opt(Policy),
    'parent' : IDL.Opt(IDL.Text),
    'policy' : Policy,
  });
  const Chart = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'children' : IDL.Vec(Department),
    'seats' : IDL.Nat,
    'filled' : IDL.Nat,
    'department' : Department,
    'positions' : IDL.Nat,
  });
  const DepartmentCreateArgs = IDL.Record({
    'description' : IDL.Text,
    'department' : IDL.Text,
    'parent' : IDL.Opt(IDL.Text),
  });
  const DepartmentEditArgs = IDL.Record({
    'head' : IDL.Opt(
      IDL.Variant({ 'Set' : IDL.Principal, 'Clear' : IDL.Null })
    ),
    'description' : IDL.Opt(IDL.Text),
    'department' : IDL.Text,
    'parent' : IDL.Opt(IDL.Text),
  });
  const ExpelArgs = IDL.Record({
    'user' : IDL.Principal,
    'department' : IDL.Text,
  });
  const GetArgs = IDL.Record({
    'id' : IDL.Text,
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const AppointmentStatus = IDL.Variant({
    'Ended' : IDL.Null,
    'Active' : IDL.Null,
  });
  const AppointmentKind = IDL.Variant({
    'Acting' : IDL.Null,
    'Substantive' : IDL.Null,
  });
  const Appointment = IDL.Record({
    'id' : IDL.Text,
    'supervisor' : IDL.Opt(IDL.Principal),
    'status' : AppointmentStatus,
    'agent' : IDL.Bool,
    'source_quarter' : IDL.Opt(IDL.Text),
    'kind' : AppointmentKind,
    'user' : IDL.Principal,
    'position' : IDL.Text,
    'ended_at' : IDL.Opt(Timestamp),
    'started_at' : Timestamp,
  });
  const PositionStatus = IDL.Variant({
    'Open' : IDL.Null,
    'Closed' : IDL.Null,
    'Frozen' : IDL.Null,
  });
  const Duration = IDL.Nat64;
  const Position = IDL.Record({
    'id' : IDL.Text,
    'status' : PositionStatus,
    'title' : IDL.Text,
    'salary_period' : IDL.Opt(Duration),
    'salary' : IDL.Nat,
    'headcount' : IDL.Nat,
    'organization' : IDL.Opt(IDL.Text),
    'department' : IDL.Opt(IDL.Text),
    'inherit_from_capital' : IDL.Bool,
    'profile' : IDL.Opt(IDL.Text),
  });
  const Seat = IDL.Record({
    'holders' : IDL.Vec(Appointment),
    'position' : Position,
  });
  const DepartmentDetail = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'seats' : IDL.Vec(Seat),
    'department' : Department,
  });
  const DepartmentPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Department),
  });
  const DepartmentPolicyArgs = IDL.Record({
    'department' : IDL.Text,
    'policy' : Policy,
  });
  const DisputeAcceptArgs = IDL.Record({
    'court' : IDL.Text,
    'dispute' : IDL.Text,
  });
  const DisputeFileArgs = IDL.Record({
    'title' : IDL.Text,
    'subject' : IDL.Opt(Ref),
    'description_ref' : IDL.Opt(IDL.Text),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'respondent' : Ref,
  });
  const DisputeStatus = IDL.Variant({
    'Withdrawn' : IDL.Null,
    'Rejected' : IDL.Null,
    'Filed' : IDL.Null,
    'Accepted' : IDL.Null,
  });
  const Dispute = IDL.Record({
    'id' : IDL.Text,
    'status' : DisputeStatus,
    'title' : IDL.Text,
    'subject' : IDL.Opt(Ref),
    'claimant' : IDL.Principal,
    'description_ref' : IDL.Opt(IDL.Text),
    'case' : IDL.Opt(IDL.Text),
    'respondent' : Ref,
  });
  const DisputeGetArgs = IDL.Record({
    'id' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const DisputeListArgs = IDL.Record({
    'status' : IDL.Opt(DisputeStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const DisputePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Dispute),
  });
  const DisputeWithdrawArgs = IDL.Record({
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'dispute' : IDL.Text,
  });
  const DocumentDeleteArgs = IDL.Record({
    'limit' : IDL.Opt(IDL.Nat32),
    'document' : IDL.Text,
  });
  const DocumentDeleted = IDL.Record({
    'deleted' : IDL.Bool,
    'revoked' : IDL.Nat,
  });
  const Document = IDL.Record({
    'at' : Timestamp,
    'id' : IDL.Text,
    'ref' : IDL.Text,
    'title' : IDL.Text,
    'hash' : IDL.Text,
    'author' : IDL.Principal,
    'department' : IDL.Text,
  });
  const DocumentAccess = IDL.Record({
    'envelope' : IDL.Opt(KeyEnvelope),
    'scope' : IDL.Text,
    'document' : Document,
  });
  const DocumentListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'department' : IDL.Text,
  });
  const DocumentPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Document),
  });
  const DocumentRevokeArgs = IDL.Record({
    'document' : IDL.Text,
    'principals' : IDL.Vec(IDL.Principal),
  });
  const DocumentShareArgs = IDL.Record({
    'keys' : IDL.Vec(WrappedKey),
    'document' : IDL.Text,
  });
  const DocumentStoreArgs = IDL.Record({
    'ref' : IDL.Text,
    'title' : IDL.Text,
    'hash' : IDL.Text,
    'keys' : IDL.Vec(WrappedKey),
    'document' : IDL.Opt(IDL.Text),
    'department' : IDL.Text,
  });
  const DocumentStored = IDL.Record({
    'scope' : IDL.Text,
    'document' : Document,
  });
  const EnforcementArgs = IDL.Record({
    'note' : IDL.Text,
    'verdict' : IDL.Text,
  });
  const Notification = IDL.Record({
    'at' : Timestamp,
    'id' : IDL.Text,
    'read_by' : IDL.Vec(IDL.Principal),
    'title' : IDL.Text,
    'topic' : IDL.Text,
    'body' : IDL.Text,
    'href' : IDL.Opt(IDL.Text),
    'recipient' : Ref,
    'sender' : IDL.Opt(IDL.Text),
    'visibility' : IDL.Text,
  });
  const EnforcementNotifyArgs = IDL.Record({
    'to' : Ref,
    'title' : IDL.Opt(IDL.Text),
    'body' : IDL.Opt(IDL.Text),
    'verdict' : IDL.Text,
  });
  const Event = IDL.Record({
    'at' : Timestamp,
    'by' : IDL.Opt(IDL.Principal),
    'id' : IDL.Text,
    'op' : IDL.Text,
    'supervisor' : IDL.Opt(IDL.Principal),
    'result' : Value,
    'agent' : IDL.Bool,
    'args' : Value,
    'origin' : IDL.Text,
    'user' : IDL.Opt(IDL.Principal),
  });
  const EventArchive = IDL.Record({
    'first' : IDL.Text,
    'last' : IDL.Text,
    'canister' : IDL.Principal,
  });
  const EventPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Event),
    'archives' : IDL.Vec(EventArchive),
  });
  const EvidenceEvaluateArgs = IDL.Record({
    'admitted' : IDL.Bool,
    'case' : IDL.Text,
    'evidence' : IDL.Text,
  });
  const EvidenceSubmitArgs = IDL.Record({
    'ref' : IDL.Text,
    'case' : IDL.Text,
    'hash' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const FederalVoteStatus = IDL.Variant({
    'Failed' : IDL.Null,
    'Passed' : IDL.Null,
    'Open' : IDL.Null,
    'Cancelled' : IDL.Null,
  });
  const ProposalAction = IDL.Variant({
    'Call' : IDL.Record({ 'arg' : IDL.Vec(IDL.Nat8), 'method' : IDL.Text }),
    'Code' : IDL.Record({ 'url' : IDL.Text, 'checksum' : IDL.Text }),
    'Motion' : IDL.Null,
  });
  const FederalVote = IDL.Record({
    'id' : IDL.Text,
    'status' : FederalVoteStatus,
    'tally' : Value,
    'title' : IDL.Text,
    'action' : ProposalAction,
    'hash' : IDL.Text,
    'rule' : Value,
    'origin_quarter' : IDL.Text,
    'deadline' : Timestamp,
  });
  const FederalVoteProposeArgs = IDL.Record({
    'title' : IDL.Text,
    'action' : ProposalAction,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const FederationMessageArgs = IDL.Record({
    'to' : IDL.Opt(IDL.Text),
    'topic' : IDL.Text,
    'body' : Value,
  });
  const FundCreateArgs = IDL.Record({
    'fund' : IDL.Text,
    'kind' : IDL.Opt(IDL.Text),
    'name' : IDL.Opt(IDL.Text),
    'department' : IDL.Opt(IDL.Text),
  });
  const GovernanceUpdateArgs = IDL.Record({
    'voting_window' : IDL.Opt(Duration),
    'voting_quorum' : IDL.Opt(IDL.Nat),
    'voting_threshold' : IDL.Opt(IDL.Nat),
  });
  const IdentityReviewArgs = IDL.Record({
    'status' : IDL.Variant({ 'Rejected' : IDL.Null, 'Verified' : IDL.Null }),
    'identity' : IDL.Text,
  });
  const IdentityStatus = IDL.Variant({
    'Rejected' : IDL.Null,
    'Verified' : IDL.Null,
    'Pending' : IDL.Null,
  });
  const Identity = IDL.Record({
    'id' : IDL.Text,
    'ref' : IDL.Text,
    'status' : IdentityStatus,
    'human' : IDL.Text,
    'kind' : IDL.Text,
    'issuer' : IDL.Text,
    'verified_at' : IDL.Opt(Timestamp),
  });
  const IdentitySubmitArgs = IDL.Record({
    'ref' : IDL.Text,
    'kind' : IDL.Text,
    'issuer' : IDL.Opt(IDL.Text),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const InviteCreateArgs = IDL.Record({
    'max_uses' : IDL.Opt(IDL.Nat),
    'code' : IDL.Opt(IDL.Text),
    'department' : IDL.Opt(IDL.Text),
    'position' : IDL.Opt(IDL.Text),
    'expires_at' : IDL.Opt(Timestamp),
    'profile' : IDL.Opt(IDL.Text),
  });
  const Invite = IDL.Record({
    'id' : IDL.Text,
    'max_uses' : IDL.Nat,
    'revoked' : IDL.Bool,
    'uses' : IDL.Nat,
    'created_by' : IDL.Principal,
    'redeemed_by' : IDL.Vec(IDL.Principal),
    'department' : IDL.Opt(IDL.Text),
    'position' : IDL.Opt(IDL.Text),
    'expires_at' : IDL.Opt(Timestamp),
    'profile' : IDL.Opt(IDL.Text),
  });
  const InviteCreated = IDL.Record({ 'code' : IDL.Text, 'invite' : Invite });
  const InvitePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Invite),
  });
  const InvoiceCheckArgs = IDL.Record({
    'invoice' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const InvoiceStatus = IDL.Variant({
    'Paid' : IDL.Null,
    'Overdue' : IDL.Null,
    'Cancelled' : IDL.Null,
    'Pending' : IDL.Null,
  });
  const Invoice = IDL.Record({
    'id' : IDL.Text,
    'status' : InvoiceStatus,
    'due_at' : IDL.Opt(Timestamp),
    'paid_at' : IDL.Opt(Timestamp),
    'payer' : Ref,
    'amount' : IDL.Nat,
    'payment' : IDL.Opt(Value),
    'symbol' : IDL.Text,
    'reason' : IDL.Opt(Ref),
  });
  const InvoiceCreateArgs = IDL.Record({
    'due_at' : IDL.Opt(Timestamp),
    'payer' : Ref,
    'amount' : IDL.Nat,
    'symbol' : IDL.Opt(IDL.Text),
    'reason' : IDL.Opt(Ref),
  });
  const Account = IDL.Record({
    'owner' : IDL.Principal,
    'subaccount' : IDL.Opt(IDL.Vec(IDL.Nat8)),
  });
  const InvoiceCreated = IDL.Record({
    'invoice' : Invoice,
    'pay_to' : Account,
  });
  const InvoiceRefreshArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'invoice' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const InvoicePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Invoice),
  });
  const JudgeAppointArgs = IDL.Record({
    'court' : IDL.Text,
    'user' : IDL.Principal,
    'specialization' : IDL.Opt(IDL.Text),
  });
  const LandFreezeArgs = IDL.Record({
    'land' : IDL.Text,
    'reason' : IDL.Opt(IDL.Text),
  });
  const LandStatus = IDL.Variant({
    'Disputed' : IDL.Null,
    'Active' : IDL.Null,
    'Revoked' : IDL.Null,
  });
  const Land = IDL.Record({
    'x' : IDL.Nat,
    'y' : IDL.Nat,
    'id' : IDL.Text,
    'height' : IDL.Nat,
    'status' : LandStatus,
    'token_id' : IDL.Opt(IDL.Nat),
    'owner' : Ref,
    'metadata' : Value,
    'kind' : IDL.Text,
    'width' : IDL.Nat,
    'registered_by' : IDL.Principal,
  });
  const LandListArgs = IDL.Record({
    'owner' : IDL.Opt(Ref),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const LandPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Land),
  });
  const LandMapArgs = IDL.Record({
    'h' : IDL.Nat,
    'w' : IDL.Nat,
    'x' : IDL.Nat,
    'y' : IDL.Nat,
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const Zone = IDL.Record({
    'id' : IDL.Text,
    'metadata' : Value,
    'kind' : IDL.Text,
    'land' : IDL.Opt(IDL.Text),
    'name' : IDL.Text,
    'user' : IDL.Opt(IDL.Principal),
  });
  const LandMap = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'zones' : IDL.Vec(Zone),
    'parcels' : IDL.Vec(Land),
  });
  const LandMintArgs = IDL.Record({
    'prepared_by' : IDL.Opt(IDL.Principal),
    'land' : IDL.Text,
  });
  const LandRegisterArgs = IDL.Record({
    'x' : IDL.Nat,
    'y' : IDL.Nat,
    'height' : IDL.Opt(IDL.Nat),
    'owner' : Ref,
    'metadata' : IDL.Opt(Value),
    'kind' : IDL.Opt(IDL.Text),
    'width' : IDL.Opt(IDL.Nat),
  });
  const LandTransferArgs = IDL.Record({
    'to' : Ref,
    'order' : IDL.Text,
    'land' : IDL.Text,
  });
  const LedgerKind = IDL.Variant({
    'Asset' : IDL.Null,
    'Liability' : IDL.Null,
    'Revenue' : IDL.Null,
    'Expense' : IDL.Null,
    'Equity' : IDL.Null,
  });
  const LedgerArgs = IDL.Record({
    'period' : IDL.Opt(IDL.Text),
    'cursor' : IDL.Opt(IDL.Text),
    'fund' : IDL.Opt(IDL.Text),
    'kind' : IDL.Opt(LedgerKind),
    'transaction' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const LedgerEntry = IDL.Record({
    'at' : Timestamp,
    'id' : IDL.Text,
    'penalty' : IDL.Opt(IDL.Text),
    'contract' : IDL.Opt(IDL.Text),
    'period' : IDL.Opt(IDL.Text),
    'case' : IDL.Opt(IDL.Text),
    'fund' : IDL.Opt(IDL.Text),
    'invoice' : IDL.Opt(IDL.Text),
    'kind' : LedgerKind,
    'transaction' : IDL.Text,
    'user' : IDL.Opt(IDL.Principal),
    'description' : IDL.Text,
    'credit' : IDL.Nat,
    'appeal' : IDL.Opt(IDL.Text),
    'category' : IDL.Text,
    'organization' : IDL.Opt(IDL.Text),
    'debit' : IDL.Nat,
    'transfer' : IDL.Opt(IDL.Text),
    'symbol' : IDL.Text,
  });
  const LedgerPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(LedgerEntry),
  });
  const LicenseApplyArgs = IDL.Record({
    'evidence_ref' : IDL.Opt(IDL.Text),
    'kind' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'conditions' : IDL.Opt(Value),
    'department' : IDL.Opt(IDL.Text),
    'holder' : IDL.Opt(Ref),
  });
  const LicenseStatus = IDL.Variant({
    'Applied' : IDL.Null,
    'Active' : IDL.Null,
    'Suspended' : IDL.Null,
    'Rejected' : IDL.Null,
    'Revoked' : IDL.Null,
    'Expired' : IDL.Null,
  });
  const License = IDL.Record({
    'id' : IDL.Text,
    'status' : LicenseStatus,
    'evidence_ref' : IDL.Opt(IDL.Text),
    'issued_at' : IDL.Opt(Timestamp),
    'issued_by' : IDL.Text,
    'applied_at' : Timestamp,
    'kind' : IDL.Text,
    'conditions' : Value,
    'holder' : Ref,
    'expires_at' : IDL.Opt(Timestamp),
  });
  const LicenseDecideArgs = IDL.Record({
    'approve' : IDL.Bool,
    'conditions' : IDL.Opt(Value),
    'department' : IDL.Opt(IDL.Text),
    'license' : IDL.Text,
    'expires_at' : IDL.Opt(Timestamp),
  });
  const LicenseListArgs = IDL.Record({
    'status' : IDL.Opt(LicenseStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'kind' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'holder' : IDL.Opt(Ref),
  });
  const LicensePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(License),
  });
  const LicenseRenewArgs = IDL.Record({
    'evidence_ref' : IDL.Opt(IDL.Text),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'license' : IDL.Text,
  });
  const LicenseSuspendArgs = IDL.Record({
    'resume' : IDL.Bool,
    'license' : IDL.Text,
  });
  const LicenseVerifyArgs = IDL.Record({
    'id' : IDL.Opt(IDL.Text),
    'kind' : IDL.Opt(IDL.Text),
    'holder' : IDL.Opt(Ref),
  });
  const LicenseCheck = IDL.Record({
    'valid' : IDL.Bool,
    'license' : IDL.Opt(License),
  });
  const MandateExecutorArgs = IDL.Record({
    'mandate' : IDL.Text,
    'executor' : IDL.Text,
  });
  const MandateCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'max_value' : IDL.Opt(IDL.Nat),
    'scope' : Value,
    'executor' : IDL.Opt(IDL.Text),
    'expires_at' : IDL.Opt(Timestamp),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const MandateRevokeArgs = IDL.Record({ 'mandate' : IDL.Text });
  const NFTTokenRegisterArgs = IDL.Record({
    'supply_cap' : IDL.Opt(IDL.Nat),
    'transferable' : IDL.Opt(IDL.Bool),
    'name' : IDL.Opt(IDL.Text),
    'description' : IDL.Opt(IDL.Text),
    'canister' : IDL.Principal,
    'required_license' : IDL.Opt(IDL.Text),
    'symbol' : IDL.Text,
  });
  const NotificationListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'recipient' : IDL.Opt(Ref),
    'unread' : IDL.Opt(IDL.Bool),
    'limit' : IDL.Opt(IDL.Nat32),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const NotificationPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Notification),
  });
  const NotificationReadArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'recipient' : IDL.Opt(Ref),
    'notification' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const NotificationsRead = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'read' : IDL.Nat,
  });
  const NotificationSendArgs = IDL.Record({
    'title' : IDL.Text,
    'topic' : IDL.Opt(IDL.Text),
    'body' : IDL.Opt(IDL.Text),
    'href' : IDL.Opt(IDL.Text),
    'recipient' : Ref,
  });
  const OrganizationEditArgs = IDL.Record({
    'description' : IDL.Opt(IDL.Text),
    'admins' : IDL.Opt(IDL.Vec(IDL.Principal)),
    'organization' : IDL.Text,
  });
  const OrganizationStatus = IDL.Variant({
    'Active' : IDL.Null,
    'Dissolved' : IDL.Null,
    'Suspended' : IDL.Null,
  });
  const Organization = IDL.Record({
    'id' : IDL.Text,
    'status' : OrganizationStatus,
    'description' : IDL.Text,
    'admins' : IDL.Vec(IDL.Principal),
  });
  const OrganizationDetail = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'seats' : IDL.Vec(Seat),
    'organization' : Organization,
  });
  const OrganizationListArgs = IDL.Record({
    'status' : IDL.Opt(OrganizationStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const OrganizationPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Organization),
  });
  const OrganizationRegisterArgs = IDL.Record({
    'description' : IDL.Text,
    'organization' : IDL.Text,
  });
  const OrganizationStatusArgs = IDL.Record({
    'status' : OrganizationStatus,
    'organization' : IDL.Text,
  });
  const PaymentAccountAddArgs = IDL.Record({
    'network' : IDL.Text,
    'label' : IDL.Opt(IDL.Text),
    'address' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'organization' : IDL.Opt(IDL.Text),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const PaymentAccount = IDL.Record({
    'id' : IDL.Text,
    'verified' : IDL.Bool,
    'owner' : Ref,
    'network' : IDL.Text,
    'label' : IDL.Text,
    'address' : IDL.Text,
    'symbol' : IDL.Text,
  });
  const PaymentAccountRemoveArgs = IDL.Record({
    'account' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'organization' : IDL.Opt(IDL.Text),
  });
  const PayrollRunArgs = IDL.Record({
    'period' : IDL.Text,
    'department' : IDL.Text,
    'symbol' : IDL.Opt(IDL.Text),
  });
  const PenaltyExecuteArgs = IDL.Record({
    'penalty' : IDL.Text,
    'due_at' : IDL.Opt(Timestamp),
  });
  const PenaltyStatus = IDL.Variant({
    'Executed' : IDL.Null,
    'Waived' : IDL.Null,
    'Pending' : IDL.Null,
  });
  const Penalty = IDL.Record({
    'id' : IDL.Text,
    'status' : PenaltyStatus,
    'executed_at' : IDL.Opt(Timestamp),
    'invoice' : IDL.Opt(IDL.Text),
    'kind' : PenaltyKind,
    'verdict' : IDL.Text,
    'target' : Ref,
    'due_at' : IDL.Opt(Timestamp),
    'amount' : IDL.Opt(IDL.Nat),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const PeriodOpenArgs = IDL.Record({
    'starts_at' : Timestamp,
    'period' : IDL.Text,
    'ends_at' : Timestamp,
    'name' : IDL.Opt(IDL.Text),
  });
  const PositionCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'salary_period' : IDL.Opt(Duration),
    'salary' : IDL.Opt(IDL.Nat),
    'headcount' : IDL.Opt(IDL.Nat),
    'department' : IDL.Text,
    'position' : IDL.Text,
    'profile' : IDL.Opt(IDL.Text),
  });
  const PositionEditArgs = IDL.Record({
    'status' : IDL.Opt(IDL.Variant({ 'Open' : IDL.Null, 'Frozen' : IDL.Null })),
    'title' : IDL.Opt(IDL.Text),
    'salary_period' : IDL.Opt(Duration),
    'salary' : IDL.Opt(IDL.Nat),
    'headcount' : IDL.Opt(IDL.Nat),
    'position' : IDL.Text,
    'profile' : IDL.Opt(IDL.Text),
  });
  const User = IDL.Record({
    'id' : IDL.Principal,
    'private_data' : IDL.Opt(IDL.Vec(IDL.Nat8)),
    'nickname' : IDL.Opt(IDL.Text),
    'home_quarter' : IDL.Opt(IDL.Text),
    'profiles' : IDL.Vec(IDL.Text),
    'avatar' : IDL.Opt(IDL.Text),
  });
  const ProfileCreateArgs = IDL.Record({
    'allowed_to' : IDL.Vec(IDL.Text),
    'description' : IDL.Text,
    'department' : IDL.Opt(IDL.Text),
    'profile' : IDL.Text,
  });
  const ProfileEditArgs = IDL.Record({
    'allowed_to' : IDL.Opt(IDL.Vec(IDL.Text)),
    'description' : IDL.Opt(IDL.Text),
    'department' : IDL.Opt(IDL.Text),
    'profile' : IDL.Text,
  });
  const ProfileUpdateArgs = IDL.Record({
    'nickname' : IDL.Opt(IDL.Text),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'avatar' : IDL.Opt(IDL.Text),
  });
  const ProposalCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'action' : ProposalAction,
    'description' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'department' : IDL.Opt(IDL.Text),
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
  const ProposalWithdrawArgs = IDL.Record({
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'proposal' : IDL.Text,
  });
  const QuarterStatus = IDL.Variant({
    'Splitting' : IDL.Null,
    'Setup' : IDL.Null,
    'Active' : IDL.Null,
    'Suspended' : IDL.Null,
    'Merging' : IDL.Null,
  });
  const QuarterConfigureArgs = IDL.Record({
    'status' : IDL.Opt(QuarterStatus),
    'quarter' : IDL.Opt(IDL.Text),
    'name' : IDL.Opt(IDL.Text),
    'rule' : IDL.Opt(Value),
    'federation_codex' : IDL.Opt(IDL.Text),
    'quarter_join_mode' : IDL.Opt(IDL.Text),
  });
  const Quarter = IDL.Record({
    'id' : IDL.Text,
    'status' : QuarterStatus,
    'codex_version' : IDL.Opt(IDL.Text),
    'name' : IDL.Text,
    'last_activity_at' : IDL.Opt(Timestamp),
    'codex_id' : IDL.Opt(IDL.Text),
    'last_sync' : IDL.Opt(Timestamp),
    'index' : IDL.Nat,
    'population' : IDL.Nat,
  });
  const QuarterDirectory = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'capital' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Quarter),
  });
  const JoinFederationArgs = IDL.Record({
    'name' : IDL.Opt(IDL.Text),
    'capital' : IDL.Principal,
  });
  const QuarterRegisterArgs = IDL.Record({
    'name' : IDL.Opt(IDL.Text),
    'canister' : IDL.Principal,
  });
  const RealmConfigureArgs = IDL.Record({
    'name' : IDL.Opt(IDL.Text),
    'manifesto' : IDL.Opt(IDL.Text),
    'quarter_join_mode' : IDL.Opt(IDL.Text),
    'open_registration' : IDL.Opt(IDL.Bool),
    'welcome_message' : IDL.Opt(IDL.Text),
  });
  const BrandingArgs = IDL.Record({
    'logo_url' : IDL.Opt(IDL.Text),
    'background_image_url' : IDL.Opt(IDL.Text),
  });
  const TokensArgs = IDL.Record({
    'accounting_currency_decimals' : IDL.Opt(IDL.Nat8),
    'accounting_currency' : IDL.Opt(IDL.Text),
  });
  const TrustPolicyArgs = IDL.Record({
    'require_marketplace_approval' : IDL.Opt(IDL.Bool),
    'trusted_principals' : IDL.Opt(IDL.Vec(IDL.Principal)),
    'trusted_approvers' : IDL.Opt(IDL.Vec(IDL.Text)),
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
    'voting_quorum' : IDL.Nat,
    'background_image_url' : IDL.Opt(IDL.Text),
    'voting_threshold' : IDL.Nat,
    'installed_version' : IDL.Text,
    'treasury' : IDL.Opt(IDL.Text),
    'accounting_currency' : IDL.Opt(IDL.Text),
  });
  const JoinArgs = IDL.Record({
    'nickname' : IDL.Opt(IDL.Text),
    'code' : IDL.Opt(IDL.Text),
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
  const UserEntry = IDL.Record({ 'member' : IDL.Opt(Member), 'user' : User });
  const RealmRegisterArgs = IDL.Record({
    'url' : IDL.Opt(IDL.Text),
    'registry' : IDL.Principal,
    'backend_url' : IDL.Opt(IDL.Text),
  });
  const RealmUpgradeArgs = IDL.Record({
    'version' : IDL.Text,
    'module_hash' : IDL.Vec(IDL.Nat8),
  });
  const ReportIssueArgs = IDL.Record({
    'period' : IDL.Text,
    'kind' : IDL.Opt(IDL.Text),
  });
  const FinancialReport = IDL.Record({
    'id' : IDL.Text,
    'issued_by' : IDL.Principal,
    'as_of' : Timestamp,
    'period' : IDL.Text,
    'supersedes' : IDL.Opt(IDL.Text),
    'kind' : IDL.Text,
    'source_hash' : IDL.Text,
    'statements' : Value,
  });
  const ReportArgs = IDL.Record({
    'id' : IDL.Opt(IDL.Text),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const ReportPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(FinancialReport),
  });
  const RepresentativeAddArgs = IDL.Record({
    'supervisor' : IDL.Opt(IDL.Principal),
    'title' : IDL.Opt(IDL.Text),
    'agent' : IDL.Bool,
    'headcount' : IDL.Opt(IDL.Nat),
    'user' : IDL.Principal,
    'organization' : IDL.Text,
    'position' : IDL.Text,
    'profile' : IDL.Opt(IDL.Text),
  });
  const ResolutionQueryArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'court' : IDL.Opt(IDL.Text),
    'search' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'since' : IDL.Opt(Timestamp),
  });
  const VerdictStatus = IDL.Variant({
    'Draft' : IDL.Null,
    'Final' : IDL.Null,
    'Overturned' : IDL.Null,
    'Issued' : IDL.Null,
  });
  const Verdict = IDL.Record({
    'id' : IDL.Text,
    'status' : VerdictStatus,
    'decision' : IDL.Text,
    'issued_at' : IDL.Opt(Timestamp),
    'issued_by' : IDL.Text,
    'contract' : IDL.Opt(IDL.Text),
    'case' : IDL.Text,
    'reasoning_ref' : IDL.Opt(IDL.Text),
  });
  const Resolution = IDL.Record({
    'verdict' : Verdict,
    'penalties' : IDL.Vec(Penalty),
  });
  const ResolutionPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Resolution),
  });
  const RoleArgs = IDL.Record({
    'user' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
    'profile' : IDL.Text,
  });
  const ChangeQuarterArgs = IDL.Record({
    'quarter' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const Forward = IDL.Record({
    'id' : IDL.Text,
    'destination' : IDL.Text,
    'signature' : IDL.Vec(IDL.Nat8),
    'subject' : Ref,
    'origin' : IDL.Text,
    'moved_at' : Timestamp,
  });
  const SetupState = IDL.Record({
    'status' : RealmStatus,
    'done' : IDL.Vec(IDL.Text),
    'todo' : IDL.Vec(IDL.Text),
    'founder' : IDL.Opt(IDL.Principal),
  });
  const SetupStep = IDL.Variant({
    'TrustPolicy' : TrustPolicyArgs,
    'Realm' : RealmConfigureArgs,
    'Branding' : BrandingArgs,
    'Tokens' : TokensArgs,
  });
  const TaxAssessArgs = IDL.Record({
    'tax' : IDL.Opt(IDL.Text),
    'period' : IDL.Text,
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const TaxAssessPage = IDL.Record({
    'skipped' : IDL.Nat,
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Invoice),
  });
  const TaxDeclareArgs = IDL.Record({
    'period' : IDL.Text,
    'base' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'organization' : IDL.Opt(IDL.Text),
    'amount' : IDL.Nat,
  });
  const TaxDeclarationStatus = IDL.Variant({
    'Disputed' : IDL.Null,
    'Filed' : IDL.Null,
    'Assessed' : IDL.Null,
    'Settled' : IDL.Null,
  });
  const TaxDeclaration = IDL.Record({
    'id' : IDL.Text,
    'status' : TaxDeclarationStatus,
    'period' : IDL.Text,
    'base' : IDL.Text,
    'invoice' : IDL.Opt(IDL.Text),
    'declarant' : Ref,
    'amount' : IDL.Nat,
  });
  const TaxDeclared = IDL.Record({
    'invoice' : IDL.Opt(Invoice),
    'declaration' : TaxDeclaration,
  });
  const TaxPolicyDraftArgs = IDL.Record({
    'description' : IDL.Opt(IDL.Text),
    'document' : Value,
  });
  const TenderAwardArgs = IDL.Record({
    'bid' : IDL.Opt(IDL.Text),
    'justification' : IDL.Opt(IDL.Text),
    'tender' : IDL.Text,
  });
  const Criterion = IDL.Record({ 'weight' : IDL.Nat, 'criterion' : IDL.Text });
  const TenderCreateArgs = IDL.Record({
    'opens_at' : IDL.Opt(Timestamp),
    'title' : IDL.Text,
    'requester' : IDL.Text,
    'closes_at' : IDL.Opt(Timestamp),
    'rubric' : IDL.Vec(Criterion),
    'description' : IDL.Opt(IDL.Text),
  });
  const TenderStatus = IDL.Variant({
    'Open' : IDL.Null,
    'Evaluation' : IDL.Null,
    'Closed' : IDL.Null,
    'Awarded' : IDL.Null,
    'Draft' : IDL.Null,
    'Cancelled' : IDL.Null,
    'Contracted' : IDL.Null,
  });
  const Tender = IDL.Record({
    'id' : IDL.Text,
    'opens_at' : IDL.Opt(Timestamp),
    'status' : TenderStatus,
    'title' : IDL.Text,
    'requester' : IDL.Text,
    'closes_at' : IDL.Opt(Timestamp),
    'rubric' : IDL.Vec(Criterion),
    'contract' : IDL.Opt(IDL.Text),
    'winner' : IDL.Opt(IDL.Text),
    'description' : IDL.Text,
  });
  const TenderDetail = IDL.Record({
    'bids' : IDL.Vec(Bid),
    'next' : IDL.Opt(IDL.Text),
    'tender' : Tender,
  });
  const TenderListArgs = IDL.Record({
    'status' : IDL.Opt(TenderStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const TenderPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Tender),
  });
  const ForceTransferArgs = IDL.Record({
    'to' : IDL.Principal,
    'from' : IDL.Principal,
    'amount' : IDL.Nat,
    'symbol' : IDL.Text,
    'reason' : IDL.Opt(IDL.Text),
  });
  const FreezeArgs = IDL.Record({
    'account' : IDL.Principal,
    'frozen' : IDL.Bool,
    'symbol' : IDL.Text,
    'reason' : IDL.Opt(IDL.Text),
  });
  const TokenRegisterArgs = IDL.Record({
    'fee' : IDL.Opt(IDL.Nat),
    'decimals' : IDL.Opt(IDL.Nat8),
    'ledger' : IDL.Principal,
    'indexer' : IDL.Opt(IDL.Principal),
    'symbol' : IDL.Text,
  });
  const TransferCreateArgs = IDL.Record({
    'to' : Ref,
    'contract' : IDL.Opt(IDL.Text),
    'fund' : IDL.Text,
    'description' : IDL.Opt(IDL.Text),
    'category' : IDL.Opt(IDL.Text),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
    'amount' : IDL.Nat,
    'symbol' : IDL.Opt(IDL.Text),
  });
  const TransferRevertArgs = IDL.Record({
    'transfer' : IDL.Text,
    'reason' : IDL.Opt(IDL.Text),
  });
  const TreasuryConfigureArgs = IDL.Record({
    'auto_allocate' : IDL.Opt(IDL.Bool),
    'epoch' : IDL.Opt(Duration),
    'source_fund' : IDL.Opt(IDL.Text),
    'anchor_month' : IDL.Opt(IDL.Nat8),
  });
  const Balance = IDL.Record({ 'amount' : IDL.Nat, 'symbol' : IDL.Text });
  const Fund = IDL.Record({
    'id' : IDL.Text,
    'allocation_rule' : IDL.Opt(IDL.Text),
    'kind' : IDL.Text,
    'name' : IDL.Text,
    'department' : IDL.Opt(IDL.Text),
    'balances' : IDL.Vec(Balance),
  });
  const Token = IDL.Record({
    'id' : IDL.Text,
    'fee' : IDL.Nat,
    'decimals' : IDL.Nat8,
    'ledger' : IDL.Principal,
    'indexer' : IDL.Opt(IDL.Principal),
  });
  const NFTToken = IDL.Record({
    'id' : IDL.Text,
    'supply_cap' : IDL.Opt(IDL.Nat),
    'transferable' : IDL.Bool,
    'name' : IDL.Text,
    'description' : IDL.Text,
    'canister' : IDL.Principal,
    'required_license' : IDL.Opt(IDL.Text),
    'total_supply' : IDL.Nat,
  });
  const TreasuryConfig = IDL.Record({
    'auto_allocate' : IDL.Bool,
    'epoch' : Duration,
    'source_fund' : IDL.Text,
    'anchor_month' : IDL.Nat8,
  });
  const Treasury = IDL.Record({ 'id' : IDL.Text, 'config' : TreasuryConfig });
  const TreasuryView = IDL.Record({
    'funds' : IDL.Vec(Fund),
    'next' : IDL.Opt(IDL.Text),
    'tokens' : IDL.Vec(Token),
    'nft_tokens' : IDL.Vec(NFTToken),
    'treasury' : IDL.Opt(Treasury),
  });
  const UserAddArgs = IDL.Record({
    'nickname' : IDL.Opt(IDL.Text),
    'user' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
  });
  const UserEditArgs = IDL.Record({
    'nickname' : IDL.Opt(IDL.Text),
    'home_quarter' : IDL.Opt(IDL.Text),
    'user' : IDL.Principal,
    'avatar' : IDL.Opt(IDL.Text),
  });
  const NewUser = IDL.Record({
    'nickname' : IDL.Opt(IDL.Text),
    'user' : IDL.Principal,
  });
  const UserImportArgs = IDL.Record({
    'users' : IDL.Vec(NewUser),
    'department' : IDL.Opt(IDL.Text),
  });
  const UserPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(UserEntry),
  });
  const UserRemoveArgs = IDL.Record({
    'user' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
  });
  const UserSetStatusArgs = IDL.Record({
    'status' : MemberStatus,
    'user' : IDL.Principal,
    'department' : IDL.Opt(IDL.Text),
  });
  const VerdictDraftArgs = IDL.Record({
    'decision' : IDL.Text,
    'case' : IDL.Text,
    'reasoning_ref' : IDL.Opt(IDL.Text),
    'penalties' : IDL.Vec(PenaltyTerms),
  });
  const VerdictContractArgs = IDL.Record({
    'contract' : IDL.Text,
    'verdict' : IDL.Text,
  });
  const VerdictTermsArgs = IDL.Record({
    'decision' : IDL.Opt(IDL.Text),
    'verdict' : IDL.Text,
    'reasoning_ref' : IDL.Opt(IDL.Text),
    'penalties' : IDL.Opt(IDL.Vec(PenaltyTerms)),
  });
  const ZoneClearArgs = IDL.Record({
    'zone' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  const ZoneSetArgs = IDL.Record({
    'kind' : IDL.Opt(IDL.Text),
    'name' : IDL.Opt(IDL.Text),
    'zone' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
  });
  return IDL.Service({
    'ggg_allocation_rule_draft' : IDL.Func(
        [AllocationRuleDraftArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_allocation_rule_propose' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_appeal_decide' : IDL.Func(
        [AppealDecideArgs],
        [IDL.Variant({ 'Ok' : Appeal, 'Err' : GggError })],
        [],
      ),
    'ggg_appeal_file' : IDL.Func(
        [AppealFileArgs],
        [IDL.Variant({ 'Ok' : Appeal, 'Err' : GggError })],
        [],
      ),
    'ggg_appoint' : IDL.Func(
        [AppointArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_appoint_acting' : IDL.Func(
        [AppointArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_appointment_end' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_authority_grant' : IDL.Func(
        [AuthorityGrantArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_authority_revoke' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_bid_score' : IDL.Func(
        [BidScoreArgs],
        [IDL.Variant({ 'Ok' : Bid, 'Err' : GggError })],
        [],
      ),
    'ggg_bid_submit' : IDL.Func(
        [BidSubmitArgs],
        [IDL.Variant({ 'Ok' : Bid, 'Err' : GggError })],
        [],
      ),
    'ggg_bid_withdraw' : IDL.Func(
        [BidWithdrawArgs],
        [IDL.Variant({ 'Ok' : Bid, 'Err' : GggError })],
        [],
      ),
    'ggg_bids_reveal' : IDL.Func(
        [BidsRevealArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_budget_amend' : IDL.Func(
        [BudgetAmendArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_budget_draft' : IDL.Func(
        [BudgetDraftArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_budget_propose' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_case_assign' : IDL.Func(
        [CaseAssignArgs],
        [IDL.Variant({ 'Ok' : Case, 'Err' : GggError })],
        [],
      ),
    'ggg_codex_install' : IDL.Func(
        [CodexSource],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_codex_revert' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_codex_status' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : CodexView, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_codex_uninstall' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_contract_create' : IDL.Func(
        [ContractCreateArgs],
        [IDL.Variant({ 'Ok' : Contract, 'Err' : GggError })],
        [],
      ),
    'ggg_contract_terminate' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Contract, 'Err' : GggError })],
        [],
      ),
    'ggg_court_create' : IDL.Func(
        [CourtCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_credential_issue' : IDL.Func(
        [CredentialIssueArgs],
        [IDL.Variant({ 'Ok' : CredentialIssued, 'Err' : GggError })],
        [],
      ),
    'ggg_credential_revoke' : IDL.Func(
        [CredentialRevokeArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_credential_verify' : IDL.Func(
        [CredentialVerifyArgs],
        [IDL.Variant({ 'Ok' : CredentialCheck, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_crypto_access' : IDL.Func(
        [AccessArgs],
        [IDL.Variant({ 'Ok' : PrincipalPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_crypto_derive_key' : IDL.Func(
        [IDL.Vec(IDL.Nat8)],
        [IDL.Variant({ 'Ok' : IDL.Vec(IDL.Nat8), 'Err' : GggError })],
        [],
      ),
    'ggg_crypto_envelope' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : IDL.Opt(KeyEnvelope), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_crypto_grant' : IDL.Func(
        [KeyGrantArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_crypto_public_key' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : IDL.Vec(IDL.Nat8), 'Err' : GggError })],
        [],
      ),
    'ggg_crypto_revoke' : IDL.Func(
        [KeyRevokeArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_crypto_scopes' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : ScopePage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_delegable_operations' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : IDL.Vec(DelegableOperation), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_delegation_accept' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Delegation, 'Err' : GggError })],
        [],
      ),
    'ggg_delegation_grant' : IDL.Func(
        [DelegationGrantArgs],
        [IDL.Variant({ 'Ok' : Delegation, 'Err' : GggError })],
        [],
      ),
    'ggg_delegation_list' : IDL.Func(
        [DelegationListArgs],
        [IDL.Variant({ 'Ok' : DelegationPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_delegation_request' : IDL.Func(
        [DelegationRequestArgs],
        [IDL.Variant({ 'Ok' : DelegationRequest, 'Err' : GggError })],
        [],
      ),
    'ggg_delegation_request_decide' : IDL.Func(
        [DelegationDecideArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(Delegation), 'Err' : GggError })],
        [],
      ),
    'ggg_delegation_revoke' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Delegation, 'Err' : GggError })],
        [],
      ),
    'ggg_department_chart' : IDL.Func(
        [ChartArgs],
        [IDL.Variant({ 'Ok' : Chart, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_department_create' : IDL.Func(
        [DepartmentCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_department_delete' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_department_edit' : IDL.Func(
        [DepartmentEditArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_department_expel' : IDL.Func(
        [ExpelArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_department_get' : IDL.Func(
        [GetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(DepartmentDetail), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_department_list' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : DepartmentPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_department_set_policy' : IDL.Func(
        [DepartmentPolicyArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_dispute_accept' : IDL.Func(
        [DisputeAcceptArgs],
        [IDL.Variant({ 'Ok' : Case, 'Err' : GggError })],
        [],
      ),
    'ggg_dispute_file' : IDL.Func(
        [DisputeFileArgs],
        [IDL.Variant({ 'Ok' : Dispute, 'Err' : GggError })],
        [],
      ),
    'ggg_dispute_get' : IDL.Func(
        [DisputeGetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(Dispute), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_dispute_list_all' : IDL.Func(
        [DisputeListArgs],
        [IDL.Variant({ 'Ok' : DisputePage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_dispute_reject' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Dispute, 'Err' : GggError })],
        [],
      ),
    'ggg_dispute_withdraw' : IDL.Func(
        [DisputeWithdrawArgs],
        [IDL.Variant({ 'Ok' : Dispute, 'Err' : GggError })],
        [],
      ),
    'ggg_document_delete' : IDL.Func(
        [DocumentDeleteArgs],
        [IDL.Variant({ 'Ok' : DocumentDeleted, 'Err' : GggError })],
        [],
      ),
    'ggg_document_get' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : IDL.Opt(DocumentAccess), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_document_list' : IDL.Func(
        [DocumentListArgs],
        [IDL.Variant({ 'Ok' : DocumentPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_document_revoke' : IDL.Func(
        [DocumentRevokeArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_document_share' : IDL.Func(
        [DocumentShareArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_document_store' : IDL.Func(
        [DocumentStoreArgs],
        [IDL.Variant({ 'Ok' : DocumentStored, 'Err' : GggError })],
        [],
      ),
    'ggg_enforcement_escalate' : IDL.Func(
        [EnforcementArgs],
        [IDL.Variant({ 'Ok' : Notification, 'Err' : GggError })],
        [],
      ),
    'ggg_enforcement_notify' : IDL.Func(
        [EnforcementNotifyArgs],
        [IDL.Variant({ 'Ok' : Notification, 'Err' : GggError })],
        [],
      ),
    'ggg_enforcement_record' : IDL.Func(
        [EnforcementArgs],
        [IDL.Variant({ 'Ok' : Event, 'Err' : GggError })],
        [],
      ),
    'ggg_events' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : EventPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_evidence_evaluate' : IDL.Func(
        [EvidenceEvaluateArgs],
        [IDL.Variant({ 'Ok' : IDL.Bool, 'Err' : GggError })],
        [],
      ),
    'ggg_evidence_submit' : IDL.Func(
        [EvidenceSubmitArgs],
        [IDL.Variant({ 'Ok' : IDL.Text, 'Err' : GggError })],
        [],
      ),
    'ggg_federal_vote_cancel' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_federal_vote_finalize' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : FederalVote, 'Err' : GggError })],
        [],
      ),
    'ggg_federal_vote_propose' : IDL.Func(
        [FederalVoteProposeArgs],
        [IDL.Variant({ 'Ok' : FederalVote, 'Err' : GggError })],
        [],
      ),
    'ggg_federation_message' : IDL.Func(
        [FederationMessageArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(Value), 'Err' : GggError })],
        [],
      ),
    'ggg_fund_create' : IDL.Func(
        [FundCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_governance_update' : IDL.Func(
        [GovernanceUpdateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_identity_review' : IDL.Func(
        [IdentityReviewArgs],
        [IDL.Variant({ 'Ok' : Identity, 'Err' : GggError })],
        [],
      ),
    'ggg_identity_submit' : IDL.Func(
        [IdentitySubmitArgs],
        [IDL.Variant({ 'Ok' : Identity, 'Err' : GggError })],
        [],
      ),
    'ggg_invite_create' : IDL.Func(
        [InviteCreateArgs],
        [IDL.Variant({ 'Ok' : InviteCreated, 'Err' : GggError })],
        [],
      ),
    'ggg_invite_list' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : InvitePage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_invite_revoke' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Invite, 'Err' : GggError })],
        [],
      ),
    'ggg_invoice_check' : IDL.Func(
        [InvoiceCheckArgs],
        [IDL.Variant({ 'Ok' : Invoice, 'Err' : GggError })],
        [],
      ),
    'ggg_invoice_create' : IDL.Func(
        [InvoiceCreateArgs],
        [IDL.Variant({ 'Ok' : InvoiceCreated, 'Err' : GggError })],
        [],
      ),
    'ggg_invoice_refresh' : IDL.Func(
        [InvoiceRefreshArgs],
        [IDL.Variant({ 'Ok' : InvoicePage, 'Err' : GggError })],
        [],
      ),
    'ggg_judge_appoint' : IDL.Func(
        [JudgeAppointArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_judge_revoke' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_land_freeze' : IDL.Func(
        [LandFreezeArgs],
        [IDL.Variant({ 'Ok' : Land, 'Err' : GggError })],
        [],
      ),
    'ggg_land_list' : IDL.Func(
        [LandListArgs],
        [IDL.Variant({ 'Ok' : LandPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_land_map' : IDL.Func(
        [LandMapArgs],
        [IDL.Variant({ 'Ok' : LandMap, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_land_mint_nft' : IDL.Func(
        [LandMintArgs],
        [IDL.Variant({ 'Ok' : IDL.Nat, 'Err' : GggError })],
        [],
      ),
    'ggg_land_register' : IDL.Func(
        [LandRegisterArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_land_transfer' : IDL.Func(
        [LandTransferArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_land_unfreeze' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Land, 'Err' : GggError })],
        [],
      ),
    'ggg_ledger_view' : IDL.Func(
        [LedgerArgs],
        [IDL.Variant({ 'Ok' : LedgerPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_license_apply' : IDL.Func(
        [LicenseApplyArgs],
        [IDL.Variant({ 'Ok' : License, 'Err' : GggError })],
        [],
      ),
    'ggg_license_decide' : IDL.Func(
        [LicenseDecideArgs],
        [IDL.Variant({ 'Ok' : License, 'Err' : GggError })],
        [],
      ),
    'ggg_license_list' : IDL.Func(
        [LicenseListArgs],
        [IDL.Variant({ 'Ok' : LicensePage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_license_renew' : IDL.Func(
        [LicenseRenewArgs],
        [IDL.Variant({ 'Ok' : License, 'Err' : GggError })],
        [],
      ),
    'ggg_license_revoke' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : License, 'Err' : GggError })],
        [],
      ),
    'ggg_license_suspend' : IDL.Func(
        [LicenseSuspendArgs],
        [IDL.Variant({ 'Ok' : License, 'Err' : GggError })],
        [],
      ),
    'ggg_license_verify' : IDL.Func(
        [LicenseVerifyArgs],
        [IDL.Variant({ 'Ok' : LicenseCheck, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_mandate_assign_executor' : IDL.Func(
        [MandateExecutorArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_mandate_create' : IDL.Func(
        [MandateCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_mandate_revoke' : IDL.Func(
        [MandateRevokeArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_nft_token_register' : IDL.Func(
        [NFTTokenRegisterArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_notification_list' : IDL.Func(
        [NotificationListArgs],
        [IDL.Variant({ 'Ok' : NotificationPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_notification_read' : IDL.Func(
        [NotificationReadArgs],
        [IDL.Variant({ 'Ok' : NotificationsRead, 'Err' : GggError })],
        [],
      ),
    'ggg_notification_send' : IDL.Func(
        [NotificationSendArgs],
        [IDL.Variant({ 'Ok' : Notification, 'Err' : GggError })],
        [],
      ),
    'ggg_organization_edit' : IDL.Func(
        [OrganizationEditArgs],
        [IDL.Variant({ 'Ok' : Organization, 'Err' : GggError })],
        [],
      ),
    'ggg_organization_get' : IDL.Func(
        [GetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(OrganizationDetail), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_organization_list' : IDL.Func(
        [OrganizationListArgs],
        [IDL.Variant({ 'Ok' : OrganizationPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_organization_register' : IDL.Func(
        [OrganizationRegisterArgs],
        [IDL.Variant({ 'Ok' : Organization, 'Err' : GggError })],
        [],
      ),
    'ggg_organization_set_status' : IDL.Func(
        [OrganizationStatusArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_payment_account_add' : IDL.Func(
        [PaymentAccountAddArgs],
        [IDL.Variant({ 'Ok' : PaymentAccount, 'Err' : GggError })],
        [],
      ),
    'ggg_payment_account_remove' : IDL.Func(
        [PaymentAccountRemoveArgs],
        [IDL.Variant({ 'Ok' : PaymentAccount, 'Err' : GggError })],
        [],
      ),
    'ggg_payroll_run' : IDL.Func(
        [PayrollRunArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_penalty_execute' : IDL.Func(
        [PenaltyExecuteArgs],
        [IDL.Variant({ 'Ok' : Penalty, 'Err' : GggError })],
        [],
      ),
    'ggg_period_close' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_period_open' : IDL.Func(
        [PeriodOpenArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_position_close' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_position_create' : IDL.Func(
        [PositionCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_position_edit' : IDL.Func(
        [PositionEditArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_private_data_update' : IDL.Func(
        [IDL.Vec(IDL.Nat8)],
        [IDL.Variant({ 'Ok' : User, 'Err' : GggError })],
        [],
      ),
    'ggg_profile_create' : IDL.Func(
        [ProfileCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_profile_edit' : IDL.Func(
        [ProfileEditArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_profile_update' : IDL.Func(
        [ProfileUpdateArgs],
        [IDL.Variant({ 'Ok' : User, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_create' : IDL.Func(
        [ProposalCreateArgs],
        [IDL.Variant({ 'Ok' : IDL.Text, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_execute' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Proposal, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_finalize' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Proposal, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_get' : IDL.Func(
        [GetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(ProposalDetail), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_proposal_list' : IDL.Func(
        [ProposalListArgs],
        [IDL.Variant({ 'Ok' : ProposalPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_proposal_open' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Proposal, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_vote' : IDL.Func(
        [ProposalVoteArgs],
        [IDL.Variant({ 'Ok' : Vote, 'Err' : GggError })],
        [],
      ),
    'ggg_proposal_withdraw' : IDL.Func(
        [ProposalWithdrawArgs],
        [IDL.Variant({ 'Ok' : Proposal, 'Err' : GggError })],
        [],
      ),
    'ggg_quarter_configure' : IDL.Func(
        [QuarterConfigureArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_quarter_deregister' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_quarter_directory' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : QuarterDirectory, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_quarter_join_federation' : IDL.Func(
        [JoinFederationArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_quarter_register' : IDL.Func(
        [QuarterRegisterArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_quarter_secede' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_configure' : IDL.Func(
        [RealmConfigureArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_configure_branding' : IDL.Func(
        [BrandingArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_configure_tokens' : IDL.Func(
        [TokensArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_configure_trust_policy' : IDL.Func(
        [TrustPolicyArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_info' : IDL.Func([], [Realm], ['query']),
    'ggg_realm_join' : IDL.Func(
        [JoinArgs],
        [IDL.Variant({ 'Ok' : UserEntry, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_register' : IDL.Func(
        [RealmRegisterArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_realm_upgrade' : IDL.Func(
        [RealmUpgradeArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_report_issue' : IDL.Func(
        [ReportIssueArgs],
        [IDL.Variant({ 'Ok' : FinancialReport, 'Err' : GggError })],
        [],
      ),
    'ggg_report_view' : IDL.Func(
        [ReportArgs],
        [IDL.Variant({ 'Ok' : ReportPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_representative_add' : IDL.Func(
        [RepresentativeAddArgs],
        [IDL.Variant({ 'Ok' : Appointment, 'Err' : GggError })],
        [],
      ),
    'ggg_representative_remove' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Appointment, 'Err' : GggError })],
        [],
      ),
    'ggg_resolution_query' : IDL.Func(
        [ResolutionQueryArgs],
        [IDL.Variant({ 'Ok' : ResolutionPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_role_assign' : IDL.Func(
        [RoleArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_role_revoke' : IDL.Func(
        [RoleArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_self_change_quarter' : IDL.Func(
        [ChangeQuarterArgs],
        [IDL.Variant({ 'Ok' : Forward, 'Err' : GggError })],
        [],
      ),
    'ggg_setup_launch' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : Realm, 'Err' : GggError })],
        [],
      ),
    'ggg_setup_state' : IDL.Func(
        [],
        [IDL.Variant({ 'Ok' : SetupState, 'Err' : GggError })],
        [],
      ),
    'ggg_setup_step' : IDL.Func(
        [SetupStep],
        [IDL.Variant({ 'Ok' : SetupState, 'Err' : GggError })],
        [],
      ),
    'ggg_tax_assess' : IDL.Func(
        [TaxAssessArgs],
        [IDL.Variant({ 'Ok' : TaxAssessPage, 'Err' : GggError })],
        [],
      ),
    'ggg_tax_declare' : IDL.Func(
        [TaxDeclareArgs],
        [IDL.Variant({ 'Ok' : TaxDeclared, 'Err' : GggError })],
        [],
      ),
    'ggg_tax_policy_draft' : IDL.Func(
        [TaxPolicyDraftArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tax_policy_propose' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tender_award' : IDL.Func(
        [TenderAwardArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tender_cancel' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tender_close' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tender_create' : IDL.Func(
        [TenderCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_tender_get' : IDL.Func(
        [GetArgs],
        [IDL.Variant({ 'Ok' : IDL.Opt(TenderDetail), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_tender_list' : IDL.Func(
        [TenderListArgs],
        [IDL.Variant({ 'Ok' : TenderPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_tender_open' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_token_force_transfer' : IDL.Func(
        [ForceTransferArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_token_freeze' : IDL.Func(
        [FreezeArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_token_register' : IDL.Func(
        [TokenRegisterArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_transfer_create' : IDL.Func(
        [TransferCreateArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_transfer_revert' : IDL.Func(
        [TransferRevertArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_treasury_configure' : IDL.Func(
        [TreasuryConfigureArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_treasury_view' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : TreasuryView, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_user_add' : IDL.Func(
        [UserAddArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_user_edit' : IDL.Func(
        [UserEditArgs],
        [IDL.Variant({ 'Ok' : User, 'Err' : GggError })],
        [],
      ),
    'ggg_user_get' : IDL.Func(
        [IDL.Principal],
        [IDL.Variant({ 'Ok' : IDL.Opt(UserEntry), 'Err' : GggError })],
        ['query'],
      ),
    'ggg_user_import' : IDL.Func(
        [UserImportArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_user_list' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : UserPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_user_remove' : IDL.Func(
        [UserRemoveArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_user_set_status' : IDL.Func(
        [UserSetStatusArgs],
        [IDL.Variant({ 'Ok' : Governed, 'Err' : GggError })],
        [],
      ),
    'ggg_verdict_draft' : IDL.Func(
        [VerdictDraftArgs],
        [IDL.Variant({ 'Ok' : Verdict, 'Err' : GggError })],
        [],
      ),
    'ggg_verdict_finalize' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Verdict, 'Err' : GggError })],
        [],
      ),
    'ggg_verdict_issue' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : Verdict, 'Err' : GggError })],
        [],
      ),
    'ggg_verdict_link_contract' : IDL.Func(
        [VerdictContractArgs],
        [IDL.Variant({ 'Ok' : Verdict, 'Err' : GggError })],
        [],
      ),
    'ggg_verdict_modify_terms' : IDL.Func(
        [VerdictTermsArgs],
        [IDL.Variant({ 'Ok' : Verdict, 'Err' : GggError })],
        [],
      ),
    'ggg_zone_clear' : IDL.Func(
        [ZoneClearArgs],
        [IDL.Variant({ 'Ok' : Zone, 'Err' : GggError })],
        [],
      ),
    'ggg_zone_set' : IDL.Func(
        [ZoneSetArgs],
        [IDL.Variant({ 'Ok' : Zone, 'Err' : GggError })],
        [],
      ),
    'icrc10_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text }))],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
