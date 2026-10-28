/// A minimal GGG GOS, used to test the conformance suite. It implements every method of ggg.did.
/// Members are fixed at install time. They may propose, vote, read the realm and manage their own
/// profile; every other permission is held by nobody, so those operations are refused. The only
/// department is the root, so every proposal is realm-wide. Nobody has granted a delegation, so
/// nobody acts on another's behalf. Every other domain is empty, which the model allows.
import Array "mo:core/Array";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Time "mo:core/Time";
import T "Ggg";

persistent actor class GggFixture(initMembers : [Principal]) {

  type Result<A> = { #Ok : A; #Err : T.GggError };
  type Page<A> = { items : [A]; next : ?Text };

  let DEFAULT_LIMIT = 20;
  let MAX_LIMIT = 100;
  let MAP_VIEW = 32;
  let VOTING_WINDOW_NS : Nat64 = 7 * 24 * 3600 * 1_000_000_000;
  let VOTING_THRESHOLD = 5_000;
  let VOTING_QUORUM = 0;

  func now() : T.Timestamp = Nat64.fromNat(Int.abs(Time.now()));

  let ROOT : T.Department = {
    id = "root";
    description = "The realm itself.";
    parent = null;
    is_root = true;
    head = null;
    policy = { m = 1; n = 1; quorum = 0; veto = [] };
    target_policy = null;
    fund = null;
  };

  let createdAt = now();
  let members = Map.empty<Principal, T.UserEntry>();
  for (p in initMembers.vals()) {
    let user = { id = p; nickname = null; avatar = null; home_quarter = null; profiles = ["member"]; private_data = null };
    let member = { id = Principal.toText(p); user = p; status = #Active; joined_at = ?createdAt };
    Map.add(members, Principal.compare, p, { user; member = ?member });
  };
  let proposals = Map.empty<Nat, T.Proposal>();
  let votes = Map.empty<Nat, Map.Map<Principal, T.Vote>>();
  let events = Map.empty<Nat, T.Event>();
  var nextProposal = 1;

  func pageSize(limit : ?Nat32) : Nat {
    switch (limit) {
      case null DEFAULT_LIMIT;
      case (?l) Nat.max(1, Nat.min(MAX_LIMIT, Nat32.toNat(l)));
    };
  };

  /// Cursors are offsets into the key order, written as decimal text.
  func page<A>(all : Iter.Iter<A>, cursor : ?Text, limit : ?Nat32) : Result<Page<A>> {
    let start = switch (cursor) {
      case null 0;
      case (?c) {
        switch (Nat.fromText(c)) {
          case null return #Err(#InvalidArgument("unknown cursor"));
          case (?n) n;
        };
      };
    };
    let size = pageSize(limit);
    let items = Iter.toArray(Iter.take(Iter.drop(all, start), size + 1));
    if (items.size() > size) {
      #Ok({ items = Array.sliceToArray(items, 0, size); next = ?Nat.toText(start + size) });
    } else {
      #Ok({ items; next = null });
    };
  };

  /// A page of a domain this realm has nothing in.
  func none<A>(cursor : ?Text, limit : ?Nat32) : Result<Page<A>> = page(Iter.empty<A>(), cursor, limit);

  func requireMember(caller : Principal, permission : Text) : ?T.GggError {
    if (Principal.isAnonymous(caller)) return ?#Unauthenticated;
    switch (Map.get(members, Principal.compare, caller)) {
      case (?{ member = ?{ status = #Active } }) null;
      case _ ?#Forbidden({ permission = ?permission; message = "Only active members may do this." });
    };
  };

  /// Refuses an operation whose permission no member holds.
  func nobody<A>(caller : Principal, permission : Text) : Result<A> {
    switch (requireMember(caller, permission)) { case (?e) return #Err(e); case null {} };
    #Err(#Forbidden({ permission = ?permission; message = "No member of this realm holds " # permission # "." }));
  };

  func noDelegation(permission : Text) : T.GggError {
    #Forbidden({ permission = ?permission; message = "No active delegation from that principal covers this." });
  };

  /// A call a proposal may make: one of this canister's update methods, with arguments that decode.
  func checkCall(method : Text, arg : Blob) : ?T.GggError {
    let decodes = switch (method) {
      case "ggg_proposal_create" { let a : ?T.ProposalCreateArgs = from_candid (arg); a != null };
      case "ggg_proposal_vote" { let a : ?T.ProposalVoteArgs = from_candid (arg); a != null };
      case "ggg_proposal_withdraw" { let a : ?T.ProposalWithdrawArgs = from_candid (arg); a != null };
      case "ggg_profile_update" { let a : ?T.ProfileUpdateArgs = from_candid (arg); a != null };
      case _ return ?#InvalidArgument(method # " is not an update method of this canister");
    };
    if (decodes) null else ?#InvalidArgument("arg does not decode as the arguments of " # method);
  };

  func audit(op : Text, user : Principal, args : T.Value, result : T.Value) {
    let id = Map.size(events) + 1;
    let event = {
      id = Nat.toText(id);
      op;
      user = ?user;
      by = null;
      agent = false;
      supervisor = null;
      origin = "user";
      args;
      result;
      at = now();
    };
    Map.add(events, Nat.compare, id, event);
  };

  func given(key : Text, value : ?Text) : [(Text, T.Value)] {
    switch (value) { case (?v) [(key, #Text(v))]; case null [] };
  };

  func findProposal(id : Text) : ?(Nat, T.Proposal) {
    switch (Nat.fromText(id)) {
      case null null;
      case (?n) {
        switch (Map.get(proposals, Nat.compare, n)) {
          case null null;
          case (?p) ?(n, p);
        };
      };
    };
  };

  func ballots(n : Nat) : Map.Map<Principal, T.Vote> {
    switch (Map.get(votes, Nat.compare, n)) {
      case (?b) b;
      case null {
        let b = Map.empty<Principal, T.Vote>();
        Map.add(votes, Nat.compare, n, b);
        b;
      };
    };
  };

  func add(t : T.Tally, choice : T.VoteChoice, delta : Int) : T.Tally {
    func apply(v : Nat) : Nat = Int.abs(v + delta);
    switch (choice) {
      case (#Yes) ({ t with yes = apply(t.yes) });
      case (#No) ({ t with no = apply(t.no) });
      case (#Abstain) ({ t with abstain = apply(t.abstain) });
    };
  };

  public query func icrc10_supported_standards() : async [{ name : Text; url : Text }] {
    [
      { name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md" },
      { name = "GGG"; url = "https://github.com/smart-social-contracts/ggg/blob/v0.1.0/ggg.did" },
    ];
  };

  // §2

  public query func ggg_user_get(p : Principal) : async Result<?T.UserEntry> {
    #Ok(Map.get(members, Principal.compare, p));
  };

  public query func ggg_user_list(args : T.ListArgs) : async Result<T.UserPage> {
    page(Map.values(members), args.cursor, args.limit);
  };

  public query func ggg_invite_list(args : T.ListArgs) : async Result<T.InvitePage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_delegation_list(args : T.DelegationListArgs) : async Result<T.DelegationPage> {
    switch (none<T.Delegation>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ items; requests = []; next });
    };
  };

  public query func ggg_delegable_operations() : async Result<[T.DelegableOperation]> {
    #Ok([]);
  };

  public query ({ caller }) func ggg_me(args : T.MeArgs) : async Result<T.Me> {
    let entry = switch (self(caller, "self.data_view", args.on_behalf_of)) {
      case (#Err(e)) return #Err(e);
      case (#Ok(entry)) entry;
    };
    #Ok({
      user = entry.user;
      member = entry.member;
      permissions = [
        "self.data_view",
        "self.update_public_profile",
        "self.update_private_data",
        "proposal.create",
        "proposal.vote",
        "realm.data_view",
        "realm.monitor",
        "db.export",
      ];
      delegations = [];
      requests = [];
    });
  };

  public shared ({ caller }) func ggg_realm_join(args : T.JoinArgs) : async Result<T.UserEntry> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    switch (args.code) {
      case null #Err(#Forbidden({ permission = null; message = "Registration is closed: joining needs an invite code." }));
      case (?_) #Err(#InvalidArgument("no invite has this code"));
    };
  };

  func self(caller : Principal, permission : Text, on_behalf_of : ?Principal) : Result<T.UserEntry> {
    switch (requireMember(caller, permission)) { case (?e) return #Err(e); case null {} };
    if (on_behalf_of != null) return #Err(noDelegation(permission));
    switch (Map.get(members, Principal.compare, caller)) {
      case (?entry) #Ok(entry);
      case null #Err(#NotFound);
    };
  };

  public shared ({ caller }) func ggg_profile_update(args : T.ProfileUpdateArgs) : async Result<T.User> {
    let entry = switch (self(caller, "self.update_public_profile", args.on_behalf_of)) {
      case (#Err(e)) return #Err(e);
      case (#Ok(entry)) entry;
    };
    let user = {
      entry.user with
      nickname = if (args.nickname != null) args.nickname else entry.user.nickname;
      avatar = if (args.avatar != null) args.avatar else entry.user.avatar;
    };
    Map.add(members, Principal.compare, caller, { entry with user });
    audit("profile_update", caller, #Map(Array.flatten([given("nickname", args.nickname), given("avatar", args.avatar)])), #Text(Principal.toText(caller)));
    #Ok(user);
  };

  public shared ({ caller }) func ggg_private_data_update(data : Blob) : async Result<T.User> {
    let entry = switch (self(caller, "self.update_private_data", null)) {
      case (#Err(e)) return #Err(e);
      case (#Ok(entry)) entry;
    };
    let user = { entry.user with private_data = ?data };
    Map.add(members, Principal.compare, caller, { entry with user });
    audit("private_data_update", caller, #Map([]), #Text(Principal.toText(caller)));
    #Ok(user);
  };

  public shared ({ caller }) func ggg_user_add(_ : T.UserAddArgs) : async Result<T.Governed> { nobody(caller, "user.add") };
  public shared ({ caller }) func ggg_user_import(_ : T.UserImportArgs) : async Result<T.Governed> { nobody(caller, "user.add") };
  public shared ({ caller }) func ggg_user_edit(_ : T.UserEditArgs) : async Result<T.User> { nobody(caller, "user.edit") };
  public shared ({ caller }) func ggg_user_set_status(_ : T.UserSetStatusArgs) : async Result<T.Governed> {
    nobody(caller, "user.update_status");
  };
  public shared ({ caller }) func ggg_user_remove(_ : T.UserRemoveArgs) : async Result<T.Governed> { nobody(caller, "user.delete") };

  public shared ({ caller }) func ggg_identity_submit(_ : T.IdentitySubmitArgs) : async Result<T.Identity> {
    nobody(caller, "identity.submit");
  };
  public shared ({ caller }) func ggg_identity_review(_ : T.IdentityReviewArgs) : async Result<T.Identity> {
    nobody(caller, "identity.review");
  };

  public shared ({ caller }) func ggg_invite_create(_ : T.InviteCreateArgs) : async Result<T.InviteCreated> {
    nobody(caller, "invite.manage");
  };
  public shared ({ caller }) func ggg_invite_revoke(_ : Text) : async Result<T.Invite> { nobody(caller, "invite.manage") };

  public shared ({ caller }) func ggg_profile_create(_ : T.ProfileCreateArgs) : async Result<T.Governed> {
    nobody(caller, "permission.grant");
  };
  public shared ({ caller }) func ggg_profile_edit(_ : T.ProfileEditArgs) : async Result<T.Governed> {
    nobody(caller, "permission.grant");
  };
  public shared ({ caller }) func ggg_role_assign(_ : T.RoleArgs) : async Result<T.Governed> { nobody(caller, "role.assign") };
  public shared ({ caller }) func ggg_role_revoke(_ : T.RoleArgs) : async Result<T.Governed> { nobody(caller, "role.revoke") };

  public shared ({ caller }) func ggg_delegation_grant(_ : T.DelegationGrantArgs) : async Result<T.Delegation> {
    nobody(caller, "self.delegate");
  };
  public shared ({ caller }) func ggg_delegation_accept(_ : Text) : async Result<T.Delegation> { nobody(caller, "self.delegate") };
  public shared ({ caller }) func ggg_delegation_revoke(_ : Text) : async Result<T.Delegation> { nobody(caller, "self.delegate") };
  public shared ({ caller }) func ggg_delegation_request(_ : T.DelegationRequestArgs) : async Result<T.DelegationRequest> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    #Err(#Forbidden({ permission = ?"self.delegate"; message = "No member of this realm can grant a delegation." }));
  };
  public shared ({ caller }) func ggg_delegation_request_decide(_ : T.DelegationDecideArgs) : async Result<?T.Delegation> {
    nobody(caller, "self.delegate");
  };

  // §3

  public query func ggg_department_get(args : T.GetArgs) : async Result<?T.DepartmentDetail> {
    if (args.id != ROOT.id) return #Ok(null);
    switch (none<T.Seat>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ department = ROOT; seats = items; next });
    };
  };

  public query func ggg_department_list(args : T.ListArgs) : async Result<T.DepartmentPage> {
    page([ROOT].vals(), args.cursor, args.limit);
  };

  public query func ggg_department_chart(args : T.ChartArgs) : async Result<T.Chart> {
    switch (args.department) {
      case (?d) { if (d != ROOT.id) return #Err(#NotFound) };
      case null {};
    };
    switch (none<T.Department>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ department = ROOT; positions = 0; seats = 0; filled = 0; children = items; next });
    };
  };

  public query func ggg_organization_get(_ : T.GetArgs) : async Result<?T.OrganizationDetail> {
    #Ok(null);
  };

  public query func ggg_organization_list(args : T.OrganizationListArgs) : async Result<T.OrganizationPage> {
    none(args.cursor, args.limit);
  };

  // §4

  public query func ggg_proposal_get(args : T.GetArgs) : async Result<?T.ProposalDetail> {
    let (n, p) = switch (findProposal(args.id)) { case null return #Ok(null); case (?found) found };
    switch (page(Map.values(ballots(n)), args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ proposal = p; votes = items; next });
    };
  };

  public query func ggg_proposal_list(args : T.ProposalListArgs) : async Result<T.ProposalPage> {
    let all = switch (args.status) {
      case null Map.values(proposals);
      case (?s) Iter.filter<T.Proposal>(Map.values(proposals), func(p) { p.status == s });
    };
    page(all, args.cursor, args.limit);
  };

  public shared ({ caller }) func ggg_proposal_create(args : T.ProposalCreateArgs) : async Result<Text> {
    switch (requireMember(caller, "proposal.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.create"));
    switch (args.department) {
      case (?d) { if (d != ROOT.id) return #Err(#NotFound) };
      case null {};
    };
    if (Text.size(args.title) == 0) return #Err(#InvalidArgument("title is empty"));
    switch (args.action) {
      case (#Motion) {};
      case (#Code { checksum }) {
        if (not Text.startsWith(checksum, #text "sha256:")) {
          return #Err(#InvalidArgument("checksum must start with sha256:"));
        };
      };
      case (#Call { method; arg }) {
        switch (checkCall(method, arg)) { case (?e) return #Err(e); case null {} };
      };
    };
    let t = now();
    let n = nextProposal;
    nextProposal += 1;
    let p : T.Proposal = {
      id = Nat.toText(n);
      title = args.title;
      description = args.description;
      proposer = caller;
      on_behalf_of = null;
      department = null;
      action = args.action;
      status = #Voting;
      opens_at = ?t;
      deadline = ?(t + VOTING_WINDOW_NS);
      threshold = VOTING_THRESHOLD;
      quorum = VOTING_QUORUM;
      tally = { yes = 0; no = 0; abstain = 0; eligible = ?Map.size(members) };
      result = null;
    };
    Map.add(proposals, Nat.compare, n, p);
    audit("proposal_create", caller, #Map([("title", #Text(p.title))]), #Text(p.id));
    #Ok(p.id);
  };

  public shared ({ caller }) func ggg_proposal_vote(args : T.ProposalVoteArgs) : async Result<T.Vote> {
    switch (requireMember(caller, "proposal.vote")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.vote"));
    let (n, p) = switch (findProposal(args.proposal)) { case null return #Err(#NotFound); case (?found) found };
    let t = now();
    let open = p.status == #Voting and (switch (p.deadline) { case (?d) t <= d; case null true });
    if (not open) return #Err(#Conflict("voting is not open"));
    let b = ballots(n);
    var tally = p.tally;
    switch (Map.get(b, Principal.compare, caller)) {
      case (?earlier) tally := add(tally, earlier.choice, -1);
      case null {};
    };
    tally := add(tally, args.choice, 1);
    let v : T.Vote = {
      id = p.id # ":" # Principal.toText(caller);
      proposal = p.id;
      voter = caller;
      cast_by = null;
      choice = args.choice;
      cast_at = t;
    };
    Map.add(b, Principal.compare, caller, v);
    Map.add(proposals, Nat.compare, n, { p with tally });
    audit("proposal_vote", caller, #Map([("proposal", #Text(p.id)), ("choice", #Text(debug_show (args.choice)))]), #Text(v.id));
    #Ok(v);
  };

  public shared ({ caller }) func ggg_proposal_withdraw(args : T.ProposalWithdrawArgs) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.create"));
    let (n, p) = switch (findProposal(args.proposal)) { case null return #Err(#NotFound); case (?found) found };
    if (p.proposer != caller) {
      return #Err(#Forbidden({ permission = ?"proposal.create"; message = "Only the proposer may withdraw a proposal." }));
    };
    if (p.status != #Draft and p.status != #Voting) return #Err(#Conflict("only a draft or a proposal being voted on can be withdrawn"));
    let withdrawn = { p with status = #Withdrawn };
    Map.add(proposals, Nat.compare, n, withdrawn);
    audit("proposal_withdraw", caller, #Map([("proposal", #Text(p.id))]), #Text(p.id));
    #Ok(withdrawn);
  };

  public shared ({ caller }) func ggg_proposal_open(_ : Text) : async Result<T.Proposal> { nobody(caller, "proposal.manage") };
  public shared ({ caller }) func ggg_proposal_finalize(_ : Text) : async Result<T.Proposal> { nobody(caller, "proposal.manage") };
  public shared ({ caller }) func ggg_proposal_execute(_ : Text) : async Result<T.Proposal> { nobody(caller, "proposal.manage") };

  public shared ({ caller }) func ggg_mandate_create(_ : T.MandateCreateArgs) : async Result<T.Governed> {
    nobody(caller, "mandate.create");
  };
  public shared ({ caller }) func ggg_mandate_revoke(_ : T.MandateRevokeArgs) : async Result<T.Governed> {
    nobody(caller, "mandate.create");
  };
  public shared ({ caller }) func ggg_mandate_assign_executor(_ : T.MandateExecutorArgs) : async Result<T.Governed> {
    nobody(caller, "mandate.assign_executor");
  };
  public shared ({ caller }) func ggg_contract_create(_ : T.ContractCreateArgs) : async Result<T.Contract> {
    nobody(caller, "contract.create_under_mandate");
  };
  public shared ({ caller }) func ggg_contract_terminate(_ : Text) : async Result<T.Contract> {
    nobody(caller, "contract.terminate");
  };
  public shared ({ caller }) func ggg_governance_update(_ : T.GovernanceUpdateArgs) : async Result<T.Governed> {
    nobody(caller, "governance.update");
  };

  // §5

  public query ({ caller }) func ggg_my_invoices(args : T.MyInvoicesArgs) : async Result<T.MyInvoicePage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  public query func ggg_treasury_view(args : T.ListArgs) : async Result<T.TreasuryView> {
    switch (none<T.Fund>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ treasury = null; tokens = []; nft_tokens = []; funds = items; next });
    };
  };

  public query func ggg_ledger_view(args : T.LedgerArgs) : async Result<T.LedgerPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_report_view(args : T.ReportArgs) : async Result<T.ReportPage> {
    none(args.cursor, args.limit);
  };

  // §6

  public query func ggg_land_list(args : T.LandListArgs) : async Result<T.LandPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_land_map(args : T.LandMapArgs) : async Result<T.LandMap> {
    if (args.w < 1 or args.w > MAP_VIEW or args.h < 1 or args.h > MAP_VIEW) {
      return #Err(#InvalidArgument("a map viewport is 1 to 32 cells wide and high"));
    };
    switch (none<T.Zone>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ parcels = []; zones = items; next });
    };
  };

  public query func ggg_credential_verify(_ : T.CredentialVerifyArgs) : async Result<T.CredentialCheck> {
    #Ok({ valid = false; ours = false; licensed = false; expired = false; revoked = false });
  };

  // §7

  public query func ggg_license_list(args : T.LicenseListArgs) : async Result<T.LicensePage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_license_verify(_ : T.LicenseVerifyArgs) : async Result<T.LicenseCheck> {
    #Ok({ valid = false; license = null });
  };

  // §8

  public query func ggg_dispute_get(args : T.DisputeGetArgs) : async Result<?T.Dispute> {
    if (args.on_behalf_of != null) return #Err(noDelegation("dispute.view"));
    #Ok(null);
  };

  public query func ggg_dispute_list_all(args : T.DisputeListArgs) : async Result<T.DisputePage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_resolution_query(args : T.ResolutionQueryArgs) : async Result<T.ResolutionPage> {
    none(args.cursor, args.limit);
  };

  // §9

  public query func ggg_tender_list(args : T.TenderListArgs) : async Result<T.TenderPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_tender_get(_ : T.GetArgs) : async Result<?T.TenderDetail> {
    #Ok(null);
  };

  // §10

  public query func ggg_quarter_directory(args : T.ListArgs) : async Result<T.QuarterDirectory> {
    switch (none<T.Quarter>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ capital = null; items; next });
    };
  };

  public query func ggg_join_targets() : async Result<T.JoinTargets> {
    #Ok({ default = null; targets = []; mode = null });
  };

  // §11

  public query func ggg_codex_status(args : T.ListArgs) : async Result<T.CodexView> {
    let signing = { agents = []; delegable = []; supervision = #Required };
    switch (none<Text>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ checksum = null; healthy = false; signing; history = items; next });
    };
  };

  public query func ggg_notification_list(args : T.NotificationListArgs) : async Result<T.NotificationPage> {
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  public query ({ caller }) func ggg_events(args : T.ListArgs) : async Result<T.EventPage> {
    switch (requireMember(caller, "realm.monitor")) { case (?e) return #Err(e); case null {} };
    let newest = Iter.map<(Nat, T.Event), T.Event>(Map.reverseEntries(events), func((_, e)) { e });
    switch (page(newest, args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ items; next; archives = [] });
    };
  };

  // §12

  public query ({ caller }) func ggg_realm_monitor() : async Result<T.Monitor> {
    switch (requireMember(caller, "realm.monitor")) { case (?e) return #Err(e); case null {} };
    #Ok({
      status = #Production;
      installed_version = "ggg-fixture 0.5.0";
      cycles = 0;
      memory = 0;
      events = Map.size(events);
    });
  };

  public query ({ caller }) func ggg_realm_export(args : T.ExportArgs) : async Result<T.ExportPage> {
    switch (requireMember(caller, "db.export")) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.entity) == 0) return #Err(#InvalidArgument("entity is empty"));
    switch (none<T.Value>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ entity = args.entity; items; next });
    };
  };

  public query func ggg_realm_info() : async T.Realm {
    {
      id = "1";
      name = "GGG fixture";
      manifesto = "A minimal realm used to test the GGG conformance suite.";
      welcome_message = "";
      status = #Production;
      calendar = null;
      treasury = null;
      accounting_currency = null;
      accounting_currency_decimals = null;
      is_quarter = false;
      is_capital = false;
      federation_realm_id = null;
      federation_codex = null;
      quarter_join_mode = null;
      trusted_principals = [];
      require_marketplace_approval = false;
      trusted_approvers = [];
      voting_threshold = VOTING_THRESHOLD;
      voting_quorum = VOTING_QUORUM;
      open_registration = false;
      logo_url = null;
      background_image_url = null;
      installed_version = "ggg-fixture 0.5.0";
      network = "local";
      member_count = Map.size(members);
    };
  };

  // §13

  public query func ggg_crypto_envelope(_ : Text) : async Result<?T.KeyEnvelope> {
    #Ok(null);
  };

  public query func ggg_crypto_scopes(args : T.ListArgs) : async Result<T.ScopePage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_crypto_access(args : T.AccessArgs) : async Result<T.PrincipalPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_document_list(args : T.DocumentListArgs) : async Result<T.DocumentPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_document_get(_ : Text) : async Result<?T.DocumentAccess> {
    #Ok(null);
  };

  // Operations whose permission no member holds.

  // §3
  public shared ({ caller }) func ggg_department_create(_ : T.DepartmentCreateArgs) : async Result<T.Governed> { nobody(caller, "org.create") };
  public shared ({ caller }) func ggg_department_edit(_ : T.DepartmentEditArgs) : async Result<T.Governed> { nobody(caller, "org.set_policy") };
  public shared ({ caller }) func ggg_department_delete(_ : Text) : async Result<T.Governed> { nobody(caller, "org.set_policy") };
  public shared ({ caller }) func ggg_department_set_policy(_ : T.DepartmentPolicyArgs) : async Result<T.Governed> { nobody(caller, "org.set_policy") };
  public shared ({ caller }) func ggg_position_create(_ : T.PositionCreateArgs) : async Result<T.Governed> { nobody(caller, "org.manage_members") };
  public shared ({ caller }) func ggg_position_edit(_ : T.PositionEditArgs) : async Result<T.Governed> { nobody(caller, "org.manage_members") };
  public shared ({ caller }) func ggg_position_close(_ : Text) : async Result<T.Governed> { nobody(caller, "org.manage_members") };
  public shared ({ caller }) func ggg_appoint(_ : T.AppointArgs) : async Result<T.Governed> { nobody(caller, "org.appoint") };
  public shared ({ caller }) func ggg_appoint_acting(_ : T.AppointArgs) : async Result<T.Governed> { nobody(caller, "org.appoint") };
  public shared ({ caller }) func ggg_appointment_end(_ : Text) : async Result<T.Governed> { nobody(caller, "org.appoint") };
  public shared ({ caller }) func ggg_department_expel(_ : T.ExpelArgs) : async Result<T.Governed> { nobody(caller, "org.expel") };
  public shared ({ caller }) func ggg_authority_grant(_ : T.AuthorityGrantArgs) : async Result<T.Governed> { nobody(caller, "org.grant_authority") };
  public shared ({ caller }) func ggg_authority_revoke(_ : Text) : async Result<T.Governed> { nobody(caller, "org.grant_authority") };
  public shared ({ caller }) func ggg_organization_register(_ : T.OrganizationRegisterArgs) : async Result<T.Organization> { nobody(caller, "organization.add") };
  public shared ({ caller }) func ggg_organization_edit(_ : T.OrganizationEditArgs) : async Result<T.Organization> { nobody(caller, "organization.edit") };
  public shared ({ caller }) func ggg_representative_add(_ : T.RepresentativeAddArgs) : async Result<T.Appointment> { nobody(caller, "organization.edit") };
  public shared ({ caller }) func ggg_representative_remove(_ : Text) : async Result<T.Appointment> { nobody(caller, "organization.edit") };
  public shared ({ caller }) func ggg_organization_set_status(_ : T.OrganizationStatusArgs) : async Result<T.Governed> { nobody(caller, "organization.delete") };

  // §5
  public shared ({ caller }) func ggg_treasury_configure(_ : T.TreasuryConfigureArgs) : async Result<T.Governed> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_token_register(_ : T.TokenRegisterArgs) : async Result<T.Governed> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_nft_token_register(_ : T.NFTTokenRegisterArgs) : async Result<T.Governed> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_transfer_create(_ : T.TransferCreateArgs) : async Result<T.Governed> { nobody(caller, "transfer.create") };
  public shared ({ caller }) func ggg_transfer_revert(_ : T.TransferRevertArgs) : async Result<T.Governed> { nobody(caller, "transfer.delete") };
  public shared ({ caller }) func ggg_invoice_create(_ : T.InvoiceCreateArgs) : async Result<T.InvoiceCreated> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_invoice_check(_ : T.InvoiceCheckArgs) : async Result<T.Invoice> { nobody(caller, "self.invoice_refresh") };
  public shared ({ caller }) func ggg_invoice_refresh(_ : T.InvoiceRefreshArgs) : async Result<T.InvoicePage> { nobody(caller, "invoice.refresh") };
  public shared ({ caller }) func ggg_fund_create(_ : T.FundCreateArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_period_open(_ : T.PeriodOpenArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_period_close(_ : Text) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_budget_draft(_ : T.BudgetDraftArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_budget_propose(_ : Text) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_budget_amend(_ : T.BudgetAmendArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_allocation_rule_draft(_ : T.AllocationRuleDraftArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_allocation_rule_propose(_ : Text) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_payroll_run(_ : T.PayrollRunArgs) : async Result<T.Governed> { nobody(caller, "org.manage_budget") };
  public shared ({ caller }) func ggg_report_issue(_ : T.ReportIssueArgs) : async Result<T.FinancialReport> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_tax_policy_draft(_ : T.TaxPolicyDraftArgs) : async Result<T.Governed> { nobody(caller, "tax.manage") };
  public shared ({ caller }) func ggg_tax_policy_propose(_ : Text) : async Result<T.Governed> { nobody(caller, "tax.manage") };
  public shared ({ caller }) func ggg_tax_assess(_ : T.TaxAssessArgs) : async Result<T.TaxAssessPage> { nobody(caller, "tax.assess") };
  public shared ({ caller }) func ggg_tax_declare(_ : T.TaxDeclareArgs) : async Result<T.TaxDeclared> { nobody(caller, "tax.declare") };
  public shared ({ caller }) func ggg_payment_account_add(_ : T.PaymentAccountAddArgs) : async Result<T.PaymentAccount> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_payment_account_remove(_ : T.PaymentAccountRemoveArgs) : async Result<T.PaymentAccount> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_token_force_transfer(_ : T.ForceTransferArgs) : async Result<T.Governed> { nobody(caller, "token.force_transfer") };
  public shared ({ caller }) func ggg_token_freeze(_ : T.FreezeArgs) : async Result<T.Governed> { nobody(caller, "token.force_transfer") };

  // §6
  public shared ({ caller }) func ggg_land_register(_ : T.LandRegisterArgs) : async Result<T.Governed> { nobody(caller, "nft.mint") };
  public shared ({ caller }) func ggg_land_transfer(_ : T.LandTransferArgs) : async Result<T.Governed> { nobody(caller, "nft.force_transfer") };
  public shared ({ caller }) func ggg_land_mint_nft(_ : T.LandMintArgs) : async Result<Nat> { nobody(caller, "nft.mint") };
  public shared ({ caller }) func ggg_land_freeze(_ : T.LandFreezeArgs) : async Result<T.Land> { nobody(caller, "nft.freeze") };
  public shared ({ caller }) func ggg_land_unfreeze(_ : Text) : async Result<T.Land> { nobody(caller, "nft.freeze") };
  public shared ({ caller }) func ggg_zone_set(_ : T.ZoneSetArgs) : async Result<T.Zone> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_zone_clear(_ : T.ZoneClearArgs) : async Result<T.Zone> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_credential_issue(_ : T.CredentialIssueArgs) : async Result<T.CredentialIssued> { nobody(caller, "credential.sign") };
  public shared ({ caller }) func ggg_credential_revoke(_ : T.CredentialRevokeArgs) : async Result<Nat> { nobody(caller, "credential.sign") };

  // §7
  public shared ({ caller }) func ggg_license_apply(_ : T.LicenseApplyArgs) : async Result<T.License> { nobody(caller, "license.apply") };
  public shared ({ caller }) func ggg_license_renew(_ : T.LicenseRenewArgs) : async Result<T.License> { nobody(caller, "license.apply") };
  public shared ({ caller }) func ggg_license_decide(_ : T.LicenseDecideArgs) : async Result<T.License> { nobody(caller, "license.issue") };
  public shared ({ caller }) func ggg_license_suspend(_ : T.LicenseSuspendArgs) : async Result<T.License> { nobody(caller, "license.revoke") };
  public shared ({ caller }) func ggg_license_revoke(_ : Text) : async Result<T.License> { nobody(caller, "license.revoke") };

  // §8
  public shared ({ caller }) func ggg_dispute_file(_ : T.DisputeFileArgs) : async Result<T.Dispute> { nobody(caller, "dispute.create") };
  public shared ({ caller }) func ggg_dispute_withdraw(_ : T.DisputeWithdrawArgs) : async Result<T.Dispute> { nobody(caller, "dispute.create") };
  public shared ({ caller }) func ggg_dispute_accept(_ : T.DisputeAcceptArgs) : async Result<T.Case> { nobody(caller, "dispute.accept") };
  public shared ({ caller }) func ggg_dispute_reject(_ : Text) : async Result<T.Dispute> { nobody(caller, "dispute.accept") };
  public shared ({ caller }) func ggg_case_assign(_ : T.CaseAssignArgs) : async Result<T.Case> { nobody(caller, "dispute.assign") };
  public shared ({ caller }) func ggg_evidence_submit(_ : T.EvidenceSubmitArgs) : async Result<Text> { nobody(caller, "dispute.create") };
  public shared ({ caller }) func ggg_evidence_evaluate(_ : T.EvidenceEvaluateArgs) : async Result<Bool> { nobody(caller, "evidence.evaluate") };
  public shared ({ caller }) func ggg_verdict_draft(_ : T.VerdictDraftArgs) : async Result<T.Verdict> { nobody(caller, "resolution.draft") };
  public shared ({ caller }) func ggg_verdict_issue(_ : Text) : async Result<T.Verdict> { nobody(caller, "resolution.issue") };
  public shared ({ caller }) func ggg_verdict_finalize(_ : Text) : async Result<T.Verdict> { nobody(caller, "resolution.issue") };
  public shared ({ caller }) func ggg_verdict_link_contract(_ : T.VerdictContractArgs) : async Result<T.Verdict> { nobody(caller, "resolution.link_contract") };
  public shared ({ caller }) func ggg_verdict_modify_terms(_ : T.VerdictTermsArgs) : async Result<T.Verdict> { nobody(caller, "resolution.link_contract") };
  public shared ({ caller }) func ggg_appeal_file(_ : T.AppealFileArgs) : async Result<T.Appeal> { nobody(caller, "dispute.create") };
  public shared ({ caller }) func ggg_appeal_decide(_ : T.AppealDecideArgs) : async Result<T.Appeal> { nobody(caller, "appeal.allow") };
  public shared ({ caller }) func ggg_penalty_execute(_ : T.PenaltyExecuteArgs) : async Result<T.Penalty> { nobody(caller, "fine.apply") };
  public shared ({ caller }) func ggg_enforcement_record(_ : T.EnforcementArgs) : async Result<T.Event> { nobody(caller, "enforcement.record") };
  public shared ({ caller }) func ggg_enforcement_escalate(_ : T.EnforcementArgs) : async Result<T.Notification> { nobody(caller, "enforcement.record") };
  public shared ({ caller }) func ggg_enforcement_notify(_ : T.EnforcementNotifyArgs) : async Result<T.Notification> { nobody(caller, "enforcement.record") };
  public shared ({ caller }) func ggg_court_create(_ : T.CourtCreateArgs) : async Result<T.Governed> { nobody(caller, "org.create") };
  public shared ({ caller }) func ggg_judge_appoint(_ : T.JudgeAppointArgs) : async Result<T.Governed> { nobody(caller, "org.create") };
  public shared ({ caller }) func ggg_judge_revoke(_ : Text) : async Result<T.Governed> { nobody(caller, "org.create") };

  // §9
  public shared ({ caller }) func ggg_tender_create(_ : T.TenderCreateArgs) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_tender_open(_ : Text) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_tender_close(_ : Text) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_tender_cancel(_ : Text) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_bid_submit(_ : T.BidSubmitArgs) : async Result<T.Bid> { nobody(caller, "bid.submit") };
  public shared ({ caller }) func ggg_bid_withdraw(_ : T.BidWithdrawArgs) : async Result<T.Bid> { nobody(caller, "bid.submit") };
  public shared ({ caller }) func ggg_bids_reveal(_ : T.BidsRevealArgs) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_bid_score(_ : T.BidScoreArgs) : async Result<T.Bid> { nobody(caller, "bid.evaluate") };
  public shared ({ caller }) func ggg_tender_award(_ : T.TenderAwardArgs) : async Result<T.Governed> { nobody(caller, "tender.manage") };

  // §10
  public shared ({ caller }) func ggg_quarter_register(_ : T.QuarterRegisterArgs) : async Result<T.Governed> { nobody(caller, "quarter.register") };
  public shared ({ caller }) func ggg_quarter_deregister(_ : Text) : async Result<T.Governed> { nobody(caller, "quarter.register") };
  public shared ({ caller }) func ggg_quarter_configure(_ : T.QuarterConfigureArgs) : async Result<T.Governed> { nobody(caller, "quarter.register") };
  public shared ({ caller }) func ggg_quarter_secede() : async Result<T.Governed> { nobody(caller, "quarter.secede") };
  public shared ({ caller }) func ggg_quarter_join_federation(_ : T.JoinFederationArgs) : async Result<T.Governed> { nobody(caller, "quarter.join_federation") };
  public shared ({ caller }) func ggg_self_change_quarter(_ : T.ChangeQuarterArgs) : async Result<T.Forward> { nobody(caller, "self.change_quarter") };
  public shared ({ caller }) func ggg_federal_vote_propose(_ : T.FederalVoteProposeArgs) : async Result<T.FederalVote> { nobody(caller, "federal_vote.propose") };
  public shared ({ caller }) func ggg_federal_vote_cancel(_ : Text) : async Result<T.Governed> { nobody(caller, "federal_vote.manage") };
  public shared func ggg_federal_vote_finalize(_ : Text) : async Result<T.FederalVote> { #Err(#NotFound) };
  public shared ({ caller }) func ggg_federation_message(_ : T.FederationMessageArgs) : async Result<?T.Value> { nobody(caller, "quarter.sync") };
  public shared ({ caller }) func ggg_quarter_sync() : async Result<T.QuarterDirectory> { nobody(caller, "quarter.sync") };
  public shared ({ caller }) func ggg_quarter_report(_ : T.QuarterReportArgs) : async Result<T.QuarterReport> { nobody(caller, "quarter.sync") };

  // §11
  public shared ({ caller }) func ggg_codex_install(_ : T.CodexSource) : async Result<T.Governed> { nobody(caller, "codex.install") };
  public shared ({ caller }) func ggg_codex_uninstall() : async Result<T.Governed> { nobody(caller, "codex.install") };
  public shared ({ caller }) func ggg_codex_revert() : async Result<T.Governed> { nobody(caller, "codex.install") };
  public shared ({ caller }) func ggg_notification_read(_ : T.NotificationReadArgs) : async Result<T.NotificationsRead> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_notification_send(_ : T.NotificationSendArgs) : async Result<T.Notification> { nobody(caller, "notification.send") };

  // §12
  public shared ({ caller }) func ggg_setup_state() : async Result<T.SetupState> { nobody(caller, "realm.configure") };
  public shared ({ caller }) func ggg_setup_step(_ : T.SetupStep) : async Result<T.SetupState> { nobody(caller, "realm.configure") };
  public shared ({ caller }) func ggg_setup_launch() : async Result<T.Realm> { nobody(caller, "realm.configure") };
  // The fixture is installed already launched, with no host: nobody may install it again.
  func notHost<A>(caller : Principal) : Result<A> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    #Err(#Forbidden({ permission = null; message = "Only the realm's host does this, during setup." }));
  };
  public shared ({ caller }) func ggg_host_install(_ : T.HostInstallArgs) : async Result<T.SetupState> { notHost(caller) };
  public shared ({ caller }) func ggg_host_infrastructure(_ : T.HostInfrastructure) : async Result<T.SetupState> {
    notHost(caller);
  };
  public shared ({ caller }) func ggg_realm_configure(_ : T.RealmConfigureArgs) : async Result<T.Governed> { nobody(caller, "realm.configure") };
  public shared ({ caller }) func ggg_realm_configure_branding(_ : T.BrandingArgs) : async Result<T.Governed> { nobody(caller, "realm.configure.branding") };
  public shared ({ caller }) func ggg_realm_configure_tokens(_ : T.TokensArgs) : async Result<T.Governed> { nobody(caller, "realm.configure.tokens") };
  public shared ({ caller }) func ggg_realm_configure_trust_policy(_ : T.TrustPolicyArgs) : async Result<T.Governed> { nobody(caller, "realm.configure.trust_policy") };
  public shared ({ caller }) func ggg_realm_register(_ : T.RealmRegisterArgs) : async Result<T.Governed> { nobody(caller, "realm.register") };
  public shared ({ caller }) func ggg_realm_upgrade(_ : T.RealmUpgradeArgs) : async Result<T.Governed> { nobody(caller, "realm.upgrade") };

  // §13
  public shared ({ caller }) func ggg_crypto_public_key() : async Result<Blob> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_crypto_derive_key(_ : Blob) : async Result<Blob> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_crypto_grant(_ : T.KeyGrantArgs) : async Result<Nat> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_crypto_revoke(_ : T.KeyRevokeArgs) : async Result<Nat> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_document_store(_ : T.DocumentStoreArgs) : async Result<T.DocumentStored> { nobody(caller, "document.manage") };
  public shared ({ caller }) func ggg_document_share(_ : T.DocumentShareArgs) : async Result<Nat> { nobody(caller, "document.manage") };
  public shared ({ caller }) func ggg_document_revoke(_ : T.DocumentRevokeArgs) : async Result<Nat> { nobody(caller, "document.manage") };
  public shared ({ caller }) func ggg_document_delete(_ : T.DocumentDeleteArgs) : async Result<T.DocumentDeleted> { nobody(caller, "document.manage") };

};
