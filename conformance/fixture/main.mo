/// A minimal GGG GOS, used to test the conformance suite. It implements every method of ggg.did.
/// Members are fixed at install time. Anyone listed may propose and vote. The only department is
/// the root, so every proposal is realm-wide. Nobody has granted a delegation, so nobody acts on
/// another's behalf. Every other domain is empty, which the model allows.
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

  func noDelegation(permission : Text) : T.GggError {
    #Forbidden({ permission = ?permission; message = "No active delegation from that principal covers this." });
  };

  /// A call a proposal may make: one of this canister's update methods, with arguments that decode.
  func checkCall(method : Text, arg : Blob) : ?T.GggError {
    let decodes = switch (method) {
      case "ggg_proposal_create" { let a : ?T.ProposalCreateArgs = from_candid (arg); a != null };
      case "ggg_proposal_vote" { let a : ?T.ProposalVoteArgs = from_candid (arg); a != null };
      case _ return ?#InvalidArgument(method # " is not an update method of this canister");
    };
    if (decodes) null else ?#InvalidArgument("arg does not decode as the arguments of " # method);
  };

  func audit(op : Text, user : Principal) {
    let id = Map.size(events) + 1;
    let event = {
      id = Nat.toText(id);
      op;
      user = ?user;
      by = null;
      agent = false;
      supervisor = null;
      origin = "user";
      args = #Map([]);
      result = #Text("ok");
      at = now();
    };
    Map.add(events, Nat.compare, id, event);
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
      threshold = 5_000;
      quorum = 0;
      tally = { yes = 0; no = 0; abstain = 0; eligible = ?Map.size(members) };
      result = null;
    };
    Map.add(proposals, Nat.compare, n, p);
    audit("proposal_create", caller);
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
    audit("proposal_vote", caller);
    #Ok(v);
  };

  // §5

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

  // §11

  public query func ggg_codex_status(args : T.ListArgs) : async Result<T.CodexView> {
    let signing = { agents = []; delegable = []; supervision = #Required };
    switch (none<T.Codex>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ codex = null; healthy = false; signing; history = items; next });
    };
  };

  public query func ggg_notification_list(args : T.NotificationListArgs) : async Result<T.NotificationPage> {
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  public query func ggg_events(args : T.ListArgs) : async Result<T.EventPage> {
    page(Iter.map<(Nat, T.Event), T.Event>(Map.reverseEntries(events), func((_, e)) { e }), args.cursor, args.limit);
  };

  // §12

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
      open_registration = false;
      logo_url = null;
      background_image_url = null;
      installed_version = "ggg-fixture 0.5.0";
      network = "local";
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
};
