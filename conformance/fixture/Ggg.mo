// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type AccessArgs = { cursor : ?Text; limit : ?Nat32; scope : Text };
  /// An ICRC-1 account.
  public type Account = { owner : Principal; subaccount : ?Blob };
  /// AllocationRule and TaxPolicy.
  public type AdoptionStatus = { #Superseded; #Draft; #Proposed; #Adopted };
  /// share in basis points.
  public type Allocation = { fund : Text; share : Nat };
  public type AllocationRule = {
    id : Text;
    status : AdoptionStatus;
    source_fund : Text;
    proposal : ?Text;
    rules : [Allocation];
  };
  /// Shares in basis points, adding up to at most 10 000.
  public type AllocationRuleDraftArgs = {
    source_fund : Text;
    rules : [Allocation];
  };
  public type Appeal = {
    id : Text;
    status : AppealStatus;
    decision : ?Text;
    case_ : Text;
    court : Text;
    grounds_ref : ?Text;
    verdict : Text;
    new_verdict : ?Text;
    appellant : Principal;
  };
  /// Granting issues a new verdict that overturns the appealed one.
  public type AppealDecideArgs = {
    decision : ?Text;
    granted : Bool;
    appeal : Text;
    reasoning_ref : ?Text;
    penalties : [PenaltyTerms];
  };
  /// `court` defaults to the issuing court's parent, and must rank above it.
  public type AppealFileArgs = {
    court : ?Text;
    grounds_ref : ?Text;
    verdict : Text;
    on_behalf_of : ?Principal;
  };
  public type AppealStatus = {
    #UnderReview;
    #Granted;
    #Withdrawn;
    #Filed;
    #Denied;
  };
  /// An agent needs a supervisor holding a non-agent seat in the same department or organization.
  public type AppointArgs = {
    supervisor : ?Principal;
    agent : Bool;
    user : Principal;
    position : Text;
  };
  public type Appointment = {
    id : Text;
    supervisor : ?Principal;
    status : AppointmentStatus;
    agent : Bool;
    source_quarter : ?Text;
    kind : AppointmentKind;
    user : Principal;
    position : Text;
    ended_at : ?Timestamp;
    started_at : Timestamp;
  };
  public type AppointmentKind = { #Acting; #Substantive };
  public type AppointmentStatus = { #Ended; #Active };
  public type Authority = {
    id : Text;
    grantor : Text;
    target : Ref;
    operations : [Text];
  };
  public type AuthorityGrantArgs = {
    target : Ref;
    operations : [Text];
    department : Text;
  };
  public type Balance = { amount : Nat; symbol : Text };
  public type Bid = {
    id : Text;
    sealed : Bool;
    score : ?Nat;
    vendor : Text;
    payload_ref : Text;
    price : ?Nat;
    tender : Text;
    submitted_at : Timestamp;
    payload_hash : Text;
  };
  public type BidOpening = { bid : Text; nonce : Text; price : Nat };
  public type BidScore = {
    id : Text;
    bid : Text;
    evaluator : Principal;
    score : Nat;
    scored_at : Timestamp;
    criterion : Text;
  };
  /// Marks from 0 to 10 per rubric criterion; scoring again replaces the caller's marks.
  public type BidScoreArgs = {
    bid : Text;
    scores : [{ score : Nat; criterion : Text }];
  };
  /// For a vendor the caller represents. `payload_hash` is the sha256 of `price:nonce`.
  public type BidSubmitArgs = {
    vendor : Text;
    on_behalf_of : ?Principal;
    payload_ref : Text;
    tender : Text;
    payload_hash : Text;
  };
  public type BidWithdrawArgs = { bid : Text; on_behalf_of : ?Principal };
  public type BidsRevealArgs = { tender : Text; openings : [BidOpening] };
  public type BrandingArgs = { logo_url : ?Text; background_image_url : ?Text };
  public type Budget = {
    id : Text;
    status : BudgetStatus;
    actual : Nat;
    period : Text;
    fund : Text;
    kind : Text;
    planned : Nat;
    category : Text;
    proposal : ?Text;
  };
  public type BudgetAmendArgs = { planned : Nat; budget : Text };
  public type BudgetDraftArgs = {
    period : Text;
    fund : Text;
    kind : ?Text;
    planned : Nat;
    category : Text;
  };
  public type BudgetStatus = { #Closed; #Draft; #Proposed; #Amended; #Adopted };
  public type Calendar = {
    id : Text;
    codex_release_cycle : ?Duration;
    voting_window : Duration;
    service_payment_cycle : ?Duration;
    epoch : Duration;
    benefit_cycle : ?Duration;
    license_review_cycle : ?Duration;
    fiscal_period : Duration;
    custom_cycles : [Cycle];
    realm : Text;
  };
  public type Case = {
    id : Text;
    judges : [Text];
    status : CaseStatus;
    title : Text;
    closed_at : ?Timestamp;
    court : Text;
    filed_at : Timestamp;
    defendant : Ref;
    evidence : [Sealed];
    dispute : ?Text;
    plaintiff : Ref;
  };
  public type CaseAssignArgs = { case_ : Text; judge : Text };
  public type CaseStatus = {
    #VerdictIssued;
    #Closed;
    #Transferred;
    #Dismissed;
    #Filed;
    #InProgress;
    #Appealed;
    #Assigned;
  };
  public type ChangeQuarterArgs = { quarter : Text; on_behalf_of : ?Principal };
  /// One level of the chart: the department's totals, and its sub-departments a page at a time.
  public type Chart = {
    next : ?Text;
    children : [Department];
    seats : Nat;
    filled : Nat;
    department : Department;
    positions : Nat;
  };
  public type ChartArgs = {
    cursor : ?Text;
    limit : ?Nat32;
    department : ?Text;
  };
  public type Codex = {
    id : Text;
    status : CodexStatus;
    installed_at : Timestamp;
    previous : ?Text;
    source : Text;
    capabilities : [Text];
    version : Text;
    checksum : Text;
    manifest : Value;
  };
  public type CodexSource = {
    #Package : { source : Text; manifest : Value };
    #Registry : { codex : Text; version : Text };
  };
  public type CodexStatus = { #Inactive; #Active; #Reverted };
  /// The active codex and a page of earlier ones, each named by its checksum ("sha256:<hex>").
  /// No method returns a Codex record.
  public type CodexView = {
    signing : SigningPolicy;
    next : ?Text;
    history : [Text];
    healthy : Bool;
    checksum : ?Text;
  };
  public type Contract = {
    id : Text;
    status : ContractStatus;
    title : Text;
    mandate : ?Text;
    starts_at : ?Timestamp;
    value : Nat;
    ends_at : ?Timestamp;
    terms_hash : Text;
    terms_ref : Text;
    parties : [Ref];
    symbol : Text;
  };
  public type ContractCreateArgs = {
    title : Text;
    mandate : ?Text;
    starts_at : ?Timestamp;
    value : Nat;
    ends_at : ?Timestamp;
    terms_hash : Text;
    terms_ref : Text;
    parties : [Ref];
    symbol : Text;
  };
  public type ContractStatus = {
    #Disputed;
    #Terminated;
    #Active;
    #Draft;
    #Fulfilled;
  };
  public type Court = {
    id : Text;
    status : CourtStatus;
    operator : Ref;
    name : Text;
    level : CourtLevel;
    jurisdiction : Text;
    license : ?Text;
    parent : ?Text;
  };
  /// `operator` is a department, or an organization holding an active court licence.
  public type CourtCreateArgs = {
    operator : Ref;
    name : Text;
    level : ?CourtLevel;
    jurisdiction : ?Text;
    parent : ?Text;
  };
  public type CourtLevel = {
    #Supreme;
    #Specialized;
    #FirstInstance;
    #Appellate;
  };
  public type CourtStatus = { #Closed; #Active };
  public type CredentialCheck = {
    revoked : Bool;
    expired : Bool;
    valid : Bool;
    licensed : Bool;
    ours : Bool;
  };
  public type CredentialIssueArgs = {
    prepared_by : ?Principal;
    subject : ?Text;
    schema : Text;
    fields : [(Text, Text)];
    payload_ref : ?Text;
    organization : Text;
    holder : Principal;
    expires_at : ?Timestamp;
    payload_hash : ?Text;
  };
  public type CredentialIssued = { token_id : Nat; header : [(Text, Text)] };
  public type CredentialRevokeArgs = {
    token_id : Nat;
    schema : Text;
    organization : Text;
    reason : Text;
  };
  /// The token's ggg: header as read from the ledger, and its frozen flag.
  public type CredentialVerifyArgs = { frozen : Bool; header : [(Text, Text)] };
  /// weight in basis points.
  public type Criterion = { weight : Nat; criterion : Text };
  public type Cycle = { name : Text; every : Duration };
  public type DelegableOperation = { permission : Text; operation : Text };
  public type Delegation = {
    id : Text;
    status : DelegationStatus;
    starts_at : ?Timestamp;
    accepted_at : ?Timestamp;
    delegate : Principal;
    description : Text;
    label_ : Text;
    revoked_at : ?Timestamp;
    revoked_by : ?Principal;
    grantor : Principal;
    scope : [Text];
    granted_by : Principal;
    requires_acceptance : Bool;
    expires_at : Timestamp;
  };
  /// Approving may narrow the scope or end the grant earlier.
  public type DelegationDecideArgs = {
    request : Text;
    approve : Bool;
    scope : ?[Text];
    expires_at : ?Timestamp;
  };
  public type DelegationGrantArgs = {
    starts_at : ?Timestamp;
    delegate : Principal;
    description : Text;
    label_ : Text;
    scope : [Text];
    expires_at : Timestamp;
  };
  public type DelegationListArgs = {
    cursor : ?Text;
    role : { #Delegate; #Grantor };
    limit : ?Nat32;
  };
  /// The caller's delegations in that role, and its open requests either way.
  public type DelegationPage = {
    next : ?Text;
    requests : [DelegationRequest];
    items : [Delegation];
  };
  public type DelegationRequest = {
    id : Text;
    starts_at : ?Timestamp;
    delegate : Principal;
    description : Text;
    label_ : Text;
    grantor : Principal;
    scope : [Text];
    request_expires_at : Timestamp;
    expires_at : Timestamp;
  };
  public type DelegationRequestArgs = {
    starts_at : ?Timestamp;
    description : Text;
    label_ : Text;
    grantor : Principal;
    scope : [Text];
    expires_at : Timestamp;
  };
  public type DelegationStatus = {
    #Active;
    #Declined;
    #Revoked;
    #Expired;
    #Pending;
  };
  public type Department = {
    id : Text;
    is_root : Bool;
    fund : ?Text;
    head : ?Principal;
    description : Text;
    target_policy : ?Policy;
    parent : ?Text;
    policy : Policy;
  };
  public type DepartmentCreateArgs = {
    description : Text;
    department : Text;
    parent : ?Text;
  };
  public type DepartmentDetail = {
    next : ?Text;
    seats : [Seat];
    department : Department;
  };
  /// The parent is never the department itself or one of its sub-departments; the root has none.
  public type DepartmentEditArgs = {
    head : ?{ #Set : Principal; #Clear };
    description : ?Text;
    department : Text;
    parent : ?Text;
  };
  public type DepartmentPage = { next : ?Text; items : [Department] };
  public type DepartmentPolicyArgs = { department : Text; policy : Policy };
  public type Dispute = {
    id : Text;
    status : DisputeStatus;
    title : Text;
    subject : ?Ref;
    claimant : Principal;
    description_ref : ?Text;
    case_ : ?Text;
    respondent : Ref;
  };
  public type DisputeAcceptArgs = { court : Text; dispute : Text };
  public type DisputeFileArgs = {
    title : Text;
    subject : ?Ref;
    description_ref : ?Text;
    on_behalf_of : ?Principal;
    respondent : Ref;
  };
  public type DisputeGetArgs = { id : Text; on_behalf_of : ?Principal };
  public type DisputeListArgs = {
    status : ?DisputeStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type DisputePage = { next : ?Text; items : [Dispute] };
  public type DisputeStatus = { #Withdrawn; #Rejected; #Filed; #Accepted };
  public type DisputeWithdrawArgs = {
    on_behalf_of : ?Principal;
    dispute : Text;
  };
  public type Document = {
    at : Timestamp;
    id : Text;
    ref : Text;
    title : Text;
    hash : Text;
    author : Principal;
    department : Text;
  };
  /// The document's ciphertext reference, its key scope, and the caller's envelope if it has one.
  public type DocumentAccess = {
    envelope : ?KeyEnvelope;
    scope : Text;
    document : Document;
  };
  /// Deletes the wrapped keys `limit` at a time (at most 500), then the document: call again until `deleted`.
  public type DocumentDeleteArgs = { limit : ?Nat32; document : Text };
  public type DocumentDeleted = { deleted : Bool; revoked : Nat };
  public type DocumentListArgs = {
    cursor : ?Text;
    limit : ?Nat32;
    department : Text;
  };
  public type DocumentPage = { next : ?Text; items : [Document] };
  public type DocumentRevokeArgs = {
    document : Text;
    principals : [Principal];
  };
  public type DocumentShareArgs = { keys : [WrappedKey]; document : Text };
  /// Stores a new document, or replaces `document`.
  public type DocumentStoreArgs = {
    ref : Text;
    title : Text;
    hash : Text;
    keys : [WrappedKey];
    document : ?Text;
    department : Text;
  };
  public type DocumentStored = { scope : Text; document : Document };
  /// Nanoseconds.
  public type Duration = Nat64;
  public type EnforcementArgs = { note : Text; verdict : Text };
  public type EnforcementNotifyArgs = {
    to : Ref;
    title : ?Text;
    body : ?Text;
    verdict : Text;
  };
  public type Event = {
    at : Timestamp;
    by : ?Principal;
    id : Text;
    op : Text;
    supervisor : ?Principal;
    result : Value;
    agent : Bool;
    args : Value;
    origin : Text;
    user : ?Principal;
  };
  /// Newest first. An archive holds the events from `first` to `last`, and answers ggg_events for them.
  public type EventArchive = {
    first : Text;
    last : Text;
    canister : Principal;
  };
  public type EventPage = {
    next : ?Text;
    items : [Event];
    archives : [EventArchive];
  };
  public type EvidenceEvaluateArgs = {
    admitted : Bool;
    case_ : Text;
    evidence : Text;
  };
  public type EvidenceSubmitArgs = {
    ref : Text;
    case_ : Text;
    hash : Text;
    on_behalf_of : ?Principal;
  };
  public type ExpelArgs = { user : Principal; department : Text };
  public type FederalVote = {
    id : Text;
    status : FederalVoteStatus;
    tally : Value;
    title : Text;
    action : ProposalAction;
    hash : Text;
    rule : Value;
    origin_quarter : Text;
    deadline : Timestamp;
  };
  public type FederalVoteLeg = {
    id : Text;
    no : Nat;
    yes : Nat;
    status : FederalVoteLegStatus;
    hash : ?Text;
    quarter : Text;
    vote : Text;
    abstain : Nat;
    proposal_id : ?Text;
    eligible : Nat;
    outcome : ?Outcome;
  };
  public type FederalVoteLegStatus = { #Open; #Reported };
  public type FederalVoteProposeArgs = {
    title : Text;
    action : ProposalAction;
    on_behalf_of : ?Principal;
  };
  public type FederalVoteStatus = { #Failed; #Passed; #Open; #Cancelled };
  public type FederationMessage = {
    id : Text;
    topic : Text;
    source : Text;
    body : Value;
    response : ?Value;
  };
  /// To quarter `to`, or by default every active quarter.
  public type FederationMessageArgs = {
    to : ?Text;
    topic : Text;
    body : Value;
  };
  public type FinancialReport = {
    id : Text;
    issued_by : Principal;
    as_of : Timestamp;
    period : Text;
    supersedes : ?Text;
    kind : Text;
    source_hash : Text;
    statements : Value;
  };
  public type FiscalPeriod = {
    id : Text;
    status : FiscalPeriodStatus;
    starts_at : Timestamp;
    ends_at : Timestamp;
    name : Text;
    source_hash : Text;
    statements : Value;
  };
  public type FiscalPeriodStatus = { #Open; #Closed; #Archived };
  /// By court order.
  public type ForceTransferArgs = {
    to : Principal;
    from : Principal;
    amount : Nat;
    symbol : Text;
    reason : ?Text;
  };
  public type Forward = {
    id : Text;
    destination : Text;
    signature : Blob;
    subject : Ref;
    origin : Text;
    moved_at : Timestamp;
  };
  public type FreezeArgs = {
    account : Principal;
    frozen : Bool;
    symbol : Text;
    reason : ?Text;
  };
  public type Fund = {
    id : Text;
    allocation_rule : ?Text;
    kind : Text;
    name : Text;
    department : ?Text;
    balances : [Balance];
  };
  /// `department` is the fund's owner; a department owns at most one fund.
  public type FundCreateArgs = {
    fund : Text;
    kind : ?Text;
    name : ?Text;
    department : ?Text;
  };
  /// One record by id, with its children a page at a time.
  public type GetArgs = { id : Text; cursor : ?Text; limit : ?Nat32 };
  public type GggError = {
    #GenericError : { message : Text; error_code : Nat };
    #NotFound;
    #InvalidArgument : Text;
    #Unavailable : Text;
    #Forbidden : { permission : ?Text; message : Text };
    #Unauthenticated;
    #Conflict : Text;
  };
  public type GovernanceUpdateArgs = {
    voting_window : ?Duration;
    voting_quorum : ?Nat;
    voting_threshold : ?Nat;
  };
  /// The change was applied, with the id of any record it created, or a proposal was filed to make it.
  public type Governed = { #Done : ?Text; #Proposed : Text };
  public type GuestUser = {
    id : Principal;
    permissions : [Text];
    home_quarter : Text;
  };
  public type Human = {
    id : Text;
    h3_index : ?Text;
    user : Principal;
    date_of_birth : ?Timestamp;
  };
  public type Identity = {
    id : Text;
    ref : Text;
    status : IdentityStatus;
    human : Text;
    kind : Text;
    issuer : Text;
    verified_at : ?Timestamp;
  };
  public type IdentityReviewArgs = {
    status : { #Rejected; #Verified };
    identity : Text;
  };
  public type IdentityStatus = { #Rejected; #Verified; #Pending };
  public type IdentitySubmitArgs = {
    ref : Text;
    kind : Text;
    issuer : ?Text;
    on_behalf_of : ?Principal;
  };
  public type Invite = {
    id : Text;
    max_uses : Nat;
    revoked : Bool;
    uses : Nat;
    created_by : Principal;
    redeemed_by : [Principal];
    department : ?Text;
    position : ?Text;
    expires_at : ?Timestamp;
    profile : ?Text;
  };
  public type InviteCreateArgs = {
    max_uses : ?Nat;
    code : ?Text;
    department : ?Text;
    position : ?Text;
    expires_at : ?Timestamp;
    profile : ?Text;
  };
  /// The code is returned only this once.
  public type InviteCreated = { code : Text; invite : Invite };
  public type InvitePage = { next : ?Text; items : [Invite] };
  public type Invoice = {
    id : Text;
    status : InvoiceStatus;
    due_at : ?Timestamp;
    paid_at : ?Timestamp;
    payer : Ref;
    amount : Nat;
    payment : ?Value;
    symbol : Text;
    reason : ?Ref;
  };
  public type InvoiceCheckArgs = { invoice : Text; on_behalf_of : ?Principal };
  public type InvoiceCreateArgs = {
    due_at : ?Timestamp;
    payer : Ref;
    amount : Nat;
    symbol : ?Text;
    reason : ?Ref;
  };
  /// The invoice, and the account to pay it into.
  public type InvoiceCreated = { invoice : Invoice; pay_to : Account };
  public type InvoicePage = { next : ?Text; items : [Invoice] };
  /// One invoice, or a batch of the pending and overdue ones (at most 20 per call).
  public type InvoiceRefreshArgs = {
    cursor : ?Text;
    invoice : ?Text;
    limit : ?Nat32;
  };
  public type InvoiceStatus = { #Paid; #Overdue; #Cancelled; #Pending };
  public type JoinArgs = { nickname : ?Text; code : ?Text };
  public type JoinFederationArgs = { name : ?Text; capital : Principal };
  public type Judge = {
    id : Text;
    appointed_at : Timestamp;
    status : JudgeStatus;
    court : Text;
    user : Principal;
    specialization : Text;
  };
  public type JudgeAppointArgs = {
    court : Text;
    user : Principal;
    specialization : ?Text;
  };
  public type JudgeStatus = { #Active; #Revoked };
  public type KeyEnvelope = {
    at : Timestamp;
    id : Text;
    principal : Principal;
    scope : Text;
    granted_by : Principal;
    wrapped_dek : Blob;
  };
  /// At most 500 keys or principals per call.
  public type KeyGrantArgs = { keys : [WrappedKey]; scope : Text };
  public type KeyRevokeArgs = { scope : Text; principals : [Principal] };
  public type Land = {
    x : Nat;
    y : Nat;
    id : Text;
    height : Nat;
    status : LandStatus;
    token_id : ?Nat;
    owner : Ref;
    metadata : Value;
    kind : Text;
    width : Nat;
    registered_by : Principal;
  };
  public type LandFreezeArgs = { land : Text; reason : ?Text };
  public type LandListArgs = { owner : ?Ref; cursor : ?Text; limit : ?Nat32 };
  public type LandMap = { next : ?Text; zones : [Zone]; parcels : [Land] };
  /// A viewport of at most 32 × 32 cells, and the zones not tied to a parcel a page at a time.
  public type LandMapArgs = {
    h : Nat;
    w : Nat;
    x : Nat;
    y : Nat;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type LandMintArgs = { prepared_by : ?Principal; land : Text };
  public type LandPage = { next : ?Text; items : [Land] };
  /// At most 16 × 16 cells, overlapping no other parcel.
  public type LandRegisterArgs = {
    x : Nat;
    y : Nat;
    height : ?Nat;
    owner : Ref;
    metadata : ?Value;
    kind : ?Text;
    width : ?Nat;
  };
  public type LandStatus = { #Disputed; #Active; #Revoked };
  /// Under a court order: an issued or final verdict in a case about the parcel, with `to` a party.
  public type LandTransferArgs = { to : Ref; order : Text; land : Text };
  public type LedgerArgs = {
    period : ?Text;
    cursor : ?Text;
    fund : ?Text;
    kind : ?LedgerKind;
    transaction : ?Text;
    limit : ?Nat32;
    symbol : ?Text;
  };
  /// At most one of the source references (transfer … appeal) is set.
  public type LedgerEntry = {
    at : Timestamp;
    id : Text;
    penalty : ?Text;
    contract : ?Text;
    period : ?Text;
    case_ : ?Text;
    fund : ?Text;
    invoice : ?Text;
    kind : LedgerKind;
    transaction : Text;
    user : ?Principal;
    description : Text;
    credit : Nat;
    appeal : ?Text;
    category : Text;
    organization : ?Text;
    debit : Nat;
    transfer : ?Text;
    symbol : Text;
  };
  public type LedgerKind = { #Asset; #Liability; #Revenue; #Expense; #Equity };
  public type LedgerPage = { next : ?Text; items : [LedgerEntry] };
  public type License = {
    id : Text;
    status : LicenseStatus;
    evidence_ref : ?Text;
    issued_at : ?Timestamp;
    issued_by : Text;
    applied_at : Timestamp;
    kind : Text;
    conditions : Value;
    holder : Ref;
    expires_at : ?Timestamp;
  };
  /// For the caller, or an organization they administer.
  public type LicenseApplyArgs = {
    evidence_ref : ?Text;
    kind : Text;
    on_behalf_of : ?Principal;
    conditions : ?Value;
    department : ?Text;
    holder : ?Ref;
  };
  public type LicenseCheck = { valid : Bool; license : ?License };
  public type LicenseDecideArgs = {
    approve : Bool;
    conditions : ?Value;
    department : ?Text;
    license : Text;
    expires_at : ?Timestamp;
  };
  public type LicenseListArgs = {
    status : ?LicenseStatus;
    cursor : ?Text;
    kind : ?Text;
    limit : ?Nat32;
    holder : ?Ref;
  };
  public type LicensePage = { next : ?Text; items : [License] };
  public type LicenseRenewArgs = {
    evidence_ref : ?Text;
    on_behalf_of : ?Principal;
    license : Text;
  };
  public type LicenseStatus = {
    #Applied;
    #Active;
    #Suspended;
    #Rejected;
    #Revoked;
    #Expired;
  };
  /// With `resume`, reinstates a suspended licence.
  public type LicenseSuspendArgs = { resume : Bool; license : Text };
  /// A licence by id, or the one of `kind` that `holder` holds.
  public type LicenseVerifyArgs = { id : ?Text; kind : ?Text; holder : ?Ref };
  public type ListArgs = { cursor : ?Text; limit : ?Nat32 };
  public type Mandate = {
    id : Text;
    status : MandateStatus;
    title : Text;
    max_value : ?Nat;
    scope : Value;
    proposal : ?Text;
    executor : ?Text;
    expires_at : ?Timestamp;
    symbol : ?Text;
  };
  /// A replayed proposal records itself as the mandate's proposal.
  public type MandateCreateArgs = {
    title : Text;
    max_value : ?Nat;
    scope : Value;
    executor : ?Text;
    expires_at : ?Timestamp;
    symbol : ?Text;
  };
  public type MandateExecutorArgs = { mandate : Text; executor : Text };
  public type MandateRevokeArgs = { mandate : Text };
  public type MandateStatus = { #Active; #Revoked; #Completed; #Expired };
  public type Member = {
    id : Text;
    status : MemberStatus;
    user : Principal;
    joined_at : ?Timestamp;
  };
  public type MemberStatus = { #Inactive; #Active; #Suspended; #Banned };
  public type NFTToken = {
    id : Text;
    supply_cap : ?Nat;
    transferable : Bool;
    name : Text;
    description : Text;
    canister : Principal;
    required_license : ?Text;
    total_supply : Nat;
  };
  public type NFTTokenRegisterArgs = {
    supply_cap : ?Nat;
    transferable : ?Bool;
    name : ?Text;
    description : ?Text;
    canister : Principal;
    required_license : ?Text;
    symbol : Text;
  };
  public type NewUser = { nickname : ?Text; user : Principal };
  public type Notification = {
    at : Timestamp;
    id : Text;
    read_by : [Principal];
    title : Text;
    topic : Text;
    body : Text;
    href : ?Text;
    recipient : Ref;
    sender : ?Text;
    visibility : Text;
  };
  public type NotificationListArgs = {
    cursor : ?Text;
    recipient : ?Ref;
    unread : ?Bool;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
  };
  public type NotificationPage = { next : ?Text; items : [Notification] };
  /// One notification, or with `recipient` a page of that recipient's.
  public type NotificationReadArgs = {
    cursor : ?Text;
    recipient : ?Ref;
    notification : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
  };
  public type NotificationSendArgs = {
    title : Text;
    topic : ?Text;
    body : ?Text;
    href : ?Text;
    recipient : Ref;
  };
  public type NotificationsRead = { next : ?Text; read : Nat };
  public type Organization = {
    id : Text;
    status : OrganizationStatus;
    description : Text;
    admins : [Principal];
  };
  public type OrganizationDetail = {
    next : ?Text;
    seats : [Seat];
    organization : Organization;
  };
  public type OrganizationEditArgs = {
    description : ?Text;
    admins : ?[Principal];
    organization : Text;
  };
  public type OrganizationListArgs = {
    status : ?OrganizationStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type OrganizationPage = { next : ?Text; items : [Organization] };
  public type OrganizationRegisterArgs = {
    description : Text;
    organization : Text;
  };
  public type OrganizationStatus = { #Active; #Dissolved; #Suspended };
  public type OrganizationStatusArgs = {
    status : OrganizationStatus;
    organization : Text;
  };
  public type Outcome = { #Failed; #Passed };
  public type PaymentAccount = {
    id : Text;
    verified : Bool;
    owner : Ref;
    network : Text;
    label_ : Text;
    address : Text;
    symbol : Text;
  };
  public type PaymentAccountAddArgs = {
    network : Text;
    label_ : ?Text;
    address : Text;
    on_behalf_of : ?Principal;
    organization : ?Text;
    symbol : ?Text;
  };
  public type PaymentAccountRemoveArgs = {
    account : Text;
    on_behalf_of : ?Principal;
    organization : ?Text;
  };
  /// Pays each active, non-agent appointee once per period label.
  public type PayrollRunArgs = {
    period : Text;
    department : Text;
    symbol : ?Text;
  };
  public type Penalty = {
    id : Text;
    status : PenaltyStatus;
    executed_at : ?Timestamp;
    invoice : ?Text;
    kind : PenaltyKind;
    verdict : Text;
    target : Ref;
    due_at : ?Timestamp;
    amount : ?Nat;
    symbol : ?Text;
  };
  public type PenaltyExecuteArgs = { penalty : Text; due_at : ?Timestamp };
  public type PenaltyKind = {
    #CommunityService;
    #Fine;
    #Injunction;
    #Termination;
    #Suspension;
    #Freeze;
    #Restitution;
    #Revocation;
  };
  public type PenaltyStatus = { #Executed; #Waived; #Pending };
  public type PenaltyTerms = {
    kind : PenaltyKind;
    target : Ref;
    due_at : ?Timestamp;
    amount : ?Nat;
    symbol : ?Text;
  };
  /// Periods open in order: one starts no earlier than the latest ends.
  public type PeriodOpenArgs = {
    starts_at : Timestamp;
    period : Text;
    ends_at : Timestamp;
    name : ?Text;
  };
  public type Permission = {
    id : Text;
    departments : [Text];
    description : Text;
    scope : ?Text;
    users : [Principal];
    category : Text;
    profiles : [Text];
  };
  /// m of n approvals; quorum in basis points.
  public type Policy = { m : Nat; n : Nat; veto : [Principal]; quorum : Nat };
  public type Position = {
    id : Text;
    status : PositionStatus;
    title : Text;
    salary_period : ?Duration;
    salary : Nat;
    headcount : Nat;
    organization : ?Text;
    department : ?Text;
    inherit_from_capital : Bool;
    profile : ?Text;
  };
  public type PositionCreateArgs = {
    title : Text;
    salary_period : ?Duration;
    salary : ?Nat;
    headcount : ?Nat;
    department : Text;
    position : Text;
    profile : ?Text;
  };
  /// Closing is position_close.
  public type PositionEditArgs = {
    status : ?{ #Open; #Frozen };
    title : ?Text;
    salary_period : ?Duration;
    salary : ?Nat;
    headcount : ?Nat;
    position : Text;
    profile : ?Text;
  };
  public type PositionStatus = { #Open; #Closed; #Frozen };
  public type PrincipalPage = { next : ?Text; items : [Principal] };
  public type ProfileCreateArgs = {
    allowed_to : [Text];
    description : Text;
    department : ?Text;
    profile : Text;
  };
  public type ProfileEditArgs = {
    allowed_to : ?[Text];
    description : ?Text;
    department : ?Text;
    profile : Text;
  };
  public type ProfileUpdateArgs = {
    nickname : ?Text;
    on_behalf_of : ?Principal;
    avatar : ?Text;
  };
  public type Proposal = {
    id : Text;
    opens_at : ?Timestamp;
    status : ProposalStatus;
    result : ?ProposalResult;
    tally : Tally;
    title : Text;
    action : ProposalAction;
    threshold : Nat;
    description : Text;
    deadline : ?Timestamp;
    on_behalf_of : ?Principal;
    proposer : Principal;
    department : ?Text;
    quorum : Nat;
  };
  public type ProposalAction = {
    /// One update call the realm makes to itself once accepted; `arg` is Candid-encoded.
    #Call : { arg : Blob; method : Text };
    /// Codex code to adopt; checksum is "sha256:<hex>".
    #Code : { url : Text; checksum : Text };
    /// The decision itself is the outcome.
    #Motion;
  };
  public type ProposalCreateArgs = {
    title : Text;
    action : ProposalAction;
    description : Text;
    on_behalf_of : ?Principal;
    department : ?Text;
  };
  /// The proposal, and its votes a page at a time.
  public type ProposalDetail = {
    votes : [Vote];
    next : ?Text;
    proposal : Proposal;
  };
  public type ProposalListArgs = {
    status : ?ProposalStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type ProposalPage = { next : ?Text; items : [Proposal] };
  public type ProposalResult = {
    /// Why execution failed.
    #Error : Text;
    /// The Candid-encoded reply of a Call.
    #Reply : Blob;
  };
  public type ProposalStatus = {
    #Failed;
    #Withdrawn;
    #Draft;
    #Rejected;
    #Executed;
    #Voting;
    #Accepted;
    #Expired;
  };
  public type ProposalVoteArgs = {
    on_behalf_of : ?Principal;
    proposal : Text;
    choice : VoteChoice;
  };
  public type ProposalWithdrawArgs = {
    on_behalf_of : ?Principal;
    proposal : Text;
  };
  public type Quarter = {
    id : Text;
    status : QuarterStatus;
    codex_version : ?Text;
    name : Text;
    last_activity_at : ?Timestamp;
    codex_id : ?Text;
    last_sync : ?Timestamp;
    index : Nat;
    population : Nat;
  };
  public type QuarterConfigureArgs = {
    status : ?QuarterStatus;
    quarter : ?Text;
    name : ?Text;
    rule : ?Value;
    federation_codex : ?Text;
    quarter_join_mode : ?Text;
  };
  public type QuarterDirectory = {
    next : ?Text;
    capital : ?Text;
    items : [Quarter];
  };
  public type QuarterRegisterArgs = { name : ?Text; canister : Principal };
  public type QuarterStatus = {
    #Splitting;
    #Setup;
    #Active;
    #Suspended;
    #Merging;
  };
  public type Realm = {
    id : Text;
    status : RealmStatus;
    require_marketplace_approval : Bool;
    is_quarter : Bool;
    name : Text;
    manifesto : Text;
    network : Text;
    federation_codex : ?Text;
    quarter_join_mode : ?Text;
    is_capital : Bool;
    calendar : ?Text;
    logo_url : ?Text;
    open_registration : Bool;
    trusted_principals : [Principal];
    federation_realm_id : ?Text;
    accounting_currency_decimals : ?Nat8;
    welcome_message : Text;
    trusted_approvers : [Text];
    voting_quorum : Nat;
    background_image_url : ?Text;
    voting_threshold : Nat;
    installed_version : Text;
    treasury : ?Text;
    accounting_currency : ?Text;
  };
  public type RealmConfigureArgs = {
    name : ?Text;
    manifesto : ?Text;
    quarter_join_mode : ?Text;
    open_registration : ?Bool;
    welcome_message : ?Text;
  };
  public type RealmRegisterArgs = {
    url : ?Text;
    registry : Principal;
    backend_url : ?Text;
  };
  public type RealmStatus = {
    #Setup;
    #Terminated;
    #Production;
    #Beta;
    #Alpha;
    #Deprecation;
  };
  /// Accepts exactly this module, if the trust policy does.
  public type RealmUpgradeArgs = { version : Text; module_hash : Blob };
  /// A reference to any entity: `kind` is the entity's name in the model.
  public type Ref = { id : Text; kind : Text };
  public type Registry = {
    id : Text;
    description : Text;
    principal_id : Principal;
  };
  /// One report by id, or a page of reports.
  public type ReportArgs = { id : ?Text; cursor : ?Text; limit : ?Nat32 };
  public type ReportIssueArgs = { period : Text; kind : ?Text };
  public type ReportPage = { next : ?Text; items : [FinancialReport] };
  /// Seats the user in the organization's position, creating the position if it is new.
  public type RepresentativeAddArgs = {
    supervisor : ?Principal;
    title : ?Text;
    agent : Bool;
    headcount : ?Nat;
    user : Principal;
    organization : Text;
    position : Text;
    profile : ?Text;
  };
  public type Resolution = { verdict : Verdict; penalties : [Penalty] };
  public type ResolutionPage = { next : ?Text; items : [Resolution] };
  /// Verdicts past draft, newest first.
  public type ResolutionQueryArgs = {
    cursor : ?Text;
    court : ?Text;
    search : ?Text;
    limit : ?Nat32;
    since : ?Timestamp;
  };
  public type RoleArgs = {
    user : Principal;
    department : ?Text;
    profile : Text;
  };
  public type ScopePage = { next : ?Text; items : [Text] };
  /// Encrypted content: where it lives and its hash.
  public type Sealed = { ref : Text; hash : Text };
  /// A position and the appointments that hold it.
  public type Seat = { holders : [Appointment]; position : Position };
  public type SetupState = {
    status : RealmStatus;
    done : [Text];
    todo : [Text];
    founder : ?Principal;
  };
  public type SetupStep = {
    #TrustPolicy : TrustPolicyArgs;
    #Realm : RealmConfigureArgs;
    #Branding : BrandingArgs;
    #Tokens : TokensArgs;
  };
  public type SigningPolicy = {
    supervision : { #Required; #Optional };
    agents : [Text];
    delegable : [Text];
  };
  public type Tally = { no : Nat; yes : Nat; abstain : Nat; eligible : ?Nat };
  /// Bills one batch of taxpayers for the period; those already billed are skipped.
  public type TaxAssessArgs = {
    tax : ?Text;
    period : Text;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type TaxAssessPage = {
    skipped : Nat;
    next : ?Text;
    items : [Invoice];
  };
  public type TaxDeclaration = {
    id : Text;
    status : TaxDeclarationStatus;
    period : Text;
    base : Text;
    invoice : ?Text;
    declarant : Ref;
    amount : Nat;
  };
  public type TaxDeclarationStatus = { #Disputed; #Filed; #Assessed; #Settled };
  /// For the caller, or an organization they administer.
  public type TaxDeclareArgs = {
    period : Text;
    base : Text;
    on_behalf_of : ?Principal;
    organization : ?Text;
    amount : Nat;
  };
  public type TaxDeclared = {
    invoice : ?Invoice;
    declaration : TaxDeclaration;
  };
  public type TaxPolicy = {
    id : Text;
    status : AdoptionStatus;
    adopted_at : ?Timestamp;
    description : Text;
    document : Value;
    proposal : ?Text;
  };
  public type TaxPolicyDraftArgs = { description : ?Text; document : Value };
  public type Tender = {
    id : Text;
    opens_at : ?Timestamp;
    status : TenderStatus;
    title : Text;
    requester : Text;
    closes_at : ?Timestamp;
    rubric : [Criterion];
    contract : ?Text;
    winner : ?Text;
    description : Text;
  };
  /// `bid` defaults to the best-scored revealed bid; a lower-scored one needs a justification.
  public type TenderAwardArgs = {
    bid : ?Text;
    justification : ?Text;
    tender : Text;
  };
  /// Weights in basis points, adding up to 10 000.
  public type TenderCreateArgs = {
    opens_at : ?Timestamp;
    title : Text;
    requester : Text;
    closes_at : ?Timestamp;
    rubric : [Criterion];
    description : ?Text;
  };
  /// A sealed bid shows no price or score.
  public type TenderDetail = { bids : [Bid]; next : ?Text; tender : Tender };
  public type TenderListArgs = {
    status : ?TenderStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type TenderPage = { next : ?Text; items : [Tender] };
  public type TenderStatus = {
    #Open;
    #Evaluation;
    #Closed;
    #Awarded;
    #Draft;
    #Cancelled;
    #Contracted;
  };
  /// Nanoseconds since 1970-01-01 UTC, as returned by ic0.time.
  public type Timestamp = Nat64;
  public type Token = {
    id : Text;
    fee : Nat;
    decimals : Nat8;
    ledger : Principal;
    indexer : ?Principal;
  };
  public type TokenRegisterArgs = {
    fee : ?Nat;
    decimals : ?Nat8;
    ledger : Principal;
    indexer : ?Principal;
    symbol : Text;
  };
  public type TokensArgs = {
    accounting_currency_decimals : ?Nat8;
    accounting_currency : ?Text;
  };
  public type Trade = {
    id : Text;
    status : TradeStatus;
    contract : ?Text;
    leg_a : Text;
    leg_b : Text;
  };
  public type TradeStatus = { #Failed; #Completed; #Pending };
  public type Transfer = {
    at : Timestamp;
    id : Text;
    to : Ref;
    status : TransferStatus;
    invoice : ?Text;
    sender : Ref;
    ledger_tx : ?Nat;
    amount : Nat;
    symbol : Text;
    payroll : ?Text;
  };
  /// The fund must also cover the ledger fee. `symbol` defaults to the accounting currency.
  public type TransferCreateArgs = {
    to : Ref;
    contract : ?Text;
    fund : Text;
    description : ?Text;
    category : ?Text;
    on_behalf_of : ?Principal;
    amount : Nat;
    symbol : ?Text;
  };
  public type TransferRevertArgs = { transfer : Text; reason : ?Text };
  public type TransferStatus = { #Failed; #Sending; #Completed; #Pending };
  public type Treasury = { id : Text; config : TreasuryConfig };
  public type TreasuryConfig = {
    auto_allocate : Bool;
    epoch : Duration;
    source_fund : Text;
    anchor_month : Nat8;
  };
  public type TreasuryConfigureArgs = {
    auto_allocate : ?Bool;
    epoch : ?Duration;
    source_fund : ?Text;
    anchor_month : ?Nat8;
  };
  /// The treasury and its registered tokens, and its funds a page at a time.
  public type TreasuryView = {
    funds : [Fund];
    next : ?Text;
    tokens : [Token];
    nft_tokens : [NFTToken];
    treasury : ?Treasury;
  };
  public type TrustPolicyArgs = {
    require_marketplace_approval : ?Bool;
    trusted_principals : ?[Principal];
    trusted_approvers : ?[Text];
  };
  public type User = {
    id : Principal;
    private_data : ?Blob;
    nickname : ?Text;
    home_quarter : ?Text;
    profiles : [Text];
    avatar : ?Text;
  };
  public type UserAddArgs = {
    nickname : ?Text;
    user : Principal;
    department : ?Text;
  };
  public type UserEditArgs = {
    nickname : ?Text;
    home_quarter : ?Text;
    user : Principal;
    avatar : ?Text;
  };
  public type UserEntry = { member : ?Member; user : User };
  /// At most 500 users per call. Nobody is added if one is already known or listed twice.
  public type UserImportArgs = { users : [NewUser]; department : ?Text };
  public type UserPage = { next : ?Text; items : [UserEntry] };
  public type UserProfile = {
    id : Text;
    allowed_to : [Text];
    permissions : [Text];
    description : Text;
  };
  public type UserRemoveArgs = { user : Principal; department : ?Text };
  public type UserSetStatusArgs = {
    status : MemberStatus;
    user : Principal;
    department : ?Text;
  };
  /// The ICRC-3 generic value, for structured data whose shape the model leaves open.
  public type Value = {
    #Int : Int;
    #Map : [(Text, Value)];
    #Nat : Nat;
    #Blob : Blob;
    #Text : Text;
    #Array : [Value];
  };
  public type Verdict = {
    id : Text;
    status : VerdictStatus;
    decision : Text;
    issued_at : ?Timestamp;
    issued_by : Text;
    contract : ?Text;
    case_ : Text;
    reasoning_ref : ?Text;
  };
  public type VerdictContractArgs = { contract : Text; verdict : Text };
  public type VerdictDraftArgs = {
    decision : Text;
    case_ : Text;
    reasoning_ref : ?Text;
    penalties : [PenaltyTerms];
  };
  public type VerdictStatus = { #Draft; #Final; #Overturned; #Issued };
  /// New penalties replace them all. Changing an issued verdict restarts its appeal window.
  public type VerdictTermsArgs = {
    decision : ?Text;
    verdict : Text;
    reasoning_ref : ?Text;
    penalties : ?[PenaltyTerms];
  };
  public type Vote = {
    id : Text;
    voter : Principal;
    cast_at : Timestamp;
    cast_by : ?Principal;
    proposal : Text;
    choice : VoteChoice;
  };
  public type VoteChoice = { #No; #Yes; #Abstain };
  public type WrappedKey = { principal : Principal; wrapped_dek : Blob };
  public type Zone = {
    id : Text;
    metadata : Value;
    kind : Text;
    land : ?Text;
    name : Text;
    user : ?Principal;
  };
  public type ZoneClearArgs = { zone : Text; on_behalf_of : ?Principal };
  /// An h3 cell as the caller's home; it replaces the previous one.
  public type ZoneSetArgs = {
    kind : ?Text;
    name : ?Text;
    zone : Text;
    on_behalf_of : ?Principal;
  };
  public type Self = actor {
    ggg_allocation_rule_draft : shared AllocationRuleDraftArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_allocation_rule_propose : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_appeal_decide : shared AppealDecideArgs -> async {
        #Ok : Appeal;
        #Err : GggError;
      };
    ggg_appeal_file : shared AppealFileArgs -> async {
        #Ok : Appeal;
        #Err : GggError;
      };
    ggg_appoint : shared AppointArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_appoint_acting : shared AppointArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_appointment_end : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_authority_grant : shared AuthorityGrantArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_authority_revoke : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_bid_score : shared BidScoreArgs -> async { #Ok : Bid; #Err : GggError };
    ggg_bid_submit : shared BidSubmitArgs -> async {
        #Ok : Bid;
        #Err : GggError;
      };
    ggg_bid_withdraw : shared BidWithdrawArgs -> async {
        #Ok : Bid;
        #Err : GggError;
      };
    ggg_bids_reveal : shared BidsRevealArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_budget_amend : shared BudgetAmendArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_budget_draft : shared BudgetDraftArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_budget_propose : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_case_assign : shared CaseAssignArgs -> async {
        #Ok : Case;
        #Err : GggError;
      };
    ggg_codex_install : shared CodexSource -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_codex_revert : shared () -> async { #Ok : Governed; #Err : GggError };
    /// §11
    ggg_codex_status : shared query ListArgs -> async {
        #Ok : CodexView;
        #Err : GggError;
      };
    ggg_codex_uninstall : shared () -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_contract_create : shared ContractCreateArgs -> async {
        #Ok : Contract;
        #Err : GggError;
      };
    ggg_contract_terminate : shared Text -> async {
        #Ok : Contract;
        #Err : GggError;
      };
    ggg_court_create : shared CourtCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_credential_issue : shared CredentialIssueArgs -> async {
        #Ok : CredentialIssued;
        #Err : GggError;
      };
    ggg_credential_revoke : shared CredentialRevokeArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_credential_verify : shared query CredentialVerifyArgs -> async {
        #Ok : CredentialCheck;
        #Err : GggError;
      };
    ggg_crypto_access : shared query AccessArgs -> async {
        #Ok : PrincipalPage;
        #Err : GggError;
      };
    ggg_crypto_derive_key : shared Blob -> async {
        #Ok : Blob;
        #Err : GggError;
      };
    /// §13
    ggg_crypto_envelope : shared query Text -> async {
        #Ok : ?KeyEnvelope;
        #Err : GggError;
      };
    ggg_crypto_grant : shared KeyGrantArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_crypto_public_key : shared () -> async { #Ok : Blob; #Err : GggError };
    ggg_crypto_revoke : shared KeyRevokeArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_crypto_scopes : shared query ListArgs -> async {
        #Ok : ScopePage;
        #Err : GggError;
      };
    ggg_delegable_operations : shared query () -> async {
        #Ok : [DelegableOperation];
        #Err : GggError;
      };
    ggg_delegation_accept : shared Text -> async {
        #Ok : Delegation;
        #Err : GggError;
      };
    ggg_delegation_grant : shared DelegationGrantArgs -> async {
        #Ok : Delegation;
        #Err : GggError;
      };
    ggg_delegation_list : shared query DelegationListArgs -> async {
        #Ok : DelegationPage;
        #Err : GggError;
      };
    ggg_delegation_request : shared DelegationRequestArgs -> async {
        #Ok : DelegationRequest;
        #Err : GggError;
      };
    ggg_delegation_request_decide : shared DelegationDecideArgs -> async {
        #Ok : ?Delegation;
        #Err : GggError;
      };
    ggg_delegation_revoke : shared Text -> async {
        #Ok : Delegation;
        #Err : GggError;
      };
    ggg_department_chart : shared query ChartArgs -> async {
        #Ok : Chart;
        #Err : GggError;
      };
    ggg_department_create : shared DepartmentCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_department_delete : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_department_edit : shared DepartmentEditArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_department_expel : shared ExpelArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    /// §3
    ggg_department_get : shared query GetArgs -> async {
        #Ok : ?DepartmentDetail;
        #Err : GggError;
      };
    ggg_department_list : shared query ListArgs -> async {
        #Ok : DepartmentPage;
        #Err : GggError;
      };
    ggg_department_set_policy : shared DepartmentPolicyArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_dispute_accept : shared DisputeAcceptArgs -> async {
        #Ok : Case;
        #Err : GggError;
      };
    ggg_dispute_file : shared DisputeFileArgs -> async {
        #Ok : Dispute;
        #Err : GggError;
      };
    /// §8
    ggg_dispute_get : shared query DisputeGetArgs -> async {
        #Ok : ?Dispute;
        #Err : GggError;
      };
    ggg_dispute_list_all : shared query DisputeListArgs -> async {
        #Ok : DisputePage;
        #Err : GggError;
      };
    ggg_dispute_reject : shared Text -> async {
        #Ok : Dispute;
        #Err : GggError;
      };
    ggg_dispute_withdraw : shared DisputeWithdrawArgs -> async {
        #Ok : Dispute;
        #Err : GggError;
      };
    ggg_document_delete : shared DocumentDeleteArgs -> async {
        #Ok : DocumentDeleted;
        #Err : GggError;
      };
    ggg_document_get : shared query Text -> async {
        #Ok : ?DocumentAccess;
        #Err : GggError;
      };
    ggg_document_list : shared query DocumentListArgs -> async {
        #Ok : DocumentPage;
        #Err : GggError;
      };
    ggg_document_revoke : shared DocumentRevokeArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_document_share : shared DocumentShareArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_document_store : shared DocumentStoreArgs -> async {
        #Ok : DocumentStored;
        #Err : GggError;
      };
    ggg_enforcement_escalate : shared EnforcementArgs -> async {
        #Ok : Notification;
        #Err : GggError;
      };
    ggg_enforcement_notify : shared EnforcementNotifyArgs -> async {
        #Ok : Notification;
        #Err : GggError;
      };
    ggg_enforcement_record : shared EnforcementArgs -> async {
        #Ok : Event;
        #Err : GggError;
      };
    ggg_events : shared query ListArgs -> async {
        #Ok : EventPage;
        #Err : GggError;
      };
    ggg_evidence_evaluate : shared EvidenceEvaluateArgs -> async {
        #Ok : Bool;
        #Err : GggError;
      };
    ggg_evidence_submit : shared EvidenceSubmitArgs -> async {
        #Ok : Text;
        #Err : GggError;
      };
    ggg_federal_vote_cancel : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_federal_vote_finalize : shared Text -> async {
        #Ok : FederalVote;
        #Err : GggError;
      };
    ggg_federal_vote_propose : shared FederalVoteProposeArgs -> async {
        #Ok : FederalVote;
        #Err : GggError;
      };
    ggg_federation_message : shared FederationMessageArgs -> async {
        #Ok : ?Value;
        #Err : GggError;
      };
    ggg_fund_create : shared FundCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_governance_update : shared GovernanceUpdateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_identity_review : shared IdentityReviewArgs -> async {
        #Ok : Identity;
        #Err : GggError;
      };
    ggg_identity_submit : shared IdentitySubmitArgs -> async {
        #Ok : Identity;
        #Err : GggError;
      };
    ggg_invite_create : shared InviteCreateArgs -> async {
        #Ok : InviteCreated;
        #Err : GggError;
      };
    ggg_invite_list : shared query ListArgs -> async {
        #Ok : InvitePage;
        #Err : GggError;
      };
    ggg_invite_revoke : shared Text -> async { #Ok : Invite; #Err : GggError };
    ggg_invoice_check : shared InvoiceCheckArgs -> async {
        #Ok : Invoice;
        #Err : GggError;
      };
    ggg_invoice_create : shared InvoiceCreateArgs -> async {
        #Ok : InvoiceCreated;
        #Err : GggError;
      };
    ggg_invoice_refresh : shared InvoiceRefreshArgs -> async {
        #Ok : InvoicePage;
        #Err : GggError;
      };
    ggg_judge_appoint : shared JudgeAppointArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_judge_revoke : shared Text -> async { #Ok : Governed; #Err : GggError };
    ggg_land_freeze : shared LandFreezeArgs -> async {
        #Ok : Land;
        #Err : GggError;
      };
    /// §6
    ggg_land_list : shared query LandListArgs -> async {
        #Ok : LandPage;
        #Err : GggError;
      };
    ggg_land_map : shared query LandMapArgs -> async {
        #Ok : LandMap;
        #Err : GggError;
      };
    ggg_land_mint_nft : shared LandMintArgs -> async {
        #Ok : Nat;
        #Err : GggError;
      };
    ggg_land_register : shared LandRegisterArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_land_transfer : shared LandTransferArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_land_unfreeze : shared Text -> async { #Ok : Land; #Err : GggError };
    ggg_ledger_view : shared query LedgerArgs -> async {
        #Ok : LedgerPage;
        #Err : GggError;
      };
    ggg_license_apply : shared LicenseApplyArgs -> async {
        #Ok : License;
        #Err : GggError;
      };
    ggg_license_decide : shared LicenseDecideArgs -> async {
        #Ok : License;
        #Err : GggError;
      };
    /// §7
    ggg_license_list : shared query LicenseListArgs -> async {
        #Ok : LicensePage;
        #Err : GggError;
      };
    ggg_license_renew : shared LicenseRenewArgs -> async {
        #Ok : License;
        #Err : GggError;
      };
    ggg_license_revoke : shared Text -> async {
        #Ok : License;
        #Err : GggError;
      };
    ggg_license_suspend : shared LicenseSuspendArgs -> async {
        #Ok : License;
        #Err : GggError;
      };
    ggg_license_verify : shared query LicenseVerifyArgs -> async {
        #Ok : LicenseCheck;
        #Err : GggError;
      };
    ggg_mandate_assign_executor : shared MandateExecutorArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_mandate_create : shared MandateCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_mandate_revoke : shared MandateRevokeArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_nft_token_register : shared NFTTokenRegisterArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_notification_list : shared query NotificationListArgs -> async {
        #Ok : NotificationPage;
        #Err : GggError;
      };
    ggg_notification_read : shared NotificationReadArgs -> async {
        #Ok : NotificationsRead;
        #Err : GggError;
      };
    ggg_notification_send : shared NotificationSendArgs -> async {
        #Ok : Notification;
        #Err : GggError;
      };
    ggg_organization_edit : shared OrganizationEditArgs -> async {
        #Ok : Organization;
        #Err : GggError;
      };
    ggg_organization_get : shared query GetArgs -> async {
        #Ok : ?OrganizationDetail;
        #Err : GggError;
      };
    ggg_organization_list : shared query OrganizationListArgs -> async {
        #Ok : OrganizationPage;
        #Err : GggError;
      };
    ggg_organization_register : shared OrganizationRegisterArgs -> async {
        #Ok : Organization;
        #Err : GggError;
      };
    ggg_organization_set_status : shared OrganizationStatusArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_payment_account_add : shared PaymentAccountAddArgs -> async {
        #Ok : PaymentAccount;
        #Err : GggError;
      };
    ggg_payment_account_remove : shared PaymentAccountRemoveArgs -> async {
        #Ok : PaymentAccount;
        #Err : GggError;
      };
    ggg_payroll_run : shared PayrollRunArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_penalty_execute : shared PenaltyExecuteArgs -> async {
        #Ok : Penalty;
        #Err : GggError;
      };
    ggg_period_close : shared Text -> async { #Ok : Governed; #Err : GggError };
    ggg_period_open : shared PeriodOpenArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_position_close : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_position_create : shared PositionCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_position_edit : shared PositionEditArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_private_data_update : shared Blob -> async {
        #Ok : User;
        #Err : GggError;
      };
    ggg_profile_create : shared ProfileCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_profile_edit : shared ProfileEditArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_profile_update : shared ProfileUpdateArgs -> async {
        #Ok : User;
        #Err : GggError;
      };
    ggg_proposal_create : shared ProposalCreateArgs -> async {
        #Ok : Text;
        #Err : GggError;
      };
    ggg_proposal_execute : shared Text -> async {
        #Ok : Proposal;
        #Err : GggError;
      };
    ggg_proposal_finalize : shared Text -> async {
        #Ok : Proposal;
        #Err : GggError;
      };
    /// §4
    ggg_proposal_get : shared query GetArgs -> async {
        #Ok : ?ProposalDetail;
        #Err : GggError;
      };
    ggg_proposal_list : shared query ProposalListArgs -> async {
        #Ok : ProposalPage;
        #Err : GggError;
      };
    ggg_proposal_open : shared Text -> async {
        #Ok : Proposal;
        #Err : GggError;
      };
    ggg_proposal_vote : shared ProposalVoteArgs -> async {
        #Ok : Vote;
        #Err : GggError;
      };
    ggg_proposal_withdraw : shared ProposalWithdrawArgs -> async {
        #Ok : Proposal;
        #Err : GggError;
      };
    ggg_quarter_configure : shared QuarterConfigureArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_quarter_deregister : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    /// §10
    ggg_quarter_directory : shared query ListArgs -> async {
        #Ok : QuarterDirectory;
        #Err : GggError;
      };
    ggg_quarter_join_federation : shared JoinFederationArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_quarter_register : shared QuarterRegisterArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_quarter_secede : shared () -> async { #Ok : Governed; #Err : GggError };
    ggg_realm_configure : shared RealmConfigureArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_realm_configure_branding : shared BrandingArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_realm_configure_tokens : shared TokensArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_realm_configure_trust_policy : shared TrustPolicyArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    /// §12
    ggg_realm_info : shared query () -> async Realm;
    ggg_realm_join : shared JoinArgs -> async {
        #Ok : UserEntry;
        #Err : GggError;
      };
    ggg_realm_register : shared RealmRegisterArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_realm_upgrade : shared RealmUpgradeArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_report_issue : shared ReportIssueArgs -> async {
        #Ok : FinancialReport;
        #Err : GggError;
      };
    ggg_report_view : shared query ReportArgs -> async {
        #Ok : ReportPage;
        #Err : GggError;
      };
    ggg_representative_add : shared RepresentativeAddArgs -> async {
        #Ok : Appointment;
        #Err : GggError;
      };
    ggg_representative_remove : shared Text -> async {
        #Ok : Appointment;
        #Err : GggError;
      };
    ggg_resolution_query : shared query ResolutionQueryArgs -> async {
        #Ok : ResolutionPage;
        #Err : GggError;
      };
    ggg_role_assign : shared RoleArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_role_revoke : shared RoleArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_self_change_quarter : shared ChangeQuarterArgs -> async {
        #Ok : Forward;
        #Err : GggError;
      };
    ggg_setup_launch : shared () -> async { #Ok : Realm; #Err : GggError };
    ggg_setup_state : shared () -> async { #Ok : SetupState; #Err : GggError };
    ggg_setup_step : shared SetupStep -> async {
        #Ok : SetupState;
        #Err : GggError;
      };
    ggg_tax_assess : shared TaxAssessArgs -> async {
        #Ok : TaxAssessPage;
        #Err : GggError;
      };
    ggg_tax_declare : shared TaxDeclareArgs -> async {
        #Ok : TaxDeclared;
        #Err : GggError;
      };
    ggg_tax_policy_draft : shared TaxPolicyDraftArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_tax_policy_propose : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_tender_award : shared TenderAwardArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_tender_cancel : shared Text -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_tender_close : shared Text -> async { #Ok : Governed; #Err : GggError };
    ggg_tender_create : shared TenderCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_tender_get : shared query GetArgs -> async {
        #Ok : ?TenderDetail;
        #Err : GggError;
      };
    /// §9
    ggg_tender_list : shared query TenderListArgs -> async {
        #Ok : TenderPage;
        #Err : GggError;
      };
    ggg_tender_open : shared Text -> async { #Ok : Governed; #Err : GggError };
    ggg_token_force_transfer : shared ForceTransferArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_token_freeze : shared FreezeArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_token_register : shared TokenRegisterArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_transfer_create : shared TransferCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_transfer_revert : shared TransferRevertArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_treasury_configure : shared TreasuryConfigureArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    /// §5
    ggg_treasury_view : shared query ListArgs -> async {
        #Ok : TreasuryView;
        #Err : GggError;
      };
    ggg_user_add : shared UserAddArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_user_edit : shared UserEditArgs -> async {
        #Ok : User;
        #Err : GggError;
      };
    /// §2
    ggg_user_get : shared query Principal -> async {
        #Ok : ?UserEntry;
        #Err : GggError;
      };
    ggg_user_import : shared UserImportArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_user_list : shared query ListArgs -> async {
        #Ok : UserPage;
        #Err : GggError;
      };
    ggg_user_remove : shared UserRemoveArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_user_set_status : shared UserSetStatusArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_verdict_draft : shared VerdictDraftArgs -> async {
        #Ok : Verdict;
        #Err : GggError;
      };
    ggg_verdict_finalize : shared Text -> async {
        #Ok : Verdict;
        #Err : GggError;
      };
    ggg_verdict_issue : shared Text -> async { #Ok : Verdict; #Err : GggError };
    ggg_verdict_link_contract : shared VerdictContractArgs -> async {
        #Ok : Verdict;
        #Err : GggError;
      };
    ggg_verdict_modify_terms : shared VerdictTermsArgs -> async {
        #Ok : Verdict;
        #Err : GggError;
      };
    ggg_zone_clear : shared ZoneClearArgs -> async {
        #Ok : Zone;
        #Err : GggError;
      };
    ggg_zone_set : shared ZoneSetArgs -> async { #Ok : Zone; #Err : GggError };
    icrc10_supported_standards : shared query () -> async [
        { url : Text; name : Text }
      ];
  }
}
