export const idlFactory = ({ IDL }) => {
  const Value = IDL.Rec();
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
  const CodexStatus = IDL.Variant({
    'Inactive' : IDL.Null,
    'Active' : IDL.Null,
    'Reverted' : IDL.Null,
  });
  const Timestamp = IDL.Nat64;
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
  const Codex = IDL.Record({
    'id' : IDL.Text,
    'status' : CodexStatus,
    'installed_at' : Timestamp,
    'previous' : IDL.Opt(IDL.Text),
    'source' : IDL.Text,
    'capabilities' : IDL.Vec(IDL.Text),
    'version' : IDL.Text,
    'checksum' : IDL.Text,
    'manifest' : Value,
  });
  const CodexView = IDL.Record({
    'signing' : SigningPolicy,
    'next' : IDL.Opt(IDL.Text),
    'codex' : IDL.Opt(Codex),
    'history' : IDL.Vec(Codex),
    'healthy' : IDL.Bool,
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
  const Ref = IDL.Record({ 'id' : IDL.Text, 'kind' : IDL.Text });
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
  const DisputeGetArgs = IDL.Record({
    'id' : IDL.Text,
    'on_behalf_of' : IDL.Opt(IDL.Principal),
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
  const DisputeListArgs = IDL.Record({
    'status' : IDL.Opt(DisputeStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
  });
  const DisputePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Dispute),
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
  const GovernanceUpdateArgs = IDL.Record({
    'voting_window' : IDL.Opt(Duration),
    'department' : IDL.Opt(IDL.Text),
    'voting_quorum' : IDL.Opt(IDL.Nat),
    'voting_threshold' : IDL.Opt(IDL.Nat),
  });
  const Governed = IDL.Variant({
    'Done' : IDL.Opt(IDL.Text),
    'Proposed' : IDL.Text,
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
  const LandListArgs = IDL.Record({
    'owner' : IDL.Opt(Ref),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
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
  const LicenseStatus = IDL.Variant({
    'Applied' : IDL.Null,
    'Active' : IDL.Null,
    'Suspended' : IDL.Null,
    'Rejected' : IDL.Null,
    'Revoked' : IDL.Null,
    'Expired' : IDL.Null,
  });
  const LicenseListArgs = IDL.Record({
    'status' : IDL.Opt(LicenseStatus),
    'cursor' : IDL.Opt(IDL.Text),
    'kind' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
    'holder' : IDL.Opt(Ref),
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
  const LicensePage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(License),
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
    'department' : IDL.Opt(IDL.Text),
  });
  const MandateCreateArgs = IDL.Record({
    'title' : IDL.Text,
    'max_value' : IDL.Opt(IDL.Nat),
    'scope' : Value,
    'executor' : IDL.Opt(IDL.Text),
    'department' : IDL.Opt(IDL.Text),
    'expires_at' : IDL.Opt(Timestamp),
    'symbol' : IDL.Opt(IDL.Text),
  });
  const MandateRevokeArgs = IDL.Record({
    'mandate' : IDL.Text,
    'department' : IDL.Opt(IDL.Text),
  });
  const NotificationListArgs = IDL.Record({
    'cursor' : IDL.Opt(IDL.Text),
    'recipient' : IDL.Opt(Ref),
    'unread' : IDL.Opt(IDL.Bool),
    'limit' : IDL.Opt(IDL.Nat32),
    'on_behalf_of' : IDL.Opt(IDL.Principal),
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
  const NotificationPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(Notification),
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
  const ReportArgs = IDL.Record({
    'id' : IDL.Opt(IDL.Text),
    'cursor' : IDL.Opt(IDL.Text),
    'limit' : IDL.Opt(IDL.Nat32),
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
  const ReportPage = IDL.Record({
    'next' : IDL.Opt(IDL.Text),
    'items' : IDL.Vec(FinancialReport),
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
  const PenaltyStatus = IDL.Variant({
    'Executed' : IDL.Null,
    'Waived' : IDL.Null,
    'Pending' : IDL.Null,
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
  const TenderStatus = IDL.Variant({
    'Open' : IDL.Null,
    'Evaluation' : IDL.Null,
    'Closed' : IDL.Null,
    'Awarded' : IDL.Null,
    'Draft' : IDL.Null,
    'Cancelled' : IDL.Null,
    'Contracted' : IDL.Null,
  });
  const Criterion = IDL.Record({ 'weight' : IDL.Nat, 'criterion' : IDL.Text });
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
  return IDL.Service({
    'ggg_codex_status' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : CodexView, 'Err' : GggError })],
        ['query'],
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
    'ggg_crypto_envelope' : IDL.Func(
        [IDL.Text],
        [IDL.Variant({ 'Ok' : IDL.Opt(KeyEnvelope), 'Err' : GggError })],
        ['query'],
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
    'ggg_events' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : EventPage, 'Err' : GggError })],
        ['query'],
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
    'ggg_ledger_view' : IDL.Func(
        [LedgerArgs],
        [IDL.Variant({ 'Ok' : LedgerPage, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_license_list' : IDL.Func(
        [LicenseListArgs],
        [IDL.Variant({ 'Ok' : LicensePage, 'Err' : GggError })],
        ['query'],
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
    'ggg_notification_list' : IDL.Func(
        [NotificationListArgs],
        [IDL.Variant({ 'Ok' : NotificationPage, 'Err' : GggError })],
        ['query'],
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
    'ggg_quarter_directory' : IDL.Func(
        [ListArgs],
        [IDL.Variant({ 'Ok' : QuarterDirectory, 'Err' : GggError })],
        ['query'],
      ),
    'ggg_realm_info' : IDL.Func([], [Realm], ['query']),
    'ggg_realm_join' : IDL.Func(
        [JoinArgs],
        [IDL.Variant({ 'Ok' : UserEntry, 'Err' : GggError })],
        [],
      ),
    'ggg_report_view' : IDL.Func(
        [ReportArgs],
        [IDL.Variant({ 'Ok' : ReportPage, 'Err' : GggError })],
        ['query'],
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
    'icrc10_supported_standards' : IDL.Func(
        [],
        [IDL.Vec(IDL.Record({ 'url' : IDL.Text, 'name' : IDL.Text }))],
        ['query'],
      ),
  });
};
export const init = ({ IDL }) => { return []; };
