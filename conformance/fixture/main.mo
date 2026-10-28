/// A minimal GGG GOS, used to test the conformance suite. It implements the methods ggg.did binds.
/// Members are fixed at install time. Anyone listed may propose and vote. The only department is
/// the root, so every proposal is realm-wide. Nobody has granted a delegation, so nobody acts on
/// another's behalf.
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

persistent actor class GggFixture(initMembers : [Principal]) {

  type Timestamp = Nat64;

  type GggError = {
    #NotFound;
    #Unauthenticated;
    #Forbidden : { permission : ?Text; message : Text };
    #InvalidArgument : Text;
    #Conflict : Text;
    #Unavailable : Text;
    #GenericError : { error_code : Nat; message : Text };
  };

  type Result<T> = { #Ok : T; #Err : GggError };

  type ListArgs = { cursor : ?Text; limit : ?Nat32 };

  type Page<T> = { items : [T]; next : ?Text };

  type Realm = {
    id : Text;
    name : Text;
    manifesto : Text;
    welcome_message : Text;
    status : { #Setup; #Alpha; #Beta; #Production; #Deprecation; #Terminated };
    calendar : ?Text;
    treasury : ?Text;
    accounting_currency : ?Text;
    accounting_currency_decimals : ?Nat8;
    is_quarter : Bool;
    is_capital : Bool;
    federation_realm_id : ?Text;
    federation_codex : ?Text;
    quarter_join_mode : ?Text;
    trusted_principals : [Principal];
    require_marketplace_approval : Bool;
    trusted_approvers : [Text];
    open_registration : Bool;
    logo_url : ?Text;
    background_image_url : ?Text;
    installed_version : Text;
    network : Text;
  };

  type User = {
    id : Principal;
    nickname : ?Text;
    avatar : ?Text;
    home_quarter : ?Text;
    profiles : [Text];
    private_data : ?Blob;
  };

  type Member = {
    id : Text;
    user : Principal;
    status : { #Active; #Inactive; #Suspended; #Banned };
    joined_at : ?Timestamp;
  };

  type UserEntry = { user : User; member : ?Member };

  type ProposalStatus = {
    #Draft;
    #Voting;
    #Accepted;
    #Rejected;
    #Expired;
    #Executed;
    #Failed;
    #Withdrawn;
  };

  type ProposalAction = {
    #Motion;
    #Call : { method : Text; arg : Blob };
    #Code : { url : Text; checksum : Text };
  };

  type Tally = { yes : Nat; no : Nat; abstain : Nat; eligible : ?Nat };

  type Proposal = {
    id : Text;
    title : Text;
    description : Text;
    proposer : Principal;
    on_behalf_of : ?Principal;
    department : ?Text;
    action : ProposalAction;
    status : ProposalStatus;
    opens_at : ?Timestamp;
    deadline : ?Timestamp;
    threshold : Nat;
    quorum : Nat;
    tally : Tally;
    result : ?{ #Reply : Blob; #Error : Text };
  };

  type VoteChoice = { #Yes; #No; #Abstain };

  type Vote = {
    id : Text;
    proposal : Text;
    voter : Principal;
    cast_by : ?Principal;
    choice : VoteChoice;
    cast_at : Timestamp;
  };

  type ProposalGetArgs = { id : Text; cursor : ?Text; limit : ?Nat32 };
  type ProposalDetail = { proposal : Proposal; votes : [Vote]; next : ?Text };
  type ProposalListArgs = { cursor : ?Text; limit : ?Nat32; status : ?ProposalStatus };

  type ProposalCreateArgs = {
    title : Text;
    description : Text;
    department : ?Text;
    action : ProposalAction;
    on_behalf_of : ?Principal;
  };

  type ProposalVoteArgs = { proposal : Text; choice : VoteChoice; on_behalf_of : ?Principal };

  let DEFAULT_LIMIT = 20;
  let MAX_LIMIT = 100;
  let VOTING_WINDOW_NS : Nat64 = 7 * 24 * 3600 * 1_000_000_000;
  let ROOT = "root";

  func now() : Timestamp = Nat64.fromNat(Int.abs(Time.now()));

  let createdAt = now();
  let members = Map.empty<Principal, UserEntry>();
  for (p in initMembers.vals()) {
    let user = { id = p; nickname = null; avatar = null; home_quarter = null; profiles = ["member"]; private_data = null };
    let member = { id = Principal.toText(p); user = p; status = #Active; joined_at = ?createdAt };
    Map.add(members, Principal.compare, p, { user; member = ?member });
  };
  let proposals = Map.empty<Nat, Proposal>();
  let votes = Map.empty<Nat, Map.Map<Principal, Vote>>();
  var nextProposal = 1;

  func pageSize(limit : ?Nat32) : Nat {
    switch (limit) {
      case null DEFAULT_LIMIT;
      case (?l) Nat.max(1, Nat.min(MAX_LIMIT, Nat32.toNat(l)));
    };
  };

  /// Cursors are offsets into the key order, written as decimal text.
  func page<T>(all : Iter.Iter<T>, cursor : ?Text, limit : ?Nat32) : Result<Page<T>> {
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

  func requireMember(caller : Principal, permission : Text) : ?GggError {
    if (Principal.isAnonymous(caller)) return ?#Unauthenticated;
    switch (Map.get(members, Principal.compare, caller)) {
      case (?{ member = ?{ status = #Active } }) null;
      case _ ?#Forbidden({ permission = ?permission; message = "Only active members may do this." });
    };
  };

  func noDelegation(permission : Text) : GggError {
    #Forbidden({ permission = ?permission; message = "No active delegation from that principal covers this." });
  };

  /// A call a proposal may make: one of this canister's update methods, with arguments that decode.
  func checkCall(method : Text, arg : Blob) : ?GggError {
    let decodes = switch (method) {
      case "ggg_proposal_create" { let a : ?ProposalCreateArgs = from_candid (arg); a != null };
      case "ggg_proposal_vote" { let a : ?ProposalVoteArgs = from_candid (arg); a != null };
      case _ return ?#InvalidArgument(method # " is not an update method of this canister");
    };
    if (decodes) null else ?#InvalidArgument("arg does not decode as the arguments of " # method);
  };

  func findProposal(id : Text) : ?(Nat, Proposal) {
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

  func ballots(n : Nat) : Map.Map<Principal, Vote> {
    switch (Map.get(votes, Nat.compare, n)) {
      case (?b) b;
      case null {
        let b = Map.empty<Principal, Vote>();
        Map.add(votes, Nat.compare, n, b);
        b;
      };
    };
  };

  func add(t : Tally, choice : VoteChoice, delta : Int) : Tally {
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

  public query func ggg_realm_info() : async Realm {
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
      installed_version = "ggg-fixture 0.4.0";
      network = "local";
    };
  };

  public query func ggg_user_get(p : Principal) : async Result<?UserEntry> {
    #Ok(Map.get(members, Principal.compare, p));
  };

  public query func ggg_user_list(args : ListArgs) : async Result<Page<UserEntry>> {
    page(Map.values(members), args.cursor, args.limit);
  };

  public query func ggg_proposal_get(args : ProposalGetArgs) : async Result<?ProposalDetail> {
    let (n, p) = switch (findProposal(args.id)) { case null return #Ok(null); case (?found) found };
    switch (page(Map.values(ballots(n)), args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ proposal = p; votes = items; next });
    };
  };

  public query func ggg_proposal_list(args : ProposalListArgs) : async Result<Page<Proposal>> {
    let all = switch (args.status) {
      case null Map.values(proposals);
      case (?s) Iter.filter<Proposal>(Map.values(proposals), func(p) { p.status == s });
    };
    page(all, args.cursor, args.limit);
  };

  public shared ({ caller }) func ggg_proposal_create(args : ProposalCreateArgs) : async Result<Text> {
    switch (requireMember(caller, "proposal.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.create"));
    switch (args.department) {
      case (?d) { if (d != ROOT) return #Err(#NotFound) };
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
    let p : Proposal = {
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
    #Ok(p.id);
  };

  public shared ({ caller }) func ggg_proposal_vote(args : ProposalVoteArgs) : async Result<Vote> {
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
    let v : Vote = {
      id = p.id # ":" # Principal.toText(caller);
      proposal = p.id;
      voter = caller;
      cast_by = null;
      choice = args.choice;
      cast_at = t;
    };
    Map.add(b, Principal.compare, caller, v);
    Map.add(proposals, Nat.compare, n, { p with tally });
    #Ok(v);
  };
};
