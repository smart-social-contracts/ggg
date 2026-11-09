// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module {
  public type AccessArgs = { cursor : ?Text; limit : ?Nat32; scope : Text };
  /// An ICRC-1 account.
  public type Account = { owner : Principal; subaccount : ?Blob };
  /// The grantor's own act: never under a grant, so `on_behalf_of` is refused.
  public type ActionApproveArgs = {
    action : Text;
    hash : Text;
    on_behalf_of : ?Principal;
  };
  public type ActionDeclineArgs = { action : Text; on_behalf_of : ?Principal };
  public type ActionListArgs = {
    status : ?PendingActionStatus;
    cursor : ?Text;
    role : { #Delegate; #Grantor };
    limit : ?Nat32;
  };
  /// AllocationRule and TaxPolicy.
  public type AdoptionStatus = { #Superseded; #Draft; #Proposed; #Adopted };
  public type Allocation = { fund : Text; share : Ratio };
  public type AllocationRule = {
    id : Text;
    status : AdoptionStatus;
    source_fund : Text;
    proposal : ?Text;
    rules : [Allocation];
  };
  /// Shares add up to at most 100 000 000 (100 %).
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
  /// An area in square metres.
  public type Area = Nat;
  /// A certified attribute of a person: a status another body certifies and the realm verifies, as it
  /// verifies identities, such as a disability, a family status or being a student. The kinds and their
  /// values are legislation's; GGG records the attestation. `kind` and `value` are in clear, and readable
  /// only by the person, by the holders of attribute.review while it awaits review and by the codex
  /// (I-PRV-1); the audit log never holds them.
  public type Attribute = {
    id : Text;
    ref : Text;
    status : AttributeStatus;
    human : Text;
    value : Text;
    kind : Text;
    issuer : Text;
    verified_at : ?Timestamp;
    expires_at : ?Timestamp;
  };
  /// The caller's own attributes, of one kind or all.
  public type AttributeListArgs = {
    cursor : ?Text;
    kind : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
  };
  public type AttributePage = { next : ?Text; items : [Attribute] };
  public type AttributeReviewArgs = {
    status : { #Rejected; #Verified };
    attribute : Text;
  };
  public type AttributeStatus = { #Rejected; #Verified; #Pending };
  /// For the caller's own person. `ref` points to the proof, stored encrypted or off-chain.
  public type AttributeSubmitArgs = {
    ref : Text;
    value : Text;
    kind : Text;
    issuer : ?Text;
    expires_at : ?Timestamp;
  };
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
  public type Balance = { amount : Money; symbol : Text };
  public type Bid = {
    id : Text;
    sealed : Bool;
    score : ?Nat;
    vendor : Text;
    payload_ref : Text;
    price : ?Money;
    tender : Text;
    submitted_at : Timestamp;
    payload_hash : Text;
  };
  public type BidOpening = { bid : Text; nonce : Text; price : Money };
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
    actual : Money;
    period : Text;
    fund : Text;
    kind : BudgetKind;
    planned : Money;
    category : Text;
    proposal : ?Text;
  };
  public type BudgetAmendArgs = { planned : Money; budget : Text };
  /// `category` never names `ledger_fee`, which the GOS books itself (InvalidArgument).
  public type BudgetDraftArgs = {
    period : Text;
    fund : Text;
    kind : BudgetKind;
    planned : Money;
    category : Text;
  };
  /// Whether a line plans money coming in or going out; `category` is the realm's word for what.
  public type BudgetKind = { #Revenue; #Expense };
  /// Proposes the draft lines of the period together: those of `fund`, under its owner's policy, or every
  /// fund's, under the root's; they are `proposed` from the filing, by this call or by any proposal that
  /// carries it, the execution adopts exactly them, and a proposal that ends otherwise returns them to Draft.
  /// `years` is how many periods the plan covers, when more than one. Legislation reads the totals of the
  /// lines it proposes, `revenue` and `expense` (the sums of `planned` over their Revenue and Expense lines;
  /// `fund` tells the two forms apart), as facts of the call; a total out of Money's range is
  /// InvalidArgument, like any other fact.
  public type BudgetProposeArgs = { period : Text; fund : ?Text; years : ?Nat };
  /// Proposed: filed with a proposal, which adopts exactly these lines. Extended: copied, fund by fund,
  /// from the previous period's adopted budget by budget_extend, in force until an adopted budget of that
  /// fund replaces it.
  public type BudgetStatus = {
    #Closed;
    #Draft;
    #Proposed;
    #Amended;
    #Extended;
    #Adopted;
  };
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
  /// Pending actions (model §2): a call in its confirm form, prepared by a delegate under a grant and waiting
  /// for the grantor's own approval.
  public type Call = { arg : Blob; method : Text };
  /// One call on a grantor's behalf: `arg` is Candid-encoded with the method's own argument type. A confirm
  /// operation files a pending action; a direct one runs, or files the proposal a governed call files.
  public type CallForArgs = {
    arg : Blob;
    method : Text;
    note : ?Text;
    on_behalf_of : Principal;
  };
  public type CallForReply = {
    #Done : Blob;
    #Proposed : Text;
    #Pending : PendingAction;
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
  public type ChangeQuarterArgs = { quarter : Text };
  /// A chapter of a release: the domain it writes and the checksum of its bytes.
  public type ChapterRef = { domain : Text; checksum : Text };
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
  /// `codex` is the pending codex's checksum (at most one codex is pending at a time). `at` defaults to now;
  /// a time ahead schedules the activation.
  public type CodexActivateArgs = { at : ?Timestamp; codex : Text };
  /// The checksum of a codex in the realm's history to restore; absent means the one the active codex
  /// replaced.
  public type CodexRevertArgs = { codex : ?Text };
  public type CodexSource = {
    #Package : { source : Text; manifest : Value };
    /// A release of a layer, found in the record of one of the realm's active sync sources.
    #Release : { source : Text; version : Text };
    #Registry : { codex : Text; version : Text };
  };
  /// Pending: installed and checked, waiting for codex_activate or its proposal's effective_at.
  public type CodexStatus = { #Inactive; #Active; #Reverted; #Pending };
  /// The active codex and a page of earlier ones, each named by its checksum ("sha256:<hex>").
  /// No method returns a Codex record.
  public type CodexView = {
    /// A codex installed and waiting to be activated, by its checksum.
    pending : ?Text;
    signing : SigningPolicy;
    next : ?Text;
    history : [Text];
    healthy : Bool;
    checksum : ?Text;
  };
  /// Compliant: every layer the realm runs is at least the latest release in effect in the source's
  /// record. NonCompliant since the date of the earliest release it misses, naming the `stale` layers by
  /// source id. Unknown: the record could not be read.
  public type Compliance = {
    #NonCompliant : { since : Timestamp; stale : [Text] };
    #Unknown;
    #Compliant;
  };
  public type Contract = {
    id : Text;
    status : ContractStatus;
    title : Text;
    mandate : ?Text;
    starts_at : ?Timestamp;
    value : Money;
    ends_at : ?Timestamp;
    /// What is contracted (works, supplies, services), by which procedure, and the tender it came from, which
    /// gave it its kind and procedure.
    kind : ?Text;
    terms_hash : Text;
    terms_ref : Text;
    procedure : ?Text;
    tender : ?Text;
    parties : [Ref];
    symbol : Text;
  };
  public type ContractCreateArgs = {
    title : Text;
    mandate : ?Text;
    starts_at : ?Timestamp;
    value : Money;
    ends_at : ?Timestamp;
    kind : ?Text;
    terms_hash : Text;
    terms_ref : Text;
    procedure : ?Text;
    tender : ?Text;
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
  public type Criterion = { weight : Ratio; criterion : Text };
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
  /// The events recorded under one grant, newest first, to its grantor or its delegate.
  public type DelegationActivityArgs = {
    delegation : Text;
    cursor : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
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
  /// One group a grant may name, as delegation.json defines it, with the caller's operations in it. `id` is
  /// the group's, or `office:<department>` and `orgs:<organization>` for a group with a parameter; `longest`
  /// is how long a grant of it may last; `confirms` says whether some of its operations ask each time.
  public type DelegationGroup = {
    id : Text;
    confirms : Bool;
    risk : Text;
    label_ : Text;
    summary : Text;
    longest : Duration;
    operations : [TieredOperation];
  };
  public type DelegationGroupPage = { next : ?Text; items : [DelegationGroup] };
  public type DelegationGroupsArgs = {
    cursor : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
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
  /// Revokes every pending or active grant the caller gave, `limit` at a time: call again with `next` until
  /// it is absent. The member's own act: with `on_behalf_of` it is Forbidden.
  public type DelegationRevokeAllArgs = {
    cursor : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
  };
  public type DelegationStatus = {
    #Active;
    #Declined;
    #Revoked;
    #Expired;
    #Pending;
  };
  /// An operation's tier under power of attorney (delegation.json): Direct runs at once under a grant that
  /// names its group, Confirm asks the grantor each time. `confirm_if` is the condition under which a Direct
  /// operation asks instead.
  public type DelegationTier = { #Confirm; #Direct };
  public type DelegationsRevoked = { revoked : Nat; next : ?Text };
  public type Delivery = { #Notification : Notification; #Dispatch : Dispatch };
  public type Department = {
    id : Text;
    is_root : Bool;
    fund : ?Text;
    head : ?Principal;
    /// What kind of body it is, such as the realm's plenary, so legislation from a source above can name the
    /// kind without naming the department.
    kind : ?Text;
    description : Text;
    target_policy : ?Policy;
    parent : ?Text;
    policy : Policy;
  };
  public type DepartmentCreateArgs = {
    kind : ?Text;
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
    kind : ?Text;
    description : ?Text;
    department : Text;
    parent : ?Text;
  };
  public type DepartmentPage = { next : ?Text; items : [Department] };
  public type DepartmentPolicyArgs = { department : Text; policy : Policy };
  /// One notice to an External, queued by the realm and confirmed by whoever delivered it. `document` is
  /// the document it carries, `codex` the codex it concerns, when either applies. A `body` that holds
  /// personal data carries a Document reference, encrypted, not text in clear.
  public type Dispatch = {
    id : Text;
    to : Text;
    status : DispatchStatus;
    title : Text;
    topic : Text;
    body : Value;
    codex : ?Text;
    document : ?Text;
    queued_at : Timestamp;
  };
  /// A dispatch takes one outcome; a second is Conflict.
  public type DispatchConfirmArgs = {
    dispatch : Text;
    outcome : DispatchOutcome;
  };
  public type DispatchListArgs = {
    to : ?Text;
    status : ?{ #Queued; #Failed; #Confirmed };
    cursor : ?Text;
    limit : ?Nat32;
  };
  /// How the delivery went: Confirmed with when (`at` defaults to now, and lies between the dispatch's
  /// `queued_at` and now) and the receipt that proves it, or Failed with the reason.
  public type DispatchOutcome = {
    #Failed : Text;
    #Confirmed : { at : ?Timestamp; receipt : ?Text };
  };
  public type DispatchPage = { next : ?Text; items : [Dispatch] };
  public type DispatchStatus = {
    #Queued;
    #Failed : Text;
    /// When it was delivered, and the receipt that proves it (a bulletin number, a filing reference).
    #Confirmed : { at : Timestamp; receipt : ?Text };
  };
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
    /// What the document is (minutes, an ordinance, an award), and the BCP 47 tags of its languages.
    kind : ?Text;
    languages : [Text];
    /// Published to everyone: the content in clear, readable without signing in.
    public_ : ?Published;
    author : Principal;
    publications : [Publication];
    department : Text;
    /// What legislation reads about the document when it is shared, such as its source and whether it was
    /// given freely.
    facts : Value;
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
    kind : ?Text;
    limit : ?Nat32;
    language : ?Text;
    department : Text;
  };
  public type DocumentPage = { next : ?Text; items : [Document] };
  /// Publishes the content in clear at `ref`, with its `hash`: the document becomes public. With an External
  /// journal in `to`, a Dispatch to it is queued too.
  public type DocumentPublishArgs = {
    to : ?Text;
    ref : Text;
    hash : Text;
    document : Text;
  };
  public type DocumentRevokeArgs = {
    document : Text;
    principals : [Principal];
  };
  /// `recipient` is whom the keys are for: a User, an Organization or an External. `facts` is what
  /// legislation reads about this share beyond the basis.
  public type DocumentShareArgs = {
    keys : [WrappedKey];
    recipient : Ref;
    document : Text;
    basis : ?ShareBasis;
    facts : ?Value;
  };
  /// Stores a new document, or replaces `document`.
  public type DocumentStoreArgs = {
    ref : Text;
    title : Text;
    hash : Text;
    keys : [WrappedKey];
    kind : ?Text;
    languages : [Text];
    document : ?Text;
    department : Text;
    facts : ?Value;
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
    /// The delegate that prepared the act, when the member approved it from a pending action (origin `confirmed`).
    prepared_by : ?Principal;
    supervisor : ?Principal;
    result : Value;
    agent : Bool;
    args : Value;
    origin : Text;
    user : ?Principal;
    /// The grant a delegated act ran under.
    grant : ?Text;
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
  /// A body outside the realm and outside the Internet Computer: an authority, a journal, a lender, a
  /// bank. `channel` is how a dispatch reaches it: `manual` (an operator delivers it) or an https URL (a
  /// bridge does).
  public type External = {
    id : Text;
    kind : Text;
    name : Text;
    channel : Text;
  };
  /// A second external_add of the same id redefines the body.
  public type ExternalAddArgs = {
    kind : Text;
    name : Text;
    channel : Text;
    external : Text;
  };
  public type ExternalPage = { next : ?Text; items : [External] };
  /// A report that reached the realm from an External, entered by whoever received it, with the file as
  /// evidence. It is audited as an Event, which legislation hooks.
  public type ExternalReportArgs = {
    evidence_ref : ?Text;
    topic : Text;
    body : Value;
    external : Text;
  };
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
  /// On a sync source: a realm that syncs from it, `id` its capital as text, with its link status and
  /// its last report.
  public type Follower = {
    id : Text;
    status : LinkStatus;
    compliance : Compliance;
    layers : [ReportedLayer];
    capital : Principal;
    reported_at : ?Timestamp;
    population : Nat;
  };
  public type FollowerArgs = { follower : Principal };
  public type FollowerPage = { next : ?Text; items : [Follower] };
  /// What a follower's capital reports to a sync source, its own claims: the layers it runs, its
  /// compliance against that source and its population. The source matches a layer by its checksum.
  public type FollowerReportArgs = {
    compliance : Compliance;
    layers : [ReportedLayer];
    population : Nat;
  };
  /// By court order.
  public type ForceTransferArgs = {
    to : Principal;
    from : Principal;
    amount : Money;
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
  /// `casting_vote` names an active member, else InvalidArgument.
  public type GovernanceUpdateArgs = {
    voting_window : ?Duration;
    casting_vote : ?{ #Set : Principal; #Clear };
    voting_quorum : ?Ratio;
    voting_threshold : ?Ratio;
  };
  /// The change was applied, with the id of any record it created, or a proposal was filed to make it.
  public type Governed = { #Done : ?Text; #Proposed : Text };
  public type GuestUser = {
    id : Principal;
    permissions : [Text];
    home_quarter : Text;
  };
  /// The canisters a realm works with. Ones only some GOS use go in `extra`, named "<gos>:<role>"
  /// ("realms_gos:baton").
  public type HostInfrastructure = {
    file_registry : ?Principal;
    frontend : ?Principal;
    extra : [(Text, Principal)];
  };
  /// What the platform that installs a realm (its host: an installer, a registry) tells it, once.
  public type HostInstallArgs = {
    /// Whether test features may be turned on.
    test_mode : Bool;
    /// Where it runs: "ic", "staging", "local".
    network : Text;
    /// Configures the realm until it launches.
    founder : Principal;
    /// The realm registry that lists it, if the host has one.
    registry : ?Principal;
  };
  public type Human = {
    id : Text;
    h3_index : ?Text;
    user : Principal;
    date_of_birth : ?Timestamp;
  };
  /// Standard kinds: `national_id`, `passport`, `residence_permit`, `driver_license`; a realm may add its own.
  /// The issuer of a national id or passport is the country, so it says the nationality.
  public type Identity = {
    id : Text;
    ref : Text;
    status : IdentityStatus;
    human : Text;
    kind : Text;
    issuer : Text;
    verified_at : ?Timestamp;
    /// A subdivision of the kind, such as a long-term residence permit.
    category : ?Text;
    expires_at : ?Timestamp;
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
    category : ?Text;
    expires_at : ?Timestamp;
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
    /// The items sum to `amount`. `facts` is what legislation reads about the invoice beyond its items.
    items : [InvoiceItem];
    amount : Money;
    payment : ?Value;
    symbol : Text;
    facts : Value;
    reason : ?Ref;
  };
  public type InvoiceCheckArgs = { invoice : Text; on_behalf_of : ?Principal };
  /// At least one item, and the items sum to `amount` (InvalidArgument otherwise).
  public type InvoiceCreateArgs = {
    due_at : ?Timestamp;
    payer : Ref;
    items : [InvoiceItem];
    amount : Money;
    symbol : ?Text;
    facts : ?Value;
    reason : ?Ref;
  };
  /// The invoice, and the account to pay it into.
  public type InvoiceCreated = { invoice : Invoice; pay_to : Account };
  /// One line of an invoice. A negative amount is a discount or bonus. `quantity` is in the line's `unit`
  /// (`m3`, `h`, a count when absent). `legislation` is the provision that charges it.
  public type InvoiceItem = {
    concept : Text;
    unit : ?Text;
    legislation : ?Text;
    quantity : ?Nat;
    amount : SignedMoney;
  };
  /// Adds a line to a pending invoice and raises (or, for a negative amount, lowers) its amount by the
  /// line's; Conflict once the invoice is paid, overdue or cancelled, InvalidArgument below zero.
  public type InvoiceItemAddArgs = { invoice : Text; item : InvoiceItem };
  public type InvoicePage = { next : ?Text; items : [Invoice] };
  /// One invoice, or a batch of the pending and overdue ones (at most 20 per call).
  public type InvoiceRefreshArgs = {
    cursor : ?Text;
    invoice : ?Text;
    limit : ?Nat32;
  };
  public type InvoiceStatus = { #Paid; #Overdue; #Cancelled; #Pending };
  /// `home_zone` names a zone the realm defined; an unknown zone, or a member's home cell, is InvalidArgument.
  public type JoinArgs = {
    nickname : ?Text;
    code : ?Text;
    language : ?Text;
    home_zone : ?Text;
  };
  public type JoinFederationArgs = { name : ?Text; capital : Principal };
  /// The least-populated active quarter a new member joins, and every quarter that takes joins.
  public type JoinTargets = { mode : ?Text; targets : [Text]; default : ?Text };
  /// The zone a joiner states as their home, which a codex may use to keep neighbours together; it places them and
  /// nothing else.
  public type JoinTargetsArgs = { home_zone : ?Text };
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
    area : ?Area;
    kind : Text;
    assessment_ref : ?Text;
    /// What an assessor set for taxes based on the parcel, its value in the accounting currency and its area
    /// in square metres, when, and under which reference in the assessor's register.
    assessed_value : ?Money;
    assessed_at : ?Timestamp;
    width : Nat;
    registered_by : Principal;
  };
  /// What the assessor sets, signing for it; a field left absent keeps its value. `legislation` is the
  /// provision the assessment follows.
  public type LandAssessArgs = {
    value : ?Money;
    area : ?Area;
    land : Text;
    reference : ?Text;
    legislation : ?Text;
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
    credit : Money;
    appeal : ?Text;
    category : Text;
    organization : ?Text;
    debit : Money;
    transfer : ?Text;
    symbol : Text;
  };
  public type LedgerKind = { #Asset; #Liability; #Revenue; #Expense; #Equity };
  public type LedgerPage = { next : ?Text; items : [LedgerEntry] };
  /// A release of the realm's own layer. `published` is set by the realm when the publish applies.
  public type LegislationReleasePublishArgs = {
    source : Text;
    version : Text;
    calendar : ?Text;
    effective_from : Timestamp;
    chapters : [ChapterRef];
    notes : Value;
    commit : Text;
  };
  public type License = {
    id : Text;
    status : LicenseStatus;
    evidence_ref : ?Text;
    issued_at : ?Timestamp;
    issued_by : Text;
    applied_at : Timestamp;
    /// When a decision is due, from the Procedure of the licence's kind.
    decision_due : ?Timestamp;
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
  /// From the capital at the other side of a link: the link's new status after the caller's vote.
  public type LinkNotifyArgs = { status : LinkStatus; side : LinkSide };
  /// What the caller is to the receiver: its sync source, or its follower.
  public type LinkSide = { #SyncSource; #Follower };
  /// Requested: one side has voted. Active: both have. Ended: a side ended the link, `by` its capital.
  public type LinkStatus = {
    #Ended : { at : Timestamp; by : Principal };
    #Active;
    #Requested;
  };
  public type ListArgs = { cursor : ?Text; limit : ?Nat32 };
  /// Money the realm owes an outside lender, in the accounting currency (`symbol`), so that the treasury's
  /// `debt_outstanding` is one sum. The money itself moves outside the realm; GGG records the debt and its
  /// repayments.
  public type Loan = {
    id : Text;
    status : LoanStatus;
    outstanding : Money;
    fund : Text;
    rate : Rate;
    term : Period;
    lender : Text;
    amount : Money;
    symbol : Text;
    facts : Value;
  };
  /// `lender` is an External; the loan is in the accounting currency. Governed by the root department.
  public type LoanCreateArgs = {
    fund : Text;
    rate : Rate;
    term : Period;
    lender : Text;
    amount : Money;
    facts : ?Value;
  };
  public type LoanListArgs = {
    status : ?LoanStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type LoanPage = { next : ?Text; items : [Loan] };
  public type LoanRepayArgs = { loan : Text; amount : Money; reason : ?Text };
  public type LoanStatus = { #Repaid; #Active };
  public type Mandate = {
    id : Text;
    status : MandateStatus;
    title : Text;
    max_value : ?Money;
    scope : Value;
    proposal : ?Text;
    executor : ?Text;
    expires_at : ?Timestamp;
    symbol : ?Text;
  };
  /// A replayed proposal records itself as the mandate's proposal.
  public type MandateCreateArgs = {
    title : Text;
    max_value : ?Money;
    scope : Value;
    executor : ?Text;
    expires_at : ?Timestamp;
    symbol : ?Text;
  };
  public type MandateExecutorArgs = { mandate : Text; executor : Text };
  public type MandateRevokeArgs = { mandate : Text };
  public type MandateStatus = { #Active; #Revoked; #Completed; #Expired };
  public type Me = {
    member : ?Member;
    permissions : [Text];
    user : User;
    delegations : [Delegation];
    requests : [DelegationRequest];
  };
  /// The caller, their permissions, and their open delegations. Private data is omitted when delegated.
  public type MeArgs = { on_behalf_of : ?Principal };
  public type Member = {
    id : Text;
    status : MemberStatus;
    user : Principal;
    joined_at : ?Timestamp;
  };
  public type MemberStatus = { #Inactive; #Active; #Suspended; #Banned };
  /// Money in the token's smallest unit (Token.decimals). Money computed from a Ratio is rounded to the
  /// nearest cent, an exact half away from zero (model §1).
  public type Money = Nat;
  public type Monitor = {
    memory : Nat;
    status : RealmStatus;
    cycles : Nat;
    events : Nat;
    installed_version : Text;
  };
  public type MyInvoice = { invoice : Invoice; pay_to : Account };
  public type MyInvoicePage = { next : ?Text; items : [MyInvoice] };
  /// One page of the caller's invoices, each with the account to pay it into.
  public type MyInvoicesArgs = {
    cursor : ?Text;
    limit : ?Nat32;
    on_behalf_of : ?Principal;
  };
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
  /// A notice of the tender published in a journal, recorded with tender_notice.
  public type Notice = {
    ref : ?Text;
    journal : Text;
    published_at : Timestamp;
  };
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
  /// To a user, department or organization, a Notification; to an External, a Dispatch. With translations,
  /// each reader gets the one in their language, else the title and body given.
  public type NotificationSendArgs = {
    title : Text;
    topic : ?Text;
    body : ?Text;
    href : ?Text;
    recipient : Ref;
    translations : ?[Translation];
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
    organization : ?Text;
    symbol : ?Text;
  };
  public type PaymentAccountRemoveArgs = {
    account : Text;
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
    amount : ?Money;
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
    amount : ?Money;
    symbol : ?Text;
  };
  public type PendingAction = {
    id : Text;
    status : PendingActionStatus;
    /// The reply of an approved update once it ran, Candid-encoded with the method's own type, without what
    /// the event log strips: a secret it returns, such as an invite code, is in the approval's own reply alone.
    /// An approved read stores nothing: the approval authorises one run, which the delegate collects with
    /// ggg_action_collect.
    result : ?Blob;
    call : Call;
    /// Seals the record: computed by the GOS, with sha256 or a stronger hash, over at least the realm, the
    /// id, the call, the grantor, the delegate, the grant and the expiry; a client sends it back unchanged.
    hash : Text;
    note : ?Text;
    risk : Text;
    delegate : Principal;
    filed_at : Timestamp;
    grantor : Principal;
    summary : [SummaryLine];
    grant : Text;
    expires_at : Timestamp;
    decided_at : ?Timestamp;
  };
  public type PendingActionPage = { next : ?Text; items : [PendingAction] };
  /// Approved: a read the grantor approved, waiting for the delegate to collect it (ggg_action_collect).
  public type PendingActionStatus = {
    #Failed;
    #Done;
    #Void;
    #Approved;
    #Withdrawn;
    #Approving;
    #Declined;
    #Expired;
    #Pending;
  };
  public type Period = { count : Nat; unit : PeriodUnit };
  /// Periods open in order: one starts no earlier than the latest ends.
  public type PeriodOpenArgs = {
    starts_at : Timestamp;
    period : Text;
    ends_at : Timestamp;
    name : ?Text;
  };
  /// A count of calendar units: three months is three months, whatever the days. Deadlines and terms in
  /// legislation are Periods, never Durations. A WorkingDay is a day that is neither a weekend day nor a
  /// holiday in the realm's calendar, taken in the realm's time zone; GGG names the unit and the GOS
  /// counts it, failing closed when its calendar has no entries for a year the count reaches. Periods
  /// compare only within one unit: comparing two units fails closed, with no conversion through the
  /// calendar (model §1).
  public type PeriodUnit = { #Day; #Year; #WorkingDay; #Month };
  public type Permission = {
    id : Text;
    departments : [Text];
    description : Text;
    scope : ?Text;
    users : [Principal];
    category : Text;
    profiles : [Text];
  };
  /// m of n approvals.
  public type Policy = { m : Nat; n : Nat; veto : [Principal]; quorum : Ratio };
  public type Position = {
    id : Text;
    status : PositionStatus;
    title : Text;
    salary_period : ?Duration;
    salary : Money;
    headcount : Nat;
    organization : ?Text;
    department : ?Text;
    inherit_from_capital : Bool;
    profile : ?Text;
  };
  public type PositionCreateArgs = {
    title : Text;
    salary_period : ?Duration;
    salary : ?Money;
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
    salary : ?Money;
    headcount : ?Nat;
    position : Text;
    profile : ?Text;
  };
  public type PositionStatus = { #Open; #Closed; #Frozen };
  public type PrincipalPage = { next : ?Text; items : [Principal] };
  /// How a kind of application is decided: who starts it, the deadline for a decision, and what the realm's
  /// silence means. Keyed by the licence kind it governs.
  public type Procedure = {
    id : Text;
    silence : ?Silence;
    legislation : ?Text;
    decision_deadline : ?Period;
    matter : ?Text;
    initiated_by : Text;
    facts : Value;
  };
  /// Defines, or redefines, the procedure of licences of `kind`.
  public type ProcedureDefineArgs = {
    silence : ?Silence;
    kind : Text;
    legislation : ?Text;
    decision_deadline : ?Period;
    matter : ?Text;
    initiated_by : Text;
    facts : ?Value;
  };
  public type ProcedurePage = { next : ?Text; items : [Procedure] };
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
    language : ?Text;
    on_behalf_of : ?Principal;
    avatar : ?Text;
  };
  public type Proposal = {
    id : Text;
    /// The delegate that prepared the call, when the proposer approved it from a pending action (§2).
    prepared_by : ?Principal;
    opens_at : ?Timestamp;
    status : ProposalStatus;
    result : ?ProposalResult;
    tally : Tally;
    title : Text;
    action : ProposalAction;
    /// The rule that decides it (I-GOV-3), fixed when the vote opens: the yes votes exceed (realm-wide)
    /// or reach (a department, of `tally.seats`) the threshold of the basis, with the quorum met.
    threshold : Ratio;
    /// When the action takes effect; absent means on acceptance. Fixed at creation, it never moves.
    effective_at : ?Timestamp;
    /// What the proposal is (a change of legislation, a budget, a motion) and the matter it decides, in the
    /// realm's own words, for legislation to read.
    kind : ?Text;
    description : Text;
    deadline : ?Timestamp;
    threshold_of : ThresholdBasis;
    links : [ProposalLink];
    on_behalf_of : ?Principal;
    proposer : Principal;
    matter : ?Text;
    /// The realm's casting vote when the proposal was created: a member whose yes decides a tie under the
    /// Cast basis, so only a realm-wide proposal has one. Never the proposer's choice.
    casting_vote : ?Principal;
    department : ?Text;
    quorum : Ratio;
  };
  public type ProposalAction = {
    /// One update call the realm makes to itself once accepted; `arg` is Candid-encoded.
    #Call : { arg : Blob; method : Text };
    /// Codex code to adopt; checksum is "sha256:<hex>".
    #Code : { url : Text; checksum : Text };
    /// The decision itself is the outcome.
    #Motion;
  };
  /// links is optional, and absent means none, so callers built before links existed keep working. At
  /// most 16 links, each naming an existing proposal once. A Replaces target must be a withdrawn
  /// proposal filed for the same member (on_behalf_of when set, else the proposer), and one that no
  /// other proposal replaces yet.
  public type ProposalCreateArgs = {
    title : Text;
    action : ProposalAction;
    /// Stricter than the realm's or the department's rule, never weaker (InvalidArgument): a higher threshold
    /// or quorum, or Eligible where the default is Cast. The casting vote is the realm's, for a realm-wide
    /// proposal only, not the proposer's.
    threshold : ?Ratio;
    /// Must lie after the time of the call, else InvalidArgument. Absent means the action executes on acceptance.
    effective_at : ?Timestamp;
    kind : ?Text;
    description : Text;
    threshold_of : ?ThresholdBasis;
    links : ?[ProposalLink];
    on_behalf_of : ?Principal;
    matter : ?Text;
    department : ?Text;
    quorum : ?Ratio;
  };
  /// The proposal, its votes a page at a time, and the one proposal that replaces it, if any. The other
  /// links to it are in ggg_proposal_linked_from.
  public type ProposalDetail = {
    votes : [Vote];
    next : ?Text;
    replaced_by : ?Text;
    proposal : Proposal;
  };
  public type ProposalLink = { kind : ProposalLinkKind; proposal : Text };
  /// A link to another proposal. In Proposal.links it is the proposal's own link, fixed at creation. In
  /// ggg_proposal_linked_from it is another proposal's link to this one, so Replaces there reads
  /// "replaced by" and RelatesTo "related to". The proposal is the other proposal's id.
  public type ProposalLinkKind = { #RelatesTo; #Replaces };
  /// The links of other proposals to one proposal, oldest first.
  public type ProposalLinkPage = { next : ?Text; items : [ProposalLink] };
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
  /// ExecutionScheduled: accepted, and waiting for its effective_at.
  public type ProposalStatus = {
    #Failed;
    #ExecutionScheduled;
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
  /// A publication of the document in a journal: the dispatch that carried it, and when and under which
  /// reference the journal published it, from the dispatch's confirmation.
  public type Publication = {
    ref : ?Text;
    dispatch : Text;
    journal : Text;
    published_at : ?Timestamp;
  };
  /// Content in clear: where it lives and its hash. It holds no personal data.
  public type Published = { ref : Text; hash : Text };
  public type Quarter = {
    id : Text;
    status : QuarterStatus;
    /// The same flag as a follower's: a quarter not ready when its realm's codex switches is NonCompliant
    /// until it installs.
    compliance : Compliance;
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
    /// An IANA name, for the `quarter` named; any other text, or a `timezone` with no `quarter`, is InvalidArgument.
    timezone : ?Text;
    quarter : ?Text;
    name : ?Text;
    rule : ?Value;
    federation_codex : ?Text;
    quarter_join_mode : ?Text;
    /// For the `quarter` named; a `welcome_message` with no `quarter` is InvalidArgument.
    welcome_message : ?Text;
  };
  /// `zones` is filled by quarter_sync alone: the zones the realm defines, as zone_define takes them, for the quarter to
  /// define the same (the capital is where the realm's codex defines its districts). Null in quarter_directory.
  public type QuarterDirectory = {
    next : ?Text;
    zones : ?[ZoneDefineArgs];
    capital : ?Text;
    items : [Quarter];
  };
  public type QuarterRegisterArgs = { name : ?Text; canister : Principal };
  public type QuarterReport = { quarter : Text; drifting : Bool };
  /// A quarter's report to the capital.
  public type QuarterReportArgs = {
    leg : ?FederalVoteLeg;
    codex_version : ?Text;
    /// The zones its members live in, each a pair of the zone's id and how many members have it as their
    /// home_zone. The capital keeps what the last report said for placing new members and shows it to no one:
    /// no operation returns it, since a small count singles out a person.
    zones : ?[(Text, Nat)];
    codex_id : ?Text;
    population : Nat;
  };
  public type QuarterStatus = {
    #Splitting;
    #Setup;
    #Active;
    #Suspended;
    #Merging;
  };
  public type Rate = Nat;
  /// A ratio in hundred-millionths: 100 % is 100 000 000, 1 % is 1 000 000 and 0.123456 % is 123 456.
  /// One scale for quorum, threshold, share, weight and tax rate (model §1). A Ratio is at most 100 %; a
  /// Rate, for tax rates and coefficients, which legislation takes above 100 %, is at most 100 times that.
  public type Ratio = Nat;
  public type ReadForArgs = {
    arg : Blob;
    method : Text;
    on_behalf_of : Principal;
  };
  public type Realm = {
    id : Text;
    status : RealmStatus;
    /// An IANA time zone name such as "Europe/Madrid"; "UTC" until the realm sets one.
    timezone : Text;
    require_marketplace_approval : Bool;
    is_quarter : Bool;
    name : Text;
    manifesto : Text;
    /// BCP 47 tags of the realm's languages, the first the default.
    languages : [Text];
    network : Text;
    federation_codex : ?Text;
    quarter_join_mode : ?Text;
    is_capital : Bool;
    calendar : ?Text;
    logo_url : ?Text;
    open_registration : Bool;
    trusted_principals : [Principal];
    /// The realms this one syncs legislation from, each with its link status (I-NEST-1).
    sync_sources : [SyncSource];
    federation_realm_id : ?Text;
    accounting_currency_decimals : ?Nat8;
    welcome_message : Text;
    casting_vote : ?Principal;
    trusted_approvers : [Text];
    /// Its members; on a capital, with its quarters' as they last reported.
    member_count : Nat;
    voting_quorum : Ratio;
    background_image_url : ?Text;
    /// For realm-wide proposals. `casting_vote` is an active member whose yes decides a tie over the votes
    /// cast (I-GOV-3); set with governance_update.
    voting_threshold : Ratio;
    installed_version : Text;
    treasury : ?Text;
    accounting_currency : ?Text;
  };
  public type RealmConfigureArgs = {
    /// An IANA name; any other text is InvalidArgument.
    timezone : ?Text;
    name : ?Text;
    manifesto : ?Text;
    /// BCP 47 tags, the first the default.
    languages : ?[Text];
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
  /// One release of one layer, as a published record lists it: every chapter of the source, changed or
  /// not, its calendar's checksum, the commit it was built from, when it was published and from when it
  /// is in force. `source` is the layer's source id, opaque text to GGG; `notes` are the publisher's, by
  /// language.
  public type Release = {
    source : Text;
    published : Timestamp;
    version : Text;
    calendar : ?Text;
    effective_from : Timestamp;
    chapters : [ChapterRef];
    notes : Value;
    commit : Text;
  };
  public type ReleasePage = { next : ?Text; items : [Release] };
  /// One report by id, or a page of reports.
  public type ReportArgs = { id : ?Text; cursor : ?Text; limit : ?Nat32 };
  /// `adjustments` are figures the issuer adds to the ledger's, for a report in terms the ledger doesn't keep.
  public type ReportIssueArgs = {
    period : Text;
    kind : ?Text;
    adjustments : ?Value;
  };
  public type ReportPage = { next : ?Text; items : [FinancialReport] };
  /// One layer a follower runs. It names no source: the sync source finds the layer by its checksum in
  /// its own record.
  public type ReportedLayer = { version : Text; checksum : Text };
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
  /// A request to the realm by a person or a body: a petition, a complaint, a request for information or
  /// for personal data. The kinds are the realm's; legislation sets the deadline and decides silence. A
  /// `body` or `reply` that holds personal data carries a Document reference, encrypted, not text in clear.
  public type Request = {
    by : Ref;
    id : Text;
    status : RequestStatus;
    decision : ?Text;
    body : Value;
    kind : Text;
    filed_at : Timestamp;
    due_at : ?Timestamp;
    reply : ?Text;
    decided_at : ?Timestamp;
    extension_limit : ?Timestamp;
  };
  /// `decision` is the realm's word for the outcome (`granted`, `refused`, `refused_by_silence`).
  public type RequestDecideArgs = {
    decision : Text;
    request : Text;
    reply : ?Text;
  };
  /// For the caller, or an organization they administer.
  public type RequestFileArgs = {
    body : Value;
    kind : Text;
    on_behalf_of : ?Principal;
    organization : ?Text;
  };
  public type RequestGetArgs = { id : Text; on_behalf_of : ?Principal };
  public type RequestListArgs = {
    status : ?RequestStatus;
    cursor : ?Text;
    kind : ?Text;
    limit : ?Nat32;
  };
  public type RequestPage = { next : ?Text; items : [Request] };
  /// Sets or moves the deadline, never past `extension_limit`, which is set once (Conflict after that).
  public type RequestSetDueArgs = {
    request : Text;
    due_at : Timestamp;
    extension_limit : ?Timestamp;
  };
  public type RequestStatus = { #Filed; #Decided };
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
  /// On what basis personal data is shared: the legal basis and purpose in the realm's own words, the
  /// legislation that sets the duty or task, and whether the data is of a special category.
  public type ShareBasis = {
    special_category : Bool;
    legislation : ?Text;
    purpose : Text;
    legal_basis : Text;
  };
  /// Money that may be negative, such as a discount line of an invoice. Rounded as Money is.
  public type SignedMoney = Int;
  public type SigningPolicy = {
    supervision : { #Required; #Optional };
    agents : [Text];
    delegable : [Text];
  };
  /// What the realm's silence past a deadline means: Positive grants, Negative refuses.
  public type Silence = { #Negative; #Positive };
  /// One line of the realm's own description of the call.
  public type SummaryLine = { value : Text; label_ : Text };
  public type SyncSource = {
    status : LinkStatus;
    source : SyncSourceRef;
    name : Text;
  };
  public type SyncSourceAddArgs = { source : SyncSourceRef; name : Text };
  /// A realm, by its capital, or a stand-in record at a public https URL for a source that runs no
  /// realm, pinned by the checksum of its content.
  public type SyncSourceRef = {
    #Record : { url : Text; checksum : Text };
    #Realm : Principal;
  };
  /// A Record is the same source when its url is the same, whatever the checksum.
  public type SyncSourceRemoveArgs = { source : SyncSourceRef };
  /// `eligible`: who may vote, counted when the vote opens. `seats`: a department's policy n, what its
  /// threshold is measured against (I-GOV-3); absent for a realm-wide proposal.
  public type Tally = {
    no : Nat;
    yes : Nat;
    abstain : Nat;
    seats : ?Nat;
    eligible : ?Nat;
  };
  /// One operation scheduled for a time. It runs with the authority of whoever scheduled it, never as the
  /// realm's controller, and every guard and rule runs again when it does, so a task scheduled under old
  /// legislation obeys the legislation in force on its date. The run writes the operation's own Event, with
  /// origin `task`; `event` names it. There is no task_run operation.
  public type Task = {
    at : Timestamp;
    id : Text;
    op : Text;
    status : TaskStatus;
    args : Value;
    event : ?Text;
    scheduled_by : Ref;
    reason : ?Text;
  };
  public type TaskListArgs = {
    op : ?Text;
    status : ?TaskStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  public type TaskPage = { next : ?Text; items : [Task] };
  public type TaskRescheduleArgs = { at : Timestamp; task : Text };
  /// `op` is an operation name (`user_set_status`), `args` its arguments as the Event records them.
  public type TaskScheduleArgs = {
    at : Timestamp;
    op : Text;
    args : Value;
    reason : ?Text;
  };
  public type TaskStatus = { #Run; #Failed; #Scheduled; #Cancelled };
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
    amount : Money;
  };
  public type TaxDeclarationStatus = { #Disputed; #Filed; #Assessed; #Settled };
  /// For the caller, or an organization they administer.
  public type TaxDeclareArgs = {
    period : Text;
    base : Text;
    on_behalf_of : ?Principal;
    organization : ?Text;
    amount : Money;
  };
  public type TaxDeclared = {
    invoice : ?Invoice;
    declaration : TaxDeclaration;
  };
  /// One tax, fee or charge of a policy. `kind` is the realm's word (e.g. `tax`, `fee`, `surcharge`);
  /// `subject` names the entity each assessment walks (e.g. `Land`, `User`, `Organization`); `rate` or
  /// `amount` is what the entry charges when no codex computes it; `facts` is what legislation reads about
  /// the entry beyond these. A rule on tax_policy_propose or tax_policy_draft ranges over the policy's
  /// entries, one request per entry (layered-codex §3.2).
  public type TaxEntry = {
    subject : Text;
    code : Text;
    kind : Text;
    rate : ?Rate;
    amount : ?Money;
    facts : Value;
  };
  public type TaxPolicy = {
    id : Text;
    status : AdoptionStatus;
    taxes : [TaxEntry];
    adopted_at : ?Timestamp;
    description : Text;
    document : Value;
    proposal : ?Text;
  };
  /// The entries are checked as they are when the policy is proposed (layered-codex §3.2).
  public type TaxPolicyDraftArgs = {
    taxes : [TaxEntry];
    description : ?Text;
    document : Value;
  };
  public type Tender = {
    id : Text;
    opens_at : ?Timestamp;
    status : TenderStatus;
    title : Text;
    requester : Text;
    estimated_value : ?Money;
    closes_at : ?Timestamp;
    rubric : [Criterion];
    contract : ?Text;
    /// What is tendered (works, supplies, services), by which procedure, and for how much.
    kind : ?Text;
    notices : [Notice];
    winner : ?Text;
    description : Text;
    procedure : ?Text;
  };
  /// `bid` defaults to the best-scored revealed bid; a lower-scored one needs a justification.
  public type TenderAwardArgs = {
    bid : ?Text;
    justification : ?Text;
    tender : Text;
  };
  /// Weights add up to 100 000 000 (100 %).
  public type TenderCreateArgs = {
    opens_at : ?Timestamp;
    title : Text;
    requester : Text;
    estimated_value : ?Money;
    closes_at : ?Timestamp;
    rubric : [Criterion];
    kind : ?Text;
    description : ?Text;
    procedure : ?Text;
  };
  /// A sealed bid shows no price or score.
  public type TenderDetail = { bids : [Bid]; next : ?Text; tender : Tender };
  public type TenderListArgs = {
    status : ?TenderStatus;
    cursor : ?Text;
    limit : ?Nat32;
  };
  /// Records that a notice of the tender appeared in `journal`: an External of kind `journal`, or `realm` for
  /// the realm's own journal. `at` defaults to now and is never in the future.
  public type TenderNoticeArgs = {
    at : ?Timestamp;
    ref : ?Text;
    journal : Text;
    tender : Text;
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
  /// What a threshold is measured against: the yes and no votes cast, or the eligible voters; for a
  /// department, Eligible means its policy's n (`tally.seats`), and Cast is weaker and refused.
  public type ThresholdBasis = { #Cast; #Eligible };
  public type TieredOperation = {
    permission : Text;
    tier : DelegationTier;
    operation : Text;
    confirm_if : ?Text;
  };
  /// Nanoseconds since 1970-01-01 UTC, as returned by ic0.time.
  public type Timestamp = Nat64;
  public type Token = {
    id : Text;
    fee : Money;
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
    amount : Money;
    symbol : Text;
    payroll : ?Text;
  };
  /// The fund must also cover the ledger fee. `symbol` defaults to the accounting currency. `category`
  /// never names `ledger_fee`, the fee's own entry, which the GOS books itself (InvalidArgument).
  public type TransferCreateArgs = {
    to : Ref;
    contract : ?Text;
    fund : Text;
    description : ?Text;
    category : ?Text;
    on_behalf_of : ?Principal;
    amount : Money;
    symbol : ?Text;
  };
  public type TransferRevertArgs = { transfer : Text; reason : ?Text };
  public type TransferStatus = { #Failed; #Sending; #Completed; #Pending };
  /// A title and body in one language, for a notice sent in several.
  public type Translation = { title : Text; body : ?Text; language : Text };
  public type Treasury = {
    id : Text;
    /// The sum of the active loans' `outstanding`.
    debt_outstanding : Money;
    config : TreasuryConfig;
  };
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
    /// A BCP 47 language tag, for notices to the user.
    language : ?Text;
    /// The Zone the user lives in: a district the realm defined (zone_define), stated when joining or set by
    /// user_edit.
    home_zone : ?Text;
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
    language : ?Text;
    /// A zone the realm defined; an unknown zone, or a member's home cell, is InvalidArgument.
    home_zone : ?Text;
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
  /// A member's own home cell (an h3 index, set with zone_set, tied to `user`), or a zone the realm defines
  /// with zone_define, such as a district, named by its id.
  public type Zone = {
    id : Text;
    metadata : Value;
    kind : Text;
    land : ?Text;
    name : Text;
    user : ?Principal;
    /// Members whose home_zone this is.
    population : Nat;
  };
  public type ZoneClearArgs = { zone : Text; on_behalf_of : ?Principal };
  /// Defines a zone of the realm, such as a district, which members name as their home_zone; the same id
  /// again redefines it.
  public type ZoneDefineArgs = { kind : Text; name : Text; zone : Text };
  /// An h3 cell as the caller's home; it replaces the previous one.
  public type ZoneSetArgs = {
    kind : ?Text;
    name : ?Text;
    zone : Text;
    on_behalf_of : ?Principal;
  };
  public type Self = actor {
    ggg_action_approve : shared ActionApproveArgs -> async {
        #Ok : PendingAction;
        #Err : GggError;
      };
    /// The delegate that prepared an approved read runs it once, as the grantor, at this moment, while the
    /// grant is active and covers the group: the reply, Candid-encoded with the method's own type. A second
    /// call is Conflict; so is one after expires_at (expired) or after the grant was revoked (void).
    ggg_action_collect : shared Text -> async { #Ok : Blob; #Err : GggError };
    ggg_action_decline : shared ActionDeclineArgs -> async {
        #Ok : PendingAction;
        #Err : GggError;
      };
    ggg_action_get : shared query Text -> async {
        #Ok : ?PendingAction;
        #Err : GggError;
      };
    ggg_action_list : shared query ActionListArgs -> async {
        #Ok : PendingActionPage;
        #Err : GggError;
      };
    ggg_action_withdraw : shared Text -> async {
        #Ok : PendingAction;
        #Err : GggError;
      };
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
    ggg_attribute_list : shared query AttributeListArgs -> async {
        #Ok : AttributePage;
        #Err : GggError;
      };
    /// The attributes awaiting review, for the holders of attribute.review (I-PRV-1); the cursor continues
    /// after the last attribute returned, so deciding a page skips none.
    ggg_attribute_pending_list : shared query ListArgs -> async {
        #Ok : AttributePage;
        #Err : GggError;
      };
    ggg_attribute_review : shared AttributeReviewArgs -> async {
        #Ok : Attribute;
        #Err : GggError;
      };
    ggg_attribute_submit : shared AttributeSubmitArgs -> async {
        #Ok : Attribute;
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
    /// Copies the previous period's adopted budget into the period named as Extended lines, without a vote,
    /// and replies how many lines it copied; Conflict once the period has an Extended, Proposed or Adopted
    /// line (Draft lines stand in no way).
    ggg_budget_extend : shared Text -> async { #Ok : Nat; #Err : GggError };
    ggg_budget_propose : shared BudgetProposeArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_call_for : shared CallForArgs -> async {
        #Ok : CallForReply;
        #Err : GggError;
      };
    ggg_case_assign : shared CaseAssignArgs -> async {
        #Ok : Case;
        #Err : GggError;
      };
    ggg_codex_activate : shared CodexActivateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_codex_install : shared CodexSource -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_codex_revert : shared ?CodexRevertArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
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
    ggg_delegation_activity : shared query DelegationActivityArgs -> async {
        #Ok : EventPage;
        #Err : GggError;
      };
    ggg_delegation_grant : shared DelegationGrantArgs -> async {
        #Ok : Delegation;
        #Err : GggError;
      };
    ggg_delegation_groups : shared query DelegationGroupsArgs -> async {
        #Ok : DelegationGroupPage;
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
    ggg_delegation_revoke_all : shared DelegationRevokeAllArgs -> async {
        #Ok : DelegationsRevoked;
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
    ggg_dispatch_confirm : shared DispatchConfirmArgs -> async {
        #Ok : Dispatch;
        #Err : GggError;
      };
    ggg_dispatch_list : shared query DispatchListArgs -> async {
        #Ok : DispatchPage;
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
    ggg_document_publish : shared DocumentPublishArgs -> async {
        #Ok : Document;
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
    ggg_external_add : shared ExternalAddArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_external_list : shared query ListArgs -> async {
        #Ok : ExternalPage;
        #Err : GggError;
      };
    ggg_external_report : shared ExternalReportArgs -> async {
        #Ok : Event;
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
    ggg_follower_accept : shared FollowerArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_follower_list : shared query ListArgs -> async {
        #Ok : FollowerPage;
        #Err : GggError;
      };
    ggg_follower_remove : shared FollowerArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_follower_report : shared FollowerReportArgs -> async {
        #Ok : Follower;
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
    ggg_host_infrastructure : shared HostInfrastructure -> async {
        #Ok : SetupState;
        #Err : GggError;
      };
    ggg_host_install : shared HostInstallArgs -> async {
        #Ok : SetupState;
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
    ggg_invoice_item_add : shared InvoiceItemAddArgs -> async {
        #Ok : Invoice;
        #Err : GggError;
      };
    ggg_invoice_refresh : shared InvoiceRefreshArgs -> async {
        #Ok : InvoicePage;
        #Err : GggError;
      };
    ggg_join_targets : shared query ?JoinTargetsArgs -> async {
        #Ok : JoinTargets;
        #Err : GggError;
      };
    ggg_judge_appoint : shared JudgeAppointArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_judge_revoke : shared Text -> async { #Ok : Governed; #Err : GggError };
    ggg_land_assess : shared LandAssessArgs -> async {
        #Ok : Land;
        #Err : GggError;
      };
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
    ggg_legislation_chapter : shared query Text -> async {
        #Ok : ?Blob;
        #Err : GggError;
      };
    ggg_legislation_release_publish : shared LegislationReleasePublishArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_legislation_releases : shared query ListArgs -> async {
        #Ok : ReleasePage;
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
    ggg_link_notify : shared LinkNotifyArgs -> async {
        #Ok : LinkStatus;
        #Err : GggError;
      };
    ggg_loan_create : shared LoanCreateArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_loan_list : shared query LoanListArgs -> async {
        #Ok : LoanPage;
        #Err : GggError;
      };
    ggg_loan_repay : shared LoanRepayArgs -> async {
        #Ok : Loan;
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
    ggg_me : shared query MeArgs -> async { #Ok : Me; #Err : GggError };
    ggg_my_invoices : shared query MyInvoicesArgs -> async {
        #Ok : MyInvoicePage;
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
        #Ok : Delivery;
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
    ggg_procedure_define : shared ProcedureDefineArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_procedure_list : shared query ListArgs -> async {
        #Ok : ProcedurePage;
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
    ggg_proposal_linked_from : shared query GetArgs -> async {
        #Ok : ?ProposalLinkPage;
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
    /// Ends a proposal whose execution is scheduled, as Withdrawn. Governed by the department the
    /// proposal is scoped to, the root for a realm-wide one. Done carries no id.
    ggg_proposal_stop : shared Text -> async {
        #Ok : Governed;
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
    ggg_quarter_report : shared QuarterReportArgs -> async {
        #Ok : QuarterReport;
        #Err : GggError;
      };
    ggg_quarter_secede : shared () -> async { #Ok : Governed; #Err : GggError };
    ggg_quarter_sync : shared () -> async {
        #Ok : QuarterDirectory;
        #Err : GggError;
      };
    ggg_read_for : shared query ReadForArgs -> async {
        #Ok : Blob;
        #Err : GggError;
      };
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
    ggg_realm_monitor : shared query () -> async {
        #Ok : Monitor;
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
    ggg_request_decide : shared RequestDecideArgs -> async {
        #Ok : Request;
        #Err : GggError;
      };
    ggg_request_file : shared RequestFileArgs -> async {
        #Ok : Request;
        #Err : GggError;
      };
    ggg_request_get : shared query RequestGetArgs -> async {
        #Ok : ?Request;
        #Err : GggError;
      };
    ggg_request_list : shared query RequestListArgs -> async {
        #Ok : RequestPage;
        #Err : GggError;
      };
    ggg_request_set_due : shared RequestSetDueArgs -> async {
        #Ok : Request;
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
    ggg_sync_source_add : shared SyncSourceAddArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_sync_source_remove : shared SyncSourceRemoveArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_task_cancel : shared Text -> async { #Ok : Task; #Err : GggError };
    ggg_task_list : shared query TaskListArgs -> async {
        #Ok : TaskPage;
        #Err : GggError;
      };
    ggg_task_reschedule : shared TaskRescheduleArgs -> async {
        #Ok : Task;
        #Err : GggError;
      };
    ggg_task_schedule : shared TaskScheduleArgs -> async {
        #Ok : Task;
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
    ggg_tender_notice : shared TenderNoticeArgs -> async {
        #Ok : Tender;
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
    ggg_zone_define : shared ZoneDefineArgs -> async {
        #Ok : Governed;
        #Err : GggError;
      };
    ggg_zone_set : shared ZoneSetArgs -> async { #Ok : Zone; #Err : GggError };
    icrc10_supported_standards : shared query () -> async [
        { url : Text; name : Text }
      ];
  }
}
