/// A minimal GGG-1 and GGG-2 implementation, used to test the conformance suite.
/// Members are fixed at install time. Anyone listed may propose and vote. The only department is
/// the root, so every proposal is realm-wide.
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

  type Value = {
    #Nat : Nat;
    #Int : Int;
    #Text : Text;
    #Blob : Blob;
    #Array : [Value];
    #Map : [(Text, Value)];
  };

  type GggError = {
    #NotFound;
    #Unauthenticated;
    #Forbidden : { permission : ?Text; message : Text };
    #InvalidArgument : Text;
    #Conflict : Text;
    #Unsupported : Text;
    #Unavailable : Text;
    #GenericError : { error_code : Nat; message : Text };
  };

  type Result<T> = { #Ok : T; #Err : GggError };

  type SupportedStandard = { name : Text; url : Text };

  type ListArgs = { cursor : ?Text; limit : ?Nat32 };

  type Page<T> = { items : [T]; next : ?Text };

  type Realm = {
    name : Text;
    manifesto : Text;
    welcome_message : Text;
    status : { #Setup; #Alpha; #Beta; #Production; #Deprecation; #Terminated };
    accounting_currency : ?{ symbol : Text; decimals : Nat8 };
    logo_url : ?Text;
    background_image_url : ?Text;
    open_registration : Bool;
    is_capital : Bool;
    implementation : { name : Text; version : Text; url : ?Text };
    member_count : ?Nat;
  };

  type Member = {
    id : Principal;
    status : { #Active; #Inactive; #Suspended; #Banned };
    joined_at : ?Timestamp;
    nickname : ?Text;
    avatar : ?Text;
    home_quarter : ?Text;
    profiles : [Text];
  };

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
    #Operation : { op : Text; args : Value };
    #Code : { url : Text; checksum : Text };
  };

  type Tally = { yes : Nat; no : Nat; abstain : Nat; eligible : ?Nat };

  type Proposal = {
    id : Text;
    title : Text;
    description : Text;
    proposer : Principal;
    department : ?Text;
    action : ProposalAction;
    status : ProposalStatus;
    opens_at : ?Timestamp;
    deadline : ?Timestamp;
    threshold_bps : Nat;
    quorum_bps : Nat;
    tally : Tally;
    result : ?Value;
  };

  type ProposalSummary = {
    id : Text;
    title : Text;
    proposer : Principal;
    department : ?Text;
    status : ProposalStatus;
    deadline : ?Timestamp;
  };

  type ProposalListArgs = { cursor : ?Text; limit : ?Nat32; status : ?ProposalStatus };

  type ProposalCreateArgs = {
    title : Text;
    description : Text;
    department : ?Text;
    action : ProposalAction;
    on_behalf_of : ?Principal;
  };

  type VoteChoice = { #Yes; #No; #Abstain };

  type Vote = {
    id : Text;
    proposal_id : Text;
    voter : Principal;
    cast_by : ?Principal;
    choice : VoteChoice;
    cast_at : Timestamp;
  };

  type ProposalVoteArgs = { proposal_id : Text; choice : VoteChoice; on_behalf_of : ?Principal };

  type ProposalVotesArgs = { proposal_id : Text; voter : ?Principal; cursor : ?Text; limit : ?Nat32 };

  type Operation = {
    name : Text;
    description : Text;
    permission : ?Text;
    read : Bool;
    delegable : Bool;
    governed : Bool;
    signing : Bool;
    provided_by : Text;
    args_schema : ?Text;
    result_schema : ?Text;
  };

  type OperationArgs = { op : Text; args : Value; on_behalf_of : ?Principal };

  let DEFAULT_LIMIT = 20;
  let MAX_LIMIT = 100;
  let VOTING_WINDOW_NS : Nat64 = 7 * 24 * 3600 * 1_000_000_000;
  let ROOT = "root";
  let SPEC = "https://github.com/smart-social-contracts/ggg/blob/main/standards/";

  let OPERATIONS : [Operation] = [
    {
      name = "fixture.echo";
      description = "Returns its arguments.";
      permission = null;
      read = true;
      delegable = false;
      governed = false;
      signing = false;
      provided_by = "ggg-fixture";
      args_schema = null;
      result_schema = null;
    },
    {
      name = "fixture.counter_increment";
      description = "Adds one to a counter and returns it.";
      permission = ?"member";
      read = false;
      delegable = false;
      governed = false;
      signing = false;
      provided_by = "ggg-fixture";
      args_schema = ?"{\"type\":\"object\",\"additionalProperties\":false}";
      result_schema = ?"{\"type\":\"integer\"}";
    },
  ];

  func now() : Timestamp = Nat64.fromNat(Int.abs(Time.now()));

  let createdAt = now();
  let members = Map.empty<Principal, Member>();
  for (p in initMembers.vals()) {
    Map.add(
      members,
      Principal.compare,
      p,
      {
        id = p;
        status = #Active;
        joined_at = ?createdAt;
        nickname = null;
        avatar = null;
        home_quarter = null;
        profiles = ["member"];
      },
    );
  };
  let proposals = Map.empty<Nat, Proposal>();
  let votes = Map.empty<Nat, Map.Map<Principal, Vote>>();
  var nextProposal = 1;
  var counter = 0;

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

  func member(p : Principal) : ?Member = Map.get(members, Principal.compare, p);

  func requireMember(caller : Principal) : ?GggError {
    if (Principal.isAnonymous(caller)) return ?#Unauthenticated;
    switch (member(caller)) {
      case (?{ status = #Active }) null;
      case _ ?#Forbidden({ permission = ?"member"; message = "Only active members may do this." });
    };
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

  func summary(p : Proposal) : ProposalSummary = {
    id = p.id;
    title = p.title;
    proposer = p.proposer;
    department = p.department;
    status = p.status;
    deadline = p.deadline;
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

  func operation(name : Text) : ?Operation = Array.find<Operation>(OPERATIONS, func(o) { o.name == name });

  public query func icrc10_supported_standards() : async [SupportedStandard] {
    [
      { name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md" },
      { name = "GGG-1"; url = SPEC # "GGG-1.md" },
      { name = "GGG-2"; url = SPEC # "GGG-2.md" },
    ];
  };

  public query func ggg1_realm_info() : async Realm {
    var active = 0;
    for (m in Map.values(members)) { if (m.status == #Active) active += 1 };
    {
      name = "GGG fixture";
      manifesto = "A minimal realm used to test the GGG conformance suite.";
      welcome_message = "";
      status = #Production;
      accounting_currency = null;
      logo_url = null;
      background_image_url = null;
      open_registration = false;
      is_capital = false;
      implementation = {
        name = "ggg-fixture";
        version = "0.2.0";
        url = ?"https://github.com/smart-social-contracts/ggg/tree/main/conformance/fixture";
      };
      member_count = ?active;
    };
  };

  public query func ggg1_user_get(p : Principal) : async Result<?Member> {
    #Ok(member(p));
  };

  public query func ggg1_user_list(args : ListArgs) : async Result<Page<Member>> {
    page(Map.values(members), args.cursor, args.limit);
  };

  public query func ggg1_proposal_get(id : Text) : async Result<?Proposal> {
    switch (findProposal(id)) {
      case null #Ok(null);
      case (?(_, p)) #Ok(?p);
    };
  };

  public query func ggg1_proposal_list(args : ProposalListArgs) : async Result<Page<ProposalSummary>> {
    let all = switch (args.status) {
      case null Map.values(proposals);
      case (?s) Iter.filter<Proposal>(Map.values(proposals), func(p) { p.status == s });
    };
    page(Iter.map<Proposal, ProposalSummary>(all, summary), args.cursor, args.limit);
  };

  public query func ggg1_proposal_votes(args : ProposalVotesArgs) : async Result<Page<Vote>> {
    let (n, _) = switch (findProposal(args.proposal_id)) { case null return #Err(#NotFound); case (?found) found };
    let b = ballots(n);
    let all = switch (args.voter) {
      case null Map.values(b);
      case (?v) {
        switch (Map.get(b, Principal.compare, v)) {
          case null Iter.empty<Vote>();
          case (?vote) Iter.singleton(vote);
        };
      };
    };
    page(all, args.cursor, args.limit);
  };

  public shared ({ caller }) func ggg1_proposal_create(args : ProposalCreateArgs) : async Result<Text> {
    switch (requireMember(caller)) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(#Unsupported("delegation"));
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
      case (#Operation { op }) {
        if (operation(op) == null) return #Err(#InvalidArgument("unknown operation " # op));
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
      department = null;
      action = args.action;
      status = #Voting;
      opens_at = ?t;
      deadline = ?(t + VOTING_WINDOW_NS);
      threshold_bps = 5_000;
      quorum_bps = 0;
      tally = { yes = 0; no = 0; abstain = 0; eligible = ?Map.size(members) };
      result = null;
    };
    Map.add(proposals, Nat.compare, n, p);
    #Ok(p.id);
  };

  public shared ({ caller }) func ggg1_proposal_vote(args : ProposalVoteArgs) : async Result<Vote> {
    switch (requireMember(caller)) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(#Unsupported("delegation"));
    let (n, p) = switch (findProposal(args.proposal_id)) { case null return #Err(#NotFound); case (?found) found };
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
      proposal_id = p.id;
      voter = caller;
      cast_by = null;
      choice = args.choice;
      cast_at = t;
    };
    Map.add(b, Principal.compare, caller, v);
    Map.add(proposals, Nat.compare, n, { p with tally });
    #Ok(v);
  };

  public query func ggg2_operation(name : Text) : async Result<?Operation> {
    #Ok(operation(name));
  };

  public query func ggg2_operations(args : ListArgs) : async Result<Page<Operation>> {
    page(OPERATIONS.vals(), args.cursor, args.limit);
  };

  func checkRun(args : OperationArgs, query_ : Bool) : Result<Operation> {
    let o = switch (operation(args.op)) {
      case null return #Err(#Unsupported("unknown operation " # args.op));
      case (?o) o;
    };
    if (query_ and not o.read) return #Err(#InvalidArgument(args.op # " changes the realm: use ggg2_call"));
    if (args.on_behalf_of != null and not o.delegable) {
      return #Err(#InvalidArgument(args.op # " is not delegable"));
    };
    #Ok(o);
  };

  public query func ggg2_query(args : OperationArgs) : async Result<Value> {
    switch (checkRun(args, true)) {
      case (#Err(e)) #Err(e);
      case (#Ok(_)) #Ok(args.args);
    };
  };

  public shared ({ caller }) func ggg2_call(args : OperationArgs) : async Result<Value> {
    switch (checkRun(args, false)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ read = true })) #Ok(args.args);
      case (#Ok(_)) {
        switch (requireMember(caller)) { case (?e) return #Err(e); case null {} };
        counter += 1;
        #Ok(#Nat(counter));
      };
    };
  };
};
