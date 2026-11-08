/// A minimal GGG GOS, used to test the conformance suite. It implements every method of ggg.did.
/// Members are fixed at install time. They may propose, vote, manage proposals (open, finalize,
/// execute and stop them), set the realm's governance rule (governance_update, which the root's direct
/// policy applies at once), read the realm and manage their own profile; every other permission is
/// held by nobody, so those operations are refused. There are four departments: the root, with a
/// direct policy, so a governed call on a realm-wide proposal is applied at once; a council under
/// it, deciding 2 of 3 with a 60 % quorum, so a governed call on one of its proposals files a
/// proposal instead; and two committees under the council, each deciding alone, so that a proposal
/// of the council can carry a call on a committee's records where a committee's cannot carry one on
/// its sibling's (I-GOV-13).
/// Members may also edit a department (department_edit, governed by that department, or by the lowest
/// department above both the old and the new parent when it moves) and delete one that has none below
/// it (department_delete, governed by its parent), so a committee can be moved or removed while a
/// proposal that acts on it waits; they hold org.set_policy for that, and department_set_policy is
/// refused. They also create funds and draft and propose budget lines (fund_create, budget_draft,
/// budget_propose, each governed by the fund's owner, or by the root for every fund's lines), with
/// org.manage_budget; a period is a name that period_open records in order, budget_extend copies the
/// previous period's adopted lines fund by fund, and transfer_create moves no money but refuses a
/// category outside a fund's adopted budget (model §5). No department has seats: every member may vote on a
/// department's proposal (its tally.eligible), and its threshold is measured against its policy's n
/// (tally.seats), as I-GOV-3 says: two yes votes carry a council proposal whether two or twenty
/// members vote. The fixture never ends a department vote early (I-GOV-7 allows it, it does not
/// require it): that needs veto holders, who must hold a seat (I-ORG-5). Nor does it settle a
/// proposal as its vote ends or run an accepted action as it finalizes (I-GOV-12): proposal_finalize
/// records the outcome of a vote that has ended, and proposal_execute runs the action. Nobody has
/// granted a delegation, so nobody acts on another's behalf. Every other domain is empty, which the
/// model allows. A proposal's rule is its scope's, the realm's over the votes cast or a
/// department's m/n over its policy's n, unless the proposer states a stricter one, which the
/// fixture stores and applies (I-GOV-3).
/// Links between realms (I-NEST-1 to 3): members vote to take legislation from a sync source and to
/// accept a follower, which the root's direct policy applies at once; each vote records the link,
/// then reads the realms' realm_info to refuse a cycle (Unavailable when one cannot be read), and
/// tells the other side's capital with link_notify, sending the notice again on a timer until it is
/// answered. Every call to another realm is bounded-wait. Notices and reports from anyone but the
/// capital at the other side are refused. The chapters a realm holds, by checksum, are fixed at
/// install time too (the fixture runs no install job), so it can publish releases that name them and
/// serve them with legislation_chapter. codex_install with a Release that the active sync sources'
/// records list alike adds that release to this realm's record as a relayed layer, where the
/// vouching record lists it. codex_install with a Package whose source names a checksum the realm
/// holds makes that checksum the active codex, keeping the history, and codex_revert restores the one
/// it replaced, or any earlier one by checksum; the fixture runs no codex.
import Array "mo:core/Array";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Principal "mo:core/Principal";
import Set "mo:core/Set";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Timer "mo:core/Timer";
import T "Ggg";

persistent actor class GggFixture(initMembers : [Principal], initChapters : [(Text, Blob)]) = this {

  type Result<A> = { #Ok : A; #Err : T.GggError };
  type Page<A> = { items : [A]; next : ?Text };

  let DEFAULT_LIMIT = 20;
  let MAX_LIMIT = 100;
  let MAP_VIEW = 32;
  let WHOLE = 100_000_000; // 100 %, in hundred-millionths
  let MAX_LINKS = 16; // a proposal's own links
  /// The realm's governance rule, set with governance_update: the voting window, and the threshold,
  /// quorum and casting vote of a realm-wide proposal.
  var votingWindow : T.Duration = 7 * 24 * 3600 * 1_000_000_000;
  var votingThreshold : T.Ratio = 50_000_000; // 50 %
  var votingQuorum : T.Ratio = 0;
  var castingVote : ?Principal = null;
  /// The rule that decides a proposal (I-GOV-3). The scope's, over the votes cast, unless the proposer
  /// states a stricter threshold, quorum or basis; the casting vote is the realm's, for a realm-wide
  /// proposal only.
  type Rule = { threshold : T.Ratio; quorum : T.Ratio; threshold_of : T.ThresholdBasis; casting_vote : ?Principal };
  func defaultRule() : Rule = { threshold = votingThreshold; quorum = votingQuorum; threshold_of = #Cast; casting_vote = castingVote };
  /// The rule of a proposal of `department` (I-GOV-3): the realm's, over the votes cast and with its
  /// casting vote, for the root; for any other, m/n of its policy, rounded down, over its n seats, with
  /// the policy's quorum.
  func scopeRule(department : T.Department) : Rule {
    if (department.is_root) return defaultRule();
    {
      threshold = department.policy.m * WHOLE / department.policy.n;
      quorum = department.policy.quorum;
      threshold_of = #Eligible;
      casting_vote = null;
    };
  };
  let NOT_SCHEDULED = "only a proposal whose execution is scheduled can be stopped";
  let NO_MORE_BUDGETING = "closes no period and keeps no allocation rules, payroll or loans";
  let OUT_OF_SCOPE = "a department's proposal carries only the calls that department, or one below it, governs";

  func now() : T.Timestamp = Nat64.fromNat(Int.abs(Time.now()));

  let ROOT_ID = "root";
  let DIRECT : T.Policy = { m = 1; n = 1; quorum = 0; veto = [] };

  func department(id : Text, description : Text, parent : ?Text, policy : T.Policy) : T.Department = {
    id; description; kind = null; parent; is_root = parent == null; head = null; policy; target_policy = null; fund = null;
  };

  /// The root decides alone; the council under it, 2 of 3; the two committees under the council, alone.
  /// department_edit may move a department, so the tree is read as it stands at each check.
  let departments = Map.empty<Text, T.Department>();
  for (d in [
    department(ROOT_ID, "The realm itself.", null, DIRECT),
    department(
      "council",
      "A council under the realm, deciding 2 of 3 with a 60 % quorum.",
      ?ROOT_ID,
      { m = 2; n = 3; quorum = 60_000_000; veto = [] },
    ),
    department("roads", "A committee under the council, deciding alone.", ?"council", DIRECT),
    department("parks", "A committee under the council, deciding alone.", ?"council", DIRECT),
  ].vals()) Map.add(departments, Text.compare, d.id, d);

  func findDepartment(id : Text) : ?T.Department = Map.get(departments, Text.compare, id);

  func direct(policy : T.Policy) : Bool = policy.m == 1 and policy.n == 1;

  /// Whether department `id` is `ancestor` or lies below it, as the departments stand now.
  func within(id : Text, ancestor : Text) : Bool {
    var at = ?id;
    loop {
      let ?d = at else return false;
      if (d == ancestor) return true;
      at := switch (findDepartment(d)) { case (?found) found.parent; case null null };
    };
  };

  /// The lowest department that is `a` or above it and `b` or above it: the root, if no other.
  func lowestAbove(a : Text, b : Text) : Text {
    var at = ?a;
    loop {
      let ?d = at else return ROOT_ID;
      if (within(b, d)) return d;
      at := switch (findDepartment(d)) { case (?found) found.parent; case null null };
    };
  };

  func parentOf(department : T.Department) : Text = switch (department.parent) { case (?p) p; case null ROOT_ID };

  let createdAt = now();
  let members = Map.empty<Principal, T.UserEntry>();
  for (p in initMembers.vals()) {
    let user = {
      id = p;
      nickname = null;
      avatar = null;
      home_quarter = null;
      language = null;
      home_zone = null;
      profiles = ["member"];
      private_data = null;
    };
    let member = { id = Principal.toText(p); user = p; status = #Active; joined_at = ?createdAt };
    Map.add(members, Principal.compare, p, { user; member = ?member });
  };
  let proposals = Map.empty<Nat, T.Proposal>();
  let votes = Map.empty<Nat, Map.Map<Principal, T.Vote>>();
  /// When the last eligible member voted. A vote ends then, if its deadline has not come first.
  let everyoneVotedAt = Map.empty<Nat, T.Timestamp>();
  let events = Map.empty<Nat, T.Event>();
  var nextProposal = 1;
  // Funds and budget lines (model §5): enough to govern a budget by its fund's owner (D19).
  let funds = Map.empty<Text, T.Fund>();
  let budgets = Map.empty<Nat, T.Budget>();
  var nextBudget = 1;
  // The periods, by name, in the order they were opened: the last is the current one.
  var periods : [Text] = [];

  // Links between realms (I-NEST-1 to 3). A side's record exists once that side has voted; `theirs`
  // is learnt from the other side's notice.
  type Link = { mine : Bool; theirs : Bool; ended : ?{ by : Principal; at : T.Timestamp } };
  type Source = { source : T.SyncSourceRef; name : Text; link : Link };
  type FollowerEntry = {
    capital : Principal;
    link : Link;
    layers : [T.ReportedLayer];
    compliance : T.Compliance;
    population : Nat;
    reported_at : ?T.Timestamp;
  };
  let sources = Map.empty<Text, Source>();
  let followers = Map.empty<Principal, FollowerEntry>();
  // The chapters this realm holds, by checksum, and its published record: the releases it relays, as
  // it installed them, then its own (model §11).
  let chapters = Map.empty<Text, Blob>();
  for ((checksum, bytes) in initChapters.vals()) Map.add(chapters, Text.compare, checksum, bytes);
  var relayed : [T.Release] = [];
  var published : [T.Release] = [];
  // The codices installed here, by checksum, with the one each replaced; `codexHistory` in install order.
  type Installed = { previous : ?Text; status : T.CodexStatus };
  let codices = Map.empty<Text, Installed>();
  var codexHistory : [Text] = [];
  var activeCodex : ?Text = null;
  // Notices to the other side of a link that were not answered yet, sent again on a timer (I-NEST-3).
  type Notice = { capital : Principal; side : T.LinkSide; status : T.LinkStatus };
  let pending = Map.empty<Text, Notice>();
  // The proposals whose action is running, which may await another realm: a second execute meanwhile
  // is a Conflict, and the status stays as it was until the action ends (I-GOV-1).
  transient let executing = Set.empty<Nat>();

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

  func isActiveMember(p : Principal) : Bool {
    switch (Map.get(members, Principal.compare, p)) { case (?{ member = ?{ status = #Active } }) true; case _ false };
  };

  func requireMember(caller : Principal, permission : Text) : ?T.GggError {
    if (Principal.isAnonymous(caller)) return ?#Unauthenticated;
    if (isActiveMember(caller)) null else ?#Forbidden({ permission = ?permission; message = "Only active members may do this." });
  };

  /// Refuses an operation whose permission no member holds.
  func nobody<A>(caller : Principal, permission : Text) : Result<A> {
    switch (requireMember(caller, permission)) { case (?e) return #Err(e); case null {} };
    #Err(#Forbidden({ permission = ?permission; message = "No member of this realm holds " # permission # "." }));
  };

  /// Refuses an operation this fixture leaves out, although members hold its permission.
  func notHere<A>(caller : Principal, permission : Text, what : Text) : Result<A> {
    switch (requireMember(caller, permission)) { case (?e) return #Err(e); case null {} };
    #Err(#Forbidden({ permission = null; message = "This fixture " # what # "." }));
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
      case "ggg_proposal_stop" { let a : ?Text = from_candid (arg); a != null };
      case "ggg_department_edit" { let a : ?T.DepartmentEditArgs = from_candid (arg); a != null };
      case "ggg_department_delete" { let a : ?Text = from_candid (arg); a != null };
      case "ggg_fund_create" { let a : ?T.FundCreateArgs = from_candid (arg); a != null };
      case "ggg_budget_draft" { let a : ?T.BudgetDraftArgs = from_candid (arg); a != null };
      case "ggg_budget_propose" { let a : ?T.BudgetProposeArgs = from_candid (arg); a != null };
      case "ggg_transfer_create" { let a : ?T.TransferCreateArgs = from_candid (arg); a != null };
      case "ggg_codex_install" { let a : ?T.CodexSource = from_candid (arg); a != null };
      case "ggg_codex_revert" { let a : ?(?T.CodexRevertArgs) = from_candid (arg); a != null };
      case "ggg_profile_update" { let a : ?T.ProfileUpdateArgs = from_candid (arg); a != null };
      case _ return ?#InvalidArgument(method # " is not an update method of this canister");
    };
    if (decodes) null else ?#InvalidArgument("arg does not decode as the arguments of " # method);
  };

  /// The department a proposal belongs to: the one it is scoped to, the root for a realm-wide one.
  func ownerId(p : T.Proposal) : Text = switch (p.department) { case (?d) d; case null ROOT_ID };

  /// The department that owns `fund`: the root when it names none.
  func fundOwner(fund : Text) : Result<Text> {
    let ?f = Map.get(funds, Text.compare, fund) else return #Err(#NotFound);
    #Ok(switch (f.department) { case (?d) d; case null ROOT_ID });
  };

  /// The department that governs a call (model §1): the owner of the proposal a stop ends; the
  /// department an edit changes, or the lowest department that is, or is above, both the old and the
  /// new parent when the edit moves it; the parent of the department a delete removes; the owner of a fund, or of the
  /// fund a budget names, and the root for a whole-period budget; and the root for a call no department
  /// governs, which only a realm-wide proposal carries.
  func governingDepartment(method : Text, arg : Blob) : Result<T.Department> {
    let id = switch (method) {
      case "ggg_fund_create" {
        let ?args : ?T.FundCreateArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        switch (args.department) { case (?d) d; case null ROOT_ID };
      };
      case "ggg_transfer_create" {
        let ?args : ?T.TransferCreateArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        switch (fundOwner(args.fund)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d };
      };
      case "ggg_budget_draft" {
        let ?args : ?T.BudgetDraftArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        switch (fundOwner(args.fund)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d };
      };
      case "ggg_budget_propose" {
        let ?args : ?T.BudgetProposeArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        switch (args.fund) {
          case (?f) { switch (fundOwner(f)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d } };
          case null ROOT_ID;
        };
      };
      case "ggg_proposal_stop" {
        let ?target : ?Text = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        switch (findProposal(target)) { case null return #Err(#NotFound); case (?(_, p)) ownerId(p) };
      };
      case "ggg_department_edit" {
        let ?edit : ?T.DepartmentEditArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        let ?department = findDepartment(edit.department) else return #Err(#NotFound);
        switch (edit.parent) {
          case (?parent) {
            let ?_ = findDepartment(parent) else return #Err(#NotFound);
            if (parent != parentOf(department)) lowestAbove(parentOf(department), parent) else department.id;
          };
          case null department.id;
        };
      };
      case "ggg_department_delete" {
        let ?id : ?Text = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        let ?department = findDepartment(id) else return #Err(#NotFound);
        if (department.is_root) return #Err(#InvalidArgument("the root department is never deleted"));
        parentOf(department);
      };
      case _ ROOT_ID;
    };
    switch (findDepartment(id)) { case null #Err(#NotFound); case (?found) #Ok(found) };
  };

  /// A governed call: applied at once under the governing department's direct policy, replying Done
  /// with the id of the record it created, or filed as a proposal of that department that replays it
  /// (model §1).
  func govern(caller : Principal, op : Text, governing : T.Department, arg : Blob, title : Text, description : Text, apply : () -> Result<?Text>) : Result<T.Governed> {
    if (direct(governing.policy)) {
      switch (apply()) { case (#Err(e)) #Err(e); case (#Ok(id)) #Ok(#Done(id)) };
    } else {
      let call = #Call({ method = "ggg_" # op; arg });
      let scope = if (governing.is_root) null else ?governing.id; // the root's proposals are realm-wide
      let filed = fileProposal(caller, title, description, scope, null, null, call, scopeRule(governing), null, []);
      audit(op, caller, #Map([("filed", #Text(filed.id))]), #Text(filed.id));
      #Ok(#Proposed(filed.id));
    };
  };

  /// A department's proposal carries only the calls that department or one below it governs; a
  /// realm-wide one (scope null) carries any (I-GOV-13). Checked at creation and again at execution.
  func checkScope(scope : ?Text, method : Text, arg : Blob) : ?T.GggError {
    let ?department = scope else return null;
    switch (governingDepartment(method, arg)) {
      case (#Err(e)) ?e;
      case (#Ok(governing)) { if (within(governing.id, department)) null else ?#Forbidden({ permission = null; message = OUT_OF_SCOPE }) };
    };
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

  /// The links of other proposals to this one, oldest first.
  func linksTo(id : Text) : [T.ProposalLink] {
    let found = Iter.filterMap<T.Proposal, T.ProposalLink>(
      Map.values(proposals),
      func(q) {
        for (link in q.links.vals()) {
          if (link.proposal == id) return ?{ kind = link.kind; proposal = q.id };
        };
        null;
      },
    );
    Iter.toArray(found);
  };

  /// The proposal that replaces this one, if any.
  func replacedBy(id : Text) : ?Text {
    for (link in linksTo(id).vals()) {
      if (link.kind == #Replaces) return ?link.proposal;
    };
    null;
  };

  /// The rule a proposer states, checked against the scope's: a higher threshold or quorum, or the
  /// eligible basis where the scope counts the votes cast, is allowed; weaker is refused (I-GOV-3). The
  /// casting vote is the scope's.
  func statedRule(args : T.ProposalCreateArgs) : Result<Rule> {
    let scope = switch (args.department) {
      case (?d) { switch (findDepartment(d)) { case (?found) scopeRule(found); case null return #Err(#NotFound) } };
      case null defaultRule();
    };
    let threshold = switch (args.threshold) { case (?t) t; case null scope.threshold };
    let quorum = switch (args.quorum) { case (?q) q; case null scope.quorum };
    let threshold_of = switch (args.threshold_of) { case (?b) b; case null scope.threshold_of };
    let weakerBasis = threshold_of == #Cast and scope.threshold_of == #Eligible;
    if (threshold < scope.threshold or quorum < scope.quorum or weakerBasis) {
      return #Err(#InvalidArgument("the rule is weaker than the scope's: a proposer may only tighten it"));
    };
    if (threshold > WHOLE or quorum > WHOLE) return #Err(#InvalidArgument("a ratio is at most 100 000 000 (100 %)"));
    #Ok({ threshold; quorum; threshold_of; casting_vote = scope.casting_vote });
  };

  /// The member a proposal was filed for: the grantor when it was filed on their behalf.
  func filedFor(p : T.Proposal) : Principal {
    switch (p.on_behalf_of) { case (?grantor) grantor; case null p.proposer };
  };

  /// Refuses links that break I-GOV-10. `filer` is the member the new proposal is filed for.
  func checkLinks(filer : Principal, links : [T.ProposalLink]) : ?T.GggError {
    if (links.size() > MAX_LINKS) return ?#InvalidArgument("a proposal has at most 16 links");
    let named = Map.empty<Text, ()>();
    for (link in links.vals()) {
      if (Map.containsKey(named, Text.compare, link.proposal)) {
        return ?#InvalidArgument("the links name proposal " # link.proposal # " twice");
      };
      Map.add(named, Text.compare, link.proposal, ());
      let (_, target) = switch (findProposal(link.proposal)) { case null return ?#NotFound; case (?found) found };
      if (link.kind == #Replaces) {
        if (filedFor(target) != filer) {
          return ?#Forbidden({ permission = ?"proposal.create"; message = "Only the member it was filed for may replace a withdrawn proposal." });
        };
        if (target.status != #Withdrawn) return ?#Conflict("a replaced proposal must be withdrawn first");
        if (replacedBy(target.id) != null) return ?#Conflict("proposal " # target.id # " is already replaced");
      };
    };
    null;
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

  public query ({ caller }) func ggg_attribute_list(args : T.AttributeListArgs) : async Result<T.AttributePage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
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
        "governance.update",
        "org.set_policy",
        "org.manage_budget",
        "transfer.create",
        "codex.install",
        "codex.revert",
        "realm.data_view",
        "realm.monitor",
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
      language = if (args.language != null) args.language else entry.user.language;
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
  public shared ({ caller }) func ggg_attribute_submit(_ : T.AttributeSubmitArgs) : async Result<T.Attribute> {
    nobody(caller, "attribute.submit");
  };
  public shared ({ caller }) func ggg_attribute_review(_ : T.AttributeReviewArgs) : async Result<T.Attribute> {
    nobody(caller, "attribute.review");
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
    let department = switch (findDepartment(args.id)) { case null return #Ok(null); case (?found) found };
    switch (none<T.Seat>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ department; seats = items; next });
    };
  };

  public query func ggg_department_list(args : T.ListArgs) : async Result<T.DepartmentPage> {
    page(Map.values(departments), args.cursor, args.limit);
  };

  public query func ggg_department_chart(args : T.ChartArgs) : async Result<T.Chart> {
    let id = switch (args.department) { case (?d) d; case null ROOT_ID };
    let department = switch (findDepartment(id)) { case null return #Err(#NotFound); case (?found) found };
    let below = Iter.filter<T.Department>(Map.values(departments), func(d) { d.parent == ?department.id });
    switch (page(below, args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ department; positions = 0; seats = 0; filled = 0; children = items; next });
    };
  };

  /// Edits a department: its description, kind, head and parent. Governed by that department, or by
  /// the lowest department that is, or is above, both the old and the new parent when the edit moves
  /// it (model §1).
  public shared ({ caller }) func ggg_department_edit(args : T.DepartmentEditArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.set_policy")) { case (?e) return #Err(e); case null {} };
    let department = switch (findDepartment(args.department)) { case null return #Err(#NotFound); case (?found) found };
    switch (checkEdit(department, args)) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_department_edit", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "department_edit", governing, arg, "Edit department " # department.id, "Edits the department " # department.id # ".", func() {
      switch (editDepartment(caller, args)) { case (#Err(e)) #Err(e); case (#Ok(_)) #Ok(null) };
    });
  };

  /// Deletes a department with none below it. Governed by its parent (model §1).
  public shared ({ caller }) func ggg_department_delete(id : Text) : async Result<T.Governed> {
    switch (requireMember(caller, "org.set_policy")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (id);
    let governing = switch (governingDepartment("ggg_department_delete", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (checkDelete(id)) { case (?e) return #Err(e); case null {} };
    govern(caller, "department_delete", governing, arg, "Delete department " # id, "Deletes the department " # id # ".", func() {
      deleteDepartment(caller, id);
    });
  };

  /// The root stays (I-ORG-6), a department that owns a fund stays (model §3), and this fixture deletes
  /// no department with departments below it.
  func checkDelete(id : Text) : ?T.GggError {
    let ?department = findDepartment(id) else return ?#NotFound;
    if (department.is_root) return ?#InvalidArgument("the root department is never deleted");
    for (f in Map.values(funds)) {
      if (f.department == ?id) return ?#Conflict("a department that owns a fund is not deleted");
    };
    for (d in Map.values(departments)) {
      if (d.parent == ?id) return ?#Conflict("a department with departments below it is not deleted here");
    };
    null;
  };

  /// Deletes, checked against the departments as they stand now.
  func deleteDepartment(caller : Principal, id : Text) : Result<?Text> {
    switch (checkDelete(id)) { case (?e) return #Err(e); case null {} };
    Map.remove(departments, Text.compare, id);
    audit("department_delete", caller, #Map([("department", #Text(id))]), #Text(id));
    #Ok(null);
  };

  // ---- Funds and budgets (model §5)

  /// A fund's owner is the department named, the root when none is. Governed by that owner (model §1).
  public shared ({ caller }) func ggg_fund_create(args : T.FundCreateArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_fund_create", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (checkFund(args)) { case (?e) return #Err(e); case null {} };
    govern(caller, "fund_create", governing, arg, "Create fund " # args.fund, "Creates the fund " # args.fund # ".", func() {
      createFund(caller, args);
    });
  };

  func checkFund(args : T.FundCreateArgs) : ?T.GggError {
    if (Text.size(args.fund) == 0) return ?#InvalidArgument("fund is empty");
    if (Map.containsKey(funds, Text.compare, args.fund)) return ?#Conflict("fund " # args.fund # " exists");
    null;
  };

  func createFund(caller : Principal, args : T.FundCreateArgs) : Result<?Text> {
    switch (checkFund(args)) { case (?e) return #Err(e); case null {} };
    let fund : T.Fund = {
      id = args.fund;
      name = switch (args.name) { case (?n) n; case null args.fund };
      kind = switch (args.kind) { case (?k) k; case null "general" };
      department = args.department;
      balances = [];
      allocation_rule = null;
    };
    Map.add(funds, Text.compare, fund.id, fund);
    audit("fund_create", caller, #Map([("fund", #Text(fund.id))]), #Text(fund.id));
    #Ok(?fund.id);
  };

  /// Drafts one line of a fund's budget for a period. Governed by the fund's owner (model §1).
  public shared ({ caller }) func ggg_budget_draft(args : T.BudgetDraftArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_budget_draft", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    if (Text.size(args.period) == 0 or Text.size(args.category) == 0) return #Err(#InvalidArgument("period and category are not empty"));
    switch (checkDraft(args)) { case (?e) return #Err(e); case null {} };
    govern(caller, "budget_draft", governing, arg, "Draft a budget line", "Drafts a line of " # args.fund # "'s budget for " # args.period # ".", func() {
      draftBudget(caller, args);
    });
  };

  /// Within a fund and period a category is either revenue or expense (model §5).
  func checkDraft(args : T.BudgetDraftArgs) : ?T.GggError {
    for (b in Map.values(budgets)) {
      if (b.fund == args.fund and b.period == args.period and b.category == args.category and b.kind != args.kind) {
        return ?#InvalidArgument("category " # args.category # " of " # args.fund # " in " # args.period # " is of the other kind");
      };
    };
    null;
  };

  func draftBudget(caller : Principal, args : T.BudgetDraftArgs) : Result<?Text> {
    if (not Map.containsKey(funds, Text.compare, args.fund)) return #Err(#NotFound);
    switch (checkDraft(args)) { case (?e) return #Err(e); case null {} };
    let n = nextBudget;
    nextBudget += 1;
    let line : T.Budget = {
      id = "B-" # Nat.toText(n);
      fund = args.fund;
      period = args.period;
      category = args.category;
      kind = args.kind;
      planned = args.planned;
      actual = 0;
      status = #Draft;
      proposal = null;
    };
    Map.add(budgets, Nat.compare, n, line);
    audit("budget_draft", caller, #Map([("budget", #Text(line.id))]), #Text(line.id));
    #Ok(?line.id);
  };

  /// The draft lines of a period: a fund's, or every fund's.
  func drafts(args : T.BudgetProposeArgs) : [(Nat, T.Budget)] {
    Iter.toArray(Iter.filter<(Nat, T.Budget)>(Map.entries(budgets), func((_, b)) {
      b.status == #Draft and b.period == args.period and (switch (args.fund) { case (?f) b.fund == f; case null true });
    }));
  };

  /// Proposes the draft lines of a period together. Governed by the owner of `fund`, or by the root for
  /// every fund's lines (model §5, D19).
  public shared ({ caller }) func ggg_budget_propose(args : T.BudgetProposeArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_budget_propose", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    let lines = switch (linesToFile("ggg_budget_propose", arg)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l };
    let reply = govern(caller, "budget_propose", governing, arg, "Budget " # args.period, "Proposes the draft budget lines of " # args.period # ".", func() {
      adoptBudget(caller, args, null);
    });
    switch (reply) { case (#Ok(#Proposed(id))) markProposed(lines, id); case _ {} };
    reply;
  };

  /// The draft lines a call carries into a proposal: for budget_propose, the lines it names, which the
  /// filing marks proposed (model §5), with none left a Conflict; any other call carries none.
  func linesToFile(method : Text, arg : Blob) : Result<[(Nat, T.Budget)]> {
    if (method != "ggg_budget_propose") return #Ok([]);
    let ?args : ?T.BudgetProposeArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
    let lines = drafts(args);
    if (lines.size() == 0) return #Err(#Conflict("no draft line of " # args.period # " to propose"));
    #Ok(lines);
  };

  /// The lines are fixed at the filing: proposed, with the proposal, so a later budget_propose takes only
  /// the draft lines left, and the execution adopts exactly these (model §5).
  func markProposed(lines : [(Nat, T.Budget)], proposal : Text) {
    for ((n, b) in lines.vals()) Map.add(budgets, Nat.compare, n, { b with status = #Proposed; proposal = ?proposal });
  };

  /// A proposal that ends without adopting its lines returns them to draft, with no proposal, so the
  /// fund's budget can be proposed again (model §5).
  func settled(p : T.Proposal) {
    switch (p.status) {
      case (#Rejected or #Expired or #Withdrawn or #Failed) {
        for ((n, b) in Iter.toArray(Map.entries(budgets)).vals()) {
          if (b.status == #Proposed and b.proposal == ?p.id) Map.add(budgets, Nat.compare, n, { b with status = #Draft; proposal = null });
        };
      };
      case _ {};
    };
  };

  /// Adopts the lines of `proposal`, or, applied at once, the draft lines the call names.
  func adoptBudget(caller : Principal, args : T.BudgetProposeArgs, proposal : ?Text) : Result<?Text> {
    let lines = switch (proposal) {
      case (?id) Iter.toArray(Iter.filter<(Nat, T.Budget)>(Map.entries(budgets), func((_, b)) { b.status == #Proposed and b.proposal == ?id }));
      case null drafts(args);
    };
    if (lines.size() == 0) return #Err(#Conflict("no line of " # args.period # " to adopt"));
    for ((n, b) in lines.vals()) Map.add(budgets, Nat.compare, n, { b with status = #Adopted });
    // The fund's extended lines are replaced: amended, so a dropped category does not come back (D24).
    for ((_, adopted) in lines.vals()) {
      for ((n, b) in Iter.toArray(Map.entries(budgets)).vals()) {
        if (b.status == #Extended and b.fund == adopted.fund and b.period == adopted.period) {
          Map.add(budgets, Nat.compare, n, { b with status = #Amended });
        };
      };
    };
    audit("budget_propose", caller, #Map([("period", #Text(args.period)), ("lines", #Nat(lines.size()))]), #Text("ok"));
    #Ok(null);
  };

  // ---- Periods, extension and spending (model §5, D24)

  func currentPeriod() : ?Text = if (periods.size() == 0) null else ?periods[periods.size() - 1];

  func periodOpened(period : Text) : Bool = Array.any<Text>(periods, func(p) { p == period });

  /// Governed by the root. This fixture keeps a period's name and order, nothing else.
  public shared ({ caller }) func ggg_period_open(args : T.PeriodOpenArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    let ?root = findDepartment(ROOT_ID) else return #Err(#Unavailable("the realm has no root department"));
    if (Text.size(args.period) == 0) return #Err(#InvalidArgument("period is empty"));
    if (periodOpened(args.period)) return #Err(#Conflict("period " # args.period # " is open already"));
    govern(caller, "period_open", root, to_candid (args), "Open period " # args.period, "Opens the period " # args.period # ".", func() {
      if (periodOpened(args.period)) return #Err(#Conflict("period " # args.period # " is open already"));
      periods := Array.concat(periods, [args.period]);
      audit("period_open", caller, #Map([("period", #Text(args.period))]), #Text(args.period));
      #Ok(?args.period);
    });
  };

  /// The lines of `fund` in `period` with any of `statuses`.
  func linesOf(fund : Text, period : Text, statuses : [T.BudgetStatus]) : [(Nat, T.Budget)] {
    Iter.toArray(Iter.filter<(Nat, T.Budget)>(Map.entries(budgets), func((_, b)) {
      b.fund == fund and b.period == period and Array.any<T.BudgetStatus>(statuses, func(s) { s == b.status });
    }));
  };

  /// Copies the previous period's adopted lines into `period` as extended, fund by fund, for the funds
  /// with no extended, proposed or adopted line in it yet (model §5). Replies how many lines it copied.
  public shared ({ caller }) func ggg_budget_extend(period : Text) : async Result<Nat> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    if (not periodOpened(period)) return #Err(#NotFound);
    // The period opened just before this one.
    var previous : ?Text = null;
    label find for (p in periods.vals()) {
      if (p == period) break find;
      previous := ?p;
    };
    let ?earlier = previous else return #Err(#Conflict("no period before " # period));
    var copied = 0;
    for (f in Iter.toArray(Map.values(funds)).vals()) {
      if (linesOf(f.id, period, [#Extended, #Proposed, #Adopted]).size() == 0) {
        for ((_, b) in linesOf(f.id, earlier, [#Adopted]).vals()) {
          let n = nextBudget;
          nextBudget += 1;
          Map.add(budgets, Nat.compare, n, { b with id = "B-" # Nat.toText(n); period; status = #Extended; proposal = null });
          copied += 1;
        };
      };
    };
    if (copied == 0) return #Err(#Conflict("no fund is left to extend into " # period));
    audit("budget_extend", caller, #Map([("period", #Text(period)), ("lines", #Nat(copied))]), #Text("ok"));
    #Ok(copied);
  };

  /// An adopted budget is exhaustive for its fund: in the current period, a transfer from a fund with an
  /// adopted budget names a category with an adopted line (model §5, D24).
  func checkSpending(args : T.TransferCreateArgs) : ?T.GggError {
    let ?period = currentPeriod() else return null;
    if (linesOf(args.fund, period, [#Adopted]).size() == 0) return null;
    let named = switch (args.category) { case (?c) c; case null "" };
    let budgeted = Array.any<(Nat, T.Budget)>(linesOf(args.fund, period, [#Adopted]), func((_, b)) { b.category == named });
    if (budgeted) null else ?#Conflict("the adopted budget of " # args.fund # " for " # period # " has no line for that category");
  };

  /// Governed by the fund's owner (I-FIN-2). This fixture moves no money: it checks the budget and
  /// records the transfer in the audit log.
  public shared ({ caller }) func ggg_transfer_create(args : T.TransferCreateArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "transfer.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("transfer.create"));
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_transfer_create", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (checkSpending(args)) { case (?e) return #Err(e); case null {} };
    govern(caller, "transfer_create", governing, arg, "Transfer from " # args.fund, "Transfers from the fund " # args.fund # ".", func() {
      spend(caller, args);
    });
  };

  func spend(caller : Principal, args : T.TransferCreateArgs) : Result<?Text> {
    switch (checkSpending(args)) { case (?e) return #Err(e); case null {} };
    audit("transfer_create", caller, #Map([("fund", #Text(args.fund)), ("amount", #Nat(args.amount))]), #Text("ok"));
    #Ok(null);
  };

  /// The root keeps no parent, and a department never moves under itself or a department below it.
  func checkEdit(department : T.Department, args : T.DepartmentEditArgs) : ?T.GggError {
    switch (args.parent) {
      case null {};
      case (?parent) {
        if (department.is_root) return ?#InvalidArgument("the root has no parent");
        switch (findDepartment(parent)) { case null return ?#NotFound; case (?_) {} };
        if (within(parent, department.id)) return ?#InvalidArgument("a department cannot move under itself or a department below it");
      };
    };
    switch (args.head) {
      case (?#Set(head)) { if (not isActiveMember(head)) return ?#InvalidArgument("the head names a principal who is not an active member") };
      case _ {};
    };
    null;
  };

  /// Applies an edit, checked against the departments as they stand now.
  func editDepartment(caller : Principal, args : T.DepartmentEditArgs) : Result<T.Department> {
    let department = switch (findDepartment(args.department)) { case null return #Err(#NotFound); case (?found) found };
    switch (checkEdit(department, args)) { case (?e) return #Err(e); case null {} };
    let edited = {
      department with
      description = switch (args.description) { case (?d) d; case null department.description };
      kind = switch (args.kind) { case (?k) ?k; case null department.kind };
      head = switch (args.head) { case (?#Set(h)) ?h; case (?#Clear) null; case null department.head };
      parent = switch (args.parent) { case (?p) ?p; case null department.parent };
    };
    Map.add(departments, Text.compare, edited.id, edited);
    audit("department_edit", caller, #Map([("department", #Text(edited.id))]), #Text(edited.id));
    #Ok(edited);
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
      case (#Ok({ items; next })) #Ok(?{ proposal = p; votes = items; next; replaced_by = replacedBy(p.id) });
    };
  };

  public query func ggg_proposal_linked_from(args : T.GetArgs) : async Result<?T.ProposalLinkPage> {
    let (_, p) = switch (findProposal(args.id)) { case null return #Ok(null); case (?found) found };
    switch (page(linksTo(p.id).vals(), args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok(links)) #Ok(?links);
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
      case (?d) { switch (findDepartment(d)) { case null return #Err(#NotFound); case (?_) {} } };
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
        switch (checkScope(scopeOf(args.department), method, arg)) { case (?e) return #Err(e); case null {} };
      };
    };
    let lines = switch (args.action) {
      case (#Call { method; arg }) { switch (linesToFile(method, arg)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l } };
      case _ [];
    };
    let links = switch (args.links) { case (?l) l; case null [] };
    switch (checkLinks(caller, links)) { case (?e) return #Err(e); case null {} };
    switch (args.effective_at) {
      case (?e) { if (e <= now()) return #Err(#InvalidArgument("effective_at must lie in the future")) };
      case null {};
    };
    let rule = switch (statedRule(args)) { case (#Err(e)) return #Err(e); case (#Ok(r)) r };
    let p = fileProposal(caller, args.title, args.description, args.department, args.kind, args.matter, args.action, rule, args.effective_at, links);
    markProposed(lines, p.id);
    audit("proposal_create", caller, #Map([("title", #Text(p.title))]), #Text(p.id));
    #Ok(p.id);
  };

  /// A proposal's scope as stored: the department's id, or null for a realm-wide one (the root's).
  func scopeOf(department : ?Text) : ?Text {
    switch (department) { case (?d) { if (d == ROOT_ID) null else ?d }; case null null };
  };

  /// The policy's n of a department's proposal, what its threshold is measured against; none realm-wide.
  func policySeats(scope : ?Text) : ?Nat {
    let ?d = scope else return null;
    switch (findDepartment(d)) { case (?found) ?found.policy.n; case null null };
  };

  /// Files a proposal, open for voting at once. `department` is its scope; the root's is realm-wide.
  func fileProposal(
    proposer : Principal,
    title : Text,
    description : Text,
    department : ?Text,
    kind : ?Text,
    matter : ?Text,
    action : T.ProposalAction,
    rule : Rule,
    effective_at : ?T.Timestamp,
    links : [T.ProposalLink],
  ) : T.Proposal {
    let t = now();
    let n = nextProposal;
    nextProposal += 1;
    let p : T.Proposal = {
      id = Nat.toText(n);
      title;
      description;
      proposer;
      on_behalf_of = null;
      department = scopeOf(department);
      kind;
      matter;
      action;
      status = #Voting;
      opens_at = ?t;
      deadline = ?(t + votingWindow);
      effective_at;
      threshold = rule.threshold;
      quorum = rule.quorum;
      threshold_of = rule.threshold_of;
      casting_vote = rule.casting_vote;
      tally = { yes = 0; no = 0; abstain = 0; eligible = ?Map.size(members); seats = policySeats(scopeOf(department)) };
      result = null;
      links;
    };
    Map.add(proposals, Nat.compare, n, p);
    p;
  };

  public shared ({ caller }) func ggg_proposal_vote(args : T.ProposalVoteArgs) : async Result<T.Vote> {
    switch (requireMember(caller, "proposal.vote")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.vote"));
    let (n, p) = switch (findProposal(args.proposal)) { case null return #Err(#NotFound); case (?found) found };
    let t = now();
    let beforeDeadline = switch (p.deadline) { case (?d) t <= d; case null true };
    let open = p.status == #Voting and beforeDeadline and not Map.containsKey(everyoneVotedAt, Nat.compare, n);
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
    switch (tally.eligible) {
      case (?eligible) { if (tally.yes + tally.no + tally.abstain >= eligible) Map.add(everyoneVotedAt, Nat.compare, n, t) };
      case null {};
    };
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
    settled(withdrawn);
    audit("proposal_withdraw", caller, #Map([("proposal", #Text(p.id))]), #Text(p.id));
    #Ok(withdrawn);
  };

  /// Proposals here are filed already open, so there is never a draft to open.
  public shared ({ caller }) func ggg_proposal_open(id : Text) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.manage")) { case (?e) return #Err(e); case null {} };
    switch (findProposal(id)) {
      case null #Err(#NotFound);
      case (?_) #Err(#Conflict("only a draft can be opened"));
    };
  };

  /// Whether the yes votes reach a department proposal's threshold of its policy's seats, or exceed a
  /// realm-wide proposal's threshold of its basis (I-GOV-3). A tie over the votes cast is decided by the
  /// casting vote's yes.
  func thresholdMet(n : Nat, p : T.Proposal) : Bool {
    let { yes; no; eligible; seats } = p.tally;
    switch (seats) { case (?policySeats) return yes * WHOLE >= p.threshold * policySeats; case null {} };
    let basis = switch (p.threshold_of) {
      case (#Cast) yes + no;
      case (#Eligible) { switch (eligible) { case (?e) e; case null yes + no } };
    };
    if (yes * WHOLE > p.threshold * basis) return true;
    switch (p.threshold_of, p.casting_vote) {
      case (#Cast, ?caster) {
        if (yes * WHOLE != p.threshold * basis) return false;
        switch (Map.get(ballots(n), Principal.compare, caster)) {
          case (?v) v.choice == #Yes;
          case null false;
        };
      };
      case _ false;
    };
  };

  /// How a vote that ended at `ended` and is finalized at `t` turns out. A vote that ended after
  /// `effective_at` expires the proposal, whatever was decided. Otherwise quorum and threshold decide,
  /// and an accepted proposal with an action whose `effective_at` is still ahead is scheduled. A
  /// motion has nothing to execute, so it stays accepted; so does an action whose `effective_at` has
  /// passed by the time the vote is finalized, which then executes at once.
  func outcome(n : Nat, p : T.Proposal, ended : T.Timestamp, t : T.Timestamp) : T.ProposalStatus {
    switch (p.effective_at) {
      case (?e) { if (ended > e) return #Expired };
      case null {};
    };
    let { yes; no; abstain; eligible } = p.tally;
    let quorumMet = switch (eligible) { case (?m) (yes + no + abstain) * WHOLE >= p.quorum * m; case null true };
    if (not (quorumMet and thresholdMet(n, p))) return #Rejected;
    switch (p.action, p.effective_at) {
      case (#Motion, _) #Accepted;
      case (_, ?e) { if (e > t) #ExecutionScheduled else #Accepted };
      case (_, null) #Accepted;
    };
  };

  public shared ({ caller }) func ggg_proposal_finalize(id : Text) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.manage")) { case (?e) return #Err(e); case null {} };
    let (n, p) = switch (findProposal(id)) { case null return #Err(#NotFound); case (?found) found };
    if (p.status != #Voting) return #Err(#Conflict("only a proposal being voted on can be finalized"));
    let t = now();
    // A vote ends at its deadline, or earlier at the moment every eligible member has voted. When
    // proposal_finalize runs does not change when it ended; it only records the outcome.
    let ended = switch (Map.get(everyoneVotedAt, Nat.compare, n), p.deadline) {
      case (?voted, ?d) Nat64.min(voted, d);
      case (?voted, null) voted;
      case (null, ?d) { if (t <= d) return #Err(#Conflict("voting is still open")); d };
      case (null, null) t; // no deadline: it may be finalized at any time, and ends then
    };
    let finalized = { p with status = outcome(n, p, ended, t) };
    Map.add(proposals, Nat.compare, n, finalized);
    settled(finalized);
    audit("proposal_finalize", caller, #Map([("proposal", #Text(p.id))]), #Text(debug_show (finalized.status)));
    #Ok(finalized);
  };

  /// Ends a scheduled proposal as withdrawn. The caller holds `proposal.manage` or is a replayed proposal.
  func stopProposal(caller : Principal, id : Text) : Result<T.Proposal> {
    let (n, p) = switch (findProposal(id)) { case null return #Err(#NotFound); case (?found) found };
    if (p.status != #ExecutionScheduled) return #Err(#Conflict(NOT_SCHEDULED));
    if (Set.contains(executing, Nat.compare, n)) return #Err(#Conflict("its action is running"));
    let stopped = { p with status = #Withdrawn };
    Map.add(proposals, Nat.compare, n, stopped);
    settled(stopped);
    audit("proposal_stop", caller, #Map([("proposal", #Text(p.id))]), #Text(p.id));
    #Ok(stopped);
  };

  type Ran = (T.ProposalStatus, ?T.ProposalResult);

  /// Applies an accepted call as the realm, within the proposal's scope as the departments stand now
  /// (I-GOV-13). This fixture replays ggg_proposal_stop, ggg_department_edit, ggg_department_delete,
  /// ggg_fund_create, ggg_budget_draft, ggg_budget_propose and ggg_codex_install, which may await
  /// another realm.
  func replay(caller : Principal, p : T.Proposal, method : Text, arg : Blob) : async* Ran {
    func failed(e : T.GggError) : Ran = (#Failed, ?#Error(debug_show (e)));
    func undecodable() : Ran = (#Failed, ?#Error("arg does not decode"));
    switch (checkScope(p.department, method, arg)) { case (?e) return failed(e); case null {} };
    let applied : Result<?Text> = switch (method) {
      case "ggg_proposal_stop" {
        let ?id : ?Text = from_candid (arg) else return undecodable();
        switch (stopProposal(caller, id)) { case (#Err(e)) #Err(e); case (#Ok(_)) #Ok(null) };
      };
      case "ggg_department_edit" {
        let ?edit : ?T.DepartmentEditArgs = from_candid (arg) else return undecodable();
        switch (editDepartment(caller, edit)) { case (#Err(e)) #Err(e); case (#Ok(_)) #Ok(null) };
      };
      case "ggg_department_delete" {
        let ?id : ?Text = from_candid (arg) else return undecodable();
        deleteDepartment(caller, id);
      };
      case "ggg_fund_create" {
        let ?args : ?T.FundCreateArgs = from_candid (arg) else return undecodable();
        createFund(caller, args);
      };
      case "ggg_budget_draft" {
        let ?args : ?T.BudgetDraftArgs = from_candid (arg) else return undecodable();
        draftBudget(caller, args);
      };
      case "ggg_budget_propose" {
        let ?args : ?T.BudgetProposeArgs = from_candid (arg) else return undecodable();
        adoptBudget(caller, args, ?p.id);
      };
      case "ggg_transfer_create" {
        let ?args : ?T.TransferCreateArgs = from_candid (arg) else return undecodable();
        spend(caller, args);
      };
      case "ggg_codex_install" {
        let ?source : ?T.CodexSource = from_candid (arg) else return undecodable();
        switch (source) {
          case (#Release { source = id; version }) { switch (await* installRelease(id, version)) { case (#Err(e)) #Err(e); case (#Ok(_)) #Ok(null) } };
          case (#Package { source = checksum }) installCodex(caller, checksum);
          case (#Registry _) #Err(#InvalidArgument(NOT_INSTALLABLE));
        };
      };
      case "ggg_codex_revert" {
        let ?args : ?(?T.CodexRevertArgs) = from_candid (arg) else return undecodable();
        switch (revertTarget(args)) { case (#Err(e)) #Err(e); case (#Ok(target)) revertCodex(caller, target) };
      };
      case _ return (#Failed, ?#Error(method # " is not replayed by this fixture"));
    };
    switch (applied) {
      case (#Err(e)) failed(e);
      case (#Ok(id)) {
        // What the call replies when it applies at once: Done, with the id of the record it created.
        let reply : Result<T.Governed> = #Ok(#Done(id));
        (#Executed, ?#Reply(to_candid (reply)));
      };
    };
  };

  public shared ({ caller }) func ggg_proposal_execute(id : Text) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.manage")) { case (?e) return #Err(e); case null {} };
    let (n, p) = switch (findProposal(id)) { case null return #Err(#NotFound); case (?found) found };
    if (p.status != #Accepted and p.status != #ExecutionScheduled) {
      return #Err(#Conflict("only an accepted proposal can be executed"));
    };
    switch (p.effective_at) {
      case (?e) { if (e > now()) return #Err(#Conflict("this proposal takes effect at " # Nat64.toText(e))) };
      case null {};
    };
    if (Set.contains(executing, Nat.compare, n)) return #Err(#Conflict("this proposal's action is running"));
    let (status, result) = switch (p.action) {
      case (#Motion) return #Err(#Conflict("a motion has nothing to execute"));
      case (#Code _) (#Failed, ?#Error("this fixture installs no codex"));
      case (#Call { method; arg }) {
        // The call may await another realm: a second execute meanwhile is a Conflict, and the status
        // stays as it was until the action ends, so it runs once (I-GOV-1).
        Set.add(executing, Nat.compare, n);
        let ran = await* replay(caller, p, method, arg);
        Set.remove(executing, Nat.compare, n);
        ran;
      };
    };
    let executed = { p with status; result };
    Map.add(proposals, Nat.compare, n, executed);
    settled(executed);
    audit("proposal_execute", caller, #Map([("proposal", #Text(p.id))]), #Text(debug_show (status)));
    #Ok(executed);
  };

  /// Governed by the department that owns the proposal, the root for a realm-wide one. A direct
  /// policy (one member decides) applies the stop at once; any other files a proposal that stops it.
  public shared ({ caller }) func ggg_proposal_stop(id : Text) : async Result<T.Governed> {
    switch (requireMember(caller, "proposal.manage")) { case (?e) return #Err(e); case null {} };
    let (_, target) = switch (findProposal(id)) { case null return #Err(#NotFound); case (?found) found };
    if (target.status != #ExecutionScheduled) return #Err(#Conflict(NOT_SCHEDULED));
    let owner = switch (findDepartment(ownerId(target))) { case null return #Err(#NotFound); case (?found) found };
    govern(caller, "proposal_stop", owner, to_candid (id), "Stop proposal " # id, "Stops the scheduled proposal " # id # ".", func() {
      switch (stopProposal(caller, id)) { case (#Err(e)) #Err(e); case (#Ok(_)) #Ok(null) };
    });
  };

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
  /// Governed by the root, whose direct policy applies it at once. The casting vote is an active member.
  public shared ({ caller }) func ggg_governance_update(args : T.GovernanceUpdateArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "governance.update")) { case (?e) return #Err(e); case null {} };
    for (ratio in [args.voting_threshold, args.voting_quorum].vals()) {
      switch (ratio) { case (?r) { if (r > WHOLE) return #Err(#InvalidArgument("a ratio is at most 100 000 000 (100 %)")) }; case null {} };
    };
    switch (args.casting_vote) {
      case (?#Set(member)) { if (not isActiveMember(member)) return #Err(#InvalidArgument("the casting vote names a principal who is not an active member")) };
      case _ {};
    };
    switch (args.voting_window) { case (?w) votingWindow := w; case null {} };
    switch (args.voting_threshold) { case (?t) votingThreshold := t; case null {} };
    switch (args.voting_quorum) { case (?q) votingQuorum := q; case null {} };
    switch (args.casting_vote) { case (?#Set(member)) castingVote := ?member; case (?#Clear) castingVote := null; case null {} };
    audit("governance_update", caller, #Map([]), #Text("ok"));
    #Ok(#Done(null));
  };

  // §5

  public query ({ caller }) func ggg_my_invoices(args : T.MyInvoicesArgs) : async Result<T.MyInvoicePage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  public query func ggg_treasury_view(args : T.ListArgs) : async Result<T.TreasuryView> {
    switch (page(Map.values(funds), args.cursor, args.limit)) {
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

  public query func ggg_loan_list(args : T.LoanListArgs) : async Result<T.LoanPage> {
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

  public query func ggg_procedure_list(args : T.ListArgs) : async Result<T.ProcedurePage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_request_get(args : T.RequestGetArgs) : async Result<?T.Request> {
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    #Ok(null);
  };

  public query func ggg_request_list(args : T.RequestListArgs) : async Result<T.RequestPage> {
    none(args.cursor, args.limit);
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

  // ---- Links between realms (I-NEST-1 to 3)

  func linkStatus(link : Link) : T.LinkStatus {
    switch (link.ended) {
      case (?e) #Ended(e);
      case null { if (link.mine and link.theirs) #Active else #Requested };
    };
  };

  func open(link : Link) : Bool = link.ended == null;

  /// A realm and a stand-in record never share a key, whatever the record's url says.
  func sourceKey(ref : T.SyncSourceRef) : Text {
    switch (ref) { case (#Realm(p)) "realm:" # Principal.toText(p); case (#Record { url }) "record:" # url };
  };

  func sourceView(s : Source) : T.SyncSource = { source = s.source; name = s.name; status = linkStatus(s.link) };

  func followerView(f : FollowerEntry) : T.Follower = {
    id = Principal.toText(f.capital);
    capital = f.capital;
    status = linkStatus(f.link);
    layers = f.layers;
    compliance = f.compliance;
    population = f.population;
    reported_at = f.reported_at;
  };

  func statusValue(status : T.LinkStatus) : T.Value {
    switch (status) {
      case (#Requested) #Text("Requested");
      case (#Active) #Text("Active");
      case (#Ended { by; at }) #Map([("Ended", #Map([("by", #Text(Principal.toText(by))), ("at", #Nat(Nat64.toNat(at)))]))]);
    };
  };

  func sideText(side : T.LinkSide) : Text = switch (side) { case (#SyncSource) "SyncSource"; case (#Follower) "Follower" };

  func me() : Principal = Principal.fromActor(this);

  /// What this realm calls on another realm's capital. Every call is bounded-wait: one that times out
  /// counts as unanswered (I-NEST-3).
  type Peer = actor {
    ggg_link_notify : shared T.LinkNotifyArgs -> async Result<T.LinkStatus>;
    ggg_realm_info : shared query () -> async T.Realm;
    ggg_legislation_releases : shared query T.ListArgs -> async Result<T.ReleasePage>;
  };
  func peer(capital : Principal) : Peer = actor (Principal.toText(capital));
  let CALL_TIMEOUT : Nat32 = 30; // seconds
  let CLOCK_TOLERANCE : T.Timestamp = 5 * 60 * 1_000_000_000; // subnets' clocks differ a little

  /// The other side's vote is in (it answered Active): the link is active once this side's is too.
  func theirVoteIsIn(capital : Principal, side : T.LinkSide) {
    switch (side) {
      // This realm is their follower: they are its sync source.
      case (#Follower) {
        let key = sourceKey(#Realm(capital));
        switch (Map.get(sources, Text.compare, key)) {
          case (?s) Map.add(sources, Text.compare, key, { s with link = { s.link with theirs = true } });
          case null {};
        };
      };
      case (#SyncSource) {
        switch (Map.get(followers, Principal.compare, capital)) {
          case (?f) Map.add(followers, Principal.compare, capital, { f with link = { f.link with theirs = true } });
          case null {};
        };
      };
    };
  };

  func noticeKey(capital : Principal, side : T.LinkSide) : Text = Principal.toText(capital) # "/" # sideText(side);

  /// Tells the capital at the other side what this side's vote made of the link, and reads the answer:
  /// Active completes the link here. A GggError is an answer; a call that fails or times out is not, and
  /// the notice is kept to be sent again (I-NEST-3).
  func notify(capital : Principal, side : T.LinkSide, status : T.LinkStatus) : async* () {
    let key = noticeKey(capital, side);
    let notice = { capital; side; status };
    Map.add(pending, Text.compare, key, notice);
    let answer = try { ?(await (with timeout = CALL_TIMEOUT) peer(capital).ggg_link_notify({ side; status })) } catch (_) { null };
    switch (answer) {
      case null {};
      case (?reply) {
        // A newer notice may have taken the slot meanwhile: only this one is done.
        if (Map.get(pending, Text.compare, key) == ?notice) Map.remove(pending, Text.compare, key);
        switch (reply) { case (#Ok(#Active)) theirVoteIsIn(capital, side); case _ {} };
      };
    };
  };

  /// Sends the notices that were not answered, again.
  func resendNotices() : async () {
    for (n in Iter.toArray(Map.values(pending)).vals()) await* notify(n.capital, n.side, n.status);
  };
  transient let _retry = Timer.recurringTimer<system>(#seconds 60, resendNotices);

  let WALK_LIMIT = 32; // realms read in one cycle check
  let PAGE_LIMIT = 32; // pages read of one record

  /// Whether `realm` takes legislation from `target`, directly or through other realms, over links not
  /// ended, as their realm_info says now (I-NEST-2). A realm that cannot be read, or a walk past
  /// WALK_LIMIT realms, fails the check with Unavailable: never an open link.
  func takesLegislationFrom(realm : Principal, target : Principal) : async* Result<Bool> {
    let todo = List.singleton<Principal>(realm);
    let seen = Set.empty<Principal>();
    while (not List.isEmpty(todo)) {
      let ?p = List.removeLast(todo) else return #Ok(false);
      if (p == target) return #Ok(true);
      if (not Set.contains(seen, Principal.compare, p)) {
        Set.add(seen, Principal.compare, p);
        if (Set.size(seen) > WALK_LIMIT) return #Err(#Unavailable("too many realms to check for a cycle"));
        let listed = if (p == me()) ?Iter.toArray(Iter.map<Source, T.SyncSource>(Map.values(sources), sourceView)) else {
          try { ?((await (with timeout = CALL_TIMEOUT) peer(p).ggg_realm_info()).sync_sources) } catch (_) { null };
        };
        let ?syncSources = listed else return #Err(#Unavailable("a realm could not be read to check for a cycle: " # Principal.toText(p)));
        for (s in syncSources.vals()) {
          switch (s.source, s.status) {
            case (#Realm _, #Ended _) {};
            case (#Realm(q), _) List.add(todo, q);
            case _ {};
          };
        };
      };
    };
    #Ok(false);
  };

  /// Governed by the root, whose direct policy applies it at once. The link is recorded as requested,
  /// then the walk refuses a source that takes legislation from this realm, at any remove, and undoes
  /// the record (I-NEST-2). A stand-in record's link is active on this vote alone, and a second add of
  /// the same URL pins a new checksum (I-NEST-1).
  public shared ({ caller }) func ggg_sync_source_add(args : T.SyncSourceAddArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "sync_source.manage")) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.name) == 0) return #Err(#InvalidArgument("name is empty"));
    let key = sourceKey(args.source);
    let previous = Map.get(sources, Text.compare, key);
    func undo() { switch (previous) { case (?s) Map.add(sources, Text.compare, key, s); case null Map.remove(sources, Text.compare, key) } };
    let link = switch (args.source) {
      case (#Record { url }) {
        if (not Text.startsWith(url, #text "https://")) return #Err(#InvalidArgument("a stand-in record's url is https"));
        ({ mine = true; theirs = true; ended = null });
      };
      case (#Realm(capital)) {
        if (capital == me()) return #Err(#Conflict("a realm does not take legislation from itself"));
        switch (previous) { case (?s) { if (open(s.link)) return #Err(#Conflict("already a sync source")) }; case null {} };
        ({ mine = true; theirs = false; ended = null });
      };
    };
    Map.add(sources, Text.compare, key, { source = args.source; name = args.name; link });
    switch (args.source) {
      case (#Record _) {};
      case (#Realm(capital)) {
        switch (await* takesLegislationFrom(capital, me())) {
          case (#Err(e)) { undo(); return #Err(e) };
          case (#Ok(true)) { undo(); return #Err(#Conflict("that realm takes legislation from this one: a cycle")) };
          case (#Ok(false)) {};
        };
      };
    };
    // The other side may have voted during the walk: the notice carries the link as it stands now.
    let status = switch (Map.get(sources, Text.compare, key)) { case (?s) linkStatus(s.link); case null linkStatus(link) };
    audit("sync_source_add", caller, #Map([("source", #Text(key))]), statusValue(status));
    switch (args.source) { case (#Realm(capital)) await* notify(capital, #Follower, status); case _ {} };
    #Ok(#Done(null));
  };

  public shared ({ caller }) func ggg_sync_source_remove(args : T.SyncSourceRemoveArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "sync_source.manage")) { case (?e) return #Err(e); case null {} };
    let key = sourceKey(args.source);
    let ?s = Map.get(sources, Text.compare, key) else return #Err(#NotFound);
    if (not open(s.link)) return #Err(#Conflict("this link has ended"));
    let ended = { by = me(); at = now() };
    Map.add(sources, Text.compare, key, { s with link = { s.link with ended = ?ended } });
    audit("sync_source_remove", caller, #Map([("source", #Text(key))]), statusValue(#Ended(ended)));
    switch (s.source) { case (#Realm(capital)) await* notify(capital, #Follower, #Ended(ended)); case _ {} };
    #Ok(#Done(null));
  };

  /// Governed by the root, whose direct policy applies it at once. The link is recorded as requested,
  /// then the walk refuses a follower this realm takes legislation from, at any remove, and undoes the
  /// record (I-NEST-2).
  public shared ({ caller }) func ggg_follower_accept(args : T.FollowerArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "follower.manage")) { case (?e) return #Err(e); case null {} };
    if (args.follower == me()) return #Err(#Conflict("a realm is not its own follower"));
    let previous = Map.get(followers, Principal.compare, args.follower);
    switch (previous) { case (?f) { if (open(f.link)) return #Err(#Conflict("already a follower")) }; case null {} };
    let link = { mine = true; theirs = false; ended = null };
    let entry = { capital = args.follower; link; layers = []; compliance = #Unknown; population = 0; reported_at = null };
    Map.add(followers, Principal.compare, args.follower, entry);
    func undo() { switch (previous) { case (?f) Map.add(followers, Principal.compare, args.follower, f); case null Map.remove(followers, Principal.compare, args.follower) } };
    switch (await* takesLegislationFrom(me(), args.follower)) {
      case (#Err(e)) { undo(); return #Err(e) };
      case (#Ok(true)) { undo(); return #Err(#Conflict("this realm takes legislation from that one: a cycle")) };
      case (#Ok(false)) {};
    };
    let status = switch (Map.get(followers, Principal.compare, args.follower)) { case (?f) linkStatus(f.link); case null linkStatus(link) };
    audit("follower_accept", caller, #Map([("follower", #Text(Principal.toText(args.follower)))]), statusValue(status));
    await* notify(args.follower, #SyncSource, status);
    #Ok(#Done(null));
  };

  public shared ({ caller }) func ggg_follower_remove(args : T.FollowerArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "follower.manage")) { case (?e) return #Err(e); case null {} };
    let ?f = Map.get(followers, Principal.compare, args.follower) else return #Err(#NotFound);
    if (not open(f.link)) return #Err(#Conflict("this link has ended"));
    let ended = { by = me(); at = now() };
    Map.add(followers, Principal.compare, args.follower, { f with link = { f.link with ended = ?ended } });
    audit("follower_remove", caller, #Map([("follower", #Text(Principal.toText(args.follower)))]), statusValue(#Ended(ended)));
    await* notify(args.follower, #SyncSource, #Ended(ended));
    #Ok(#Done(null));
  };

  /// The link after the other side's notice: their vote is in, or they ended it. A notice that a link
  /// ended names its sender as `by`, at a time not ahead of this realm's clock by more than a few
  /// minutes (I-NEST-3). A notice about a link that has ended is a Conflict, unless it says the same.
  func received(caller : Principal, link : Link, status : T.LinkStatus) : Result<Link> {
    switch (link.ended, status) {
      case (?_, #Ended _) #Ok(link);
      case (?_, _) #Err(#Conflict("this link has ended"));
      case (null, #Ended(e)) {
        if (e.by != caller) return #Err(#InvalidArgument("a notice that a link ended names its sender as by"));
        if (e.at > now() + CLOCK_TOLERANCE) return #Err(#InvalidArgument("a notice that a link ended is not dated ahead of this realm's clock"));
        #Ok({ link with ended = ?e });
      };
      case (null, _) #Ok({ link with theirs = true });
    };
  };

  /// Accepted from the capital at the other side of a link this realm has voted on (I-NEST-3); the
  /// reply is the link's status here, which the caller reads.
  public shared ({ caller }) func ggg_link_notify(args : T.LinkNotifyArgs) : async Result<T.LinkStatus> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    let noLink : T.GggError = #Forbidden({ permission = ?"link.sync"; message = "Only the capital at the other side of a link this realm has voted on may call this." });
    let link = switch (args.side) {
      case (#SyncSource) {
        let key = sourceKey(#Realm(caller));
        let ?s = Map.get(sources, Text.compare, key) else return #Err(noLink);
        let link = switch (received(caller, s.link, args.status)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l };
        Map.add(sources, Text.compare, key, { s with link });
        link;
      };
      case (#Follower) {
        let ?f = Map.get(followers, Principal.compare, caller) else return #Err(noLink);
        let link = switch (received(caller, f.link, args.status)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l };
        Map.add(followers, Principal.compare, caller, { f with link });
        link;
      };
    };
    let status = linkStatus(link);
    audit("link_notify", caller, #Map([("side", #Text(sideText(args.side))), ("status", statusValue(args.status))]), statusValue(status));
    #Ok(status);
  };

  /// From a follower's capital, over an active link (I-NEST-3): the follower's own claims, kept as the
  /// last report. This realm matches a layer by its checksum in its record; one it does not list
  /// matches nothing.
  public shared ({ caller }) func ggg_follower_report(args : T.FollowerReportArgs) : async Result<T.Follower> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    let ?f = Map.get(followers, Principal.compare, caller) else {
      return #Err(#Forbidden({ permission = ?"link.sync"; message = "Only the capital of a follower this realm has accepted reports." }));
    };
    if (linkStatus(f.link) != #Active) return #Err(#Conflict("the link is not active"));
    let reported = { f with layers = args.layers; compliance = args.compliance; population = args.population; reported_at = ?now() };
    Map.add(followers, Principal.compare, caller, reported);
    audit("follower_report", caller, #Map([("population", #Nat(args.population))]), #Text("ok"));
    #Ok(followerView(reported));
  };

  public query func ggg_follower_list(args : T.ListArgs) : async Result<T.FollowerPage> {
    page(Iter.map<FollowerEntry, T.Follower>(Map.values(followers), followerView), args.cursor, args.limit);
  };

  // ---- Releases: the published record (model §11)

  /// Whether this realm holds the bytes of `checksum`.
  func stored(checksum : Text) : Bool = Map.containsKey(chapters, Text.compare, checksum);

  func relays(source : Text) : Bool = Array.any<T.Release>(relayed, func(r) { r.source == source });

  /// Governed by the root, whose direct policy applies it at once. The source id is the realm's own, not
  /// a layer it relays and the one of its first release (InvalidArgument); a version is published once
  /// (Conflict); every checksum named is stored here (InvalidArgument); a release is never edited.
  public shared ({ caller }) func ggg_legislation_release_publish(args : T.LegislationReleasePublishArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "legislation.publish")) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.source) == 0 or Text.size(args.version) == 0) return #Err(#InvalidArgument("source and version are not empty"));
    if (relays(args.source)) return #Err(#InvalidArgument("the source id names a layer this realm relays"));
    if (published.size() > 0 and published[0].source != args.source) {
      return #Err(#InvalidArgument("this realm publishes as " # published[0].source));
    };
    for (r in published.vals()) { if (r.version == args.version) return #Err(#Conflict("version " # args.version # " is published already")) };
    for (c in args.chapters.vals()) {
      if (not stored(c.checksum)) return #Err(#InvalidArgument("chapter " # c.domain # " names a checksum this realm does not hold: " # c.checksum));
    };
    switch (args.calendar) {
      case (?c) { if (not stored(c)) return #Err(#InvalidArgument("the calendar names a checksum this realm does not hold: " # c)) };
      case null {};
    };
    let release : T.Release = {
      source = args.source;
      version = args.version;
      published = now();
      effective_from = args.effective_from;
      commit = args.commit;
      chapters = args.chapters;
      calendar = args.calendar;
      notes = args.notes;
    };
    published := Array.concat(published, [release]);
    audit("legislation_release_publish", caller, #Map([("source", #Text(args.source)), ("version", #Text(args.version))]), #Text("ok"));
    #Ok(#Done(null));
  };

  /// The record: the releases this realm relays, top to bottom, then its own.
  public query func ggg_legislation_releases(args : T.ListArgs) : async Result<T.ReleasePage> {
    page(Iter.concat<T.Release>(relayed.vals(), published.vals()), args.cursor, args.limit);
  };

  public query func ggg_legislation_chapter(checksum : Text) : async Result<?Blob> {
    #Ok(Map.get(chapters, Text.compare, checksum));
  };

  func position(order : [Text], source : Text) : ?Nat {
    var i = 0;
    for (s in order.vals()) { if (s == source) return ?i; i += 1 };
    null;
  };

  /// A relayed release takes the place of an earlier release of its layer, or joins the record where
  /// the vouching record lists it (`order`, its sources top to bottom): after every relayed layer that
  /// record lists above it.
  func relay(release : T.Release, order : [Text]) {
    let ?rank = position(order, release.source) else return;
    let kept = Array.filter<T.Release>(relayed, func(r) { r.source != release.source });
    var at = 0;
    var i = 0;
    for (r in kept.vals()) {
      i += 1;
      switch (position(order, r.source)) { case (?p) { if (p < rank) at := i }; case null {} };
    };
    relayed := Array.concat(Array.sliceToArray(kept, 0, at), Array.concat([release], Array.sliceToArray(kept, at, kept.size())));
  };

  /// Every release a sync source's record lists, page by page, read bounded-wait; null when it cannot
  /// be read, or runs past PAGE_LIMIT pages.
  func readRecord(capital : Principal) : async* ?[T.Release] {
    let all = List.empty<T.Release>();
    var cursor : ?Text = null;
    var pages = 0;
    loop {
      if (pages >= PAGE_LIMIT) return null;
      pages += 1;
      let reply = try { ?(await (with timeout = CALL_TIMEOUT) peer(capital).ggg_legislation_releases({ cursor; limit = ?100 })) } catch (_) { null };
      let ?(#Ok({ items; next })) = reply else return null;
      List.addAll(all, items.vals());
      switch (next) { case null return ?List.toArray(all); case (?c) cursor := ?c };
    };
  };

  /// Installs a release as the active sync sources' records list it: two records that list it
  /// differently are a Conflict, a record that cannot be read is Unavailable, and no record listing it
  /// is NotFound. The release joins this realm's record as a relayed layer.
  func installRelease(source : Text, version : Text) : async* Result<T.Release> {
    var found : ?(T.Release, [Text]) = null;
    for (s in Iter.toArray(Map.values(sources)).vals()) {
      switch (s.source, linkStatus(s.link)) {
        case (#Realm(capital), #Active) {
          let ?items = await* readRecord(capital) else {
            let why = "could not be read, or ran past " # Nat.toText(PAGE_LIMIT) # " pages";
            return #Err(#Unavailable("the record of sync source " # Principal.toText(capital) # " " # why));
          };
          let order = Array.map<T.Release, Text>(items, func(r) { r.source });
          for (r in items.vals()) {
            if (r.source == source and r.version == version) {
              switch (found) {
                case (?(first, _)) {
                  if (first.chapters != r.chapters or first.calendar != r.calendar) {
                    return #Err(#Conflict("two sync sources list " # source # " " # version # " differently"));
                  };
                };
                case null found := ?(r, order);
              };
            };
          };
        };
        case _ {};
      };
    };
    let ?(release, order) = found else return #Err(#NotFound);
    relay(release, order);
    #Ok(release);
  };

  let NOT_INSTALLABLE = "this fixture installs a codex as a release of a sync source's layer, or as a package whose source is the checksum of bytes it holds";

  /// Governed by the root, whose direct policy applies it at once: a Release joins the record (see
  /// installRelease); a Package whose source names a checksum this realm holds becomes the active codex.
  public shared ({ caller }) func ggg_codex_install(source : T.CodexSource) : async Result<T.Governed> {
    switch (requireMember(caller, "codex.install")) { case (?e) return #Err(e); case null {} };
    switch (source) {
      case (#Release { source = id; version }) {
        switch (await* installRelease(id, version)) {
          case (#Err(e)) #Err(e);
          case (#Ok(_)) {
            audit("codex_install", caller, #Map([("source", #Text(id)), ("version", #Text(version))]), #Text("ok"));
            #Ok(#Done(null));
          };
        };
      };
      case (#Package { source = checksum }) {
        let ?root = findDepartment(ROOT_ID) else return #Err(#Unavailable("the realm has no root department"));
        switch (checkInstall(checksum)) { case (?e) return #Err(e); case null {} };
        govern(caller, "codex_install", root, to_candid (source), "Install codex " # checksum, "Installs the codex " # checksum # ".", func() {
          installCodex(caller, checksum);
        });
      };
      case (#Registry _) #Err(#InvalidArgument(NOT_INSTALLABLE));
    };
  };

  func checkInstall(checksum : Text) : ?T.GggError {
    if (not stored(checksum)) return ?#InvalidArgument(NOT_INSTALLABLE);
    if (Map.containsKey(codices, Text.compare, checksum)) return ?#Conflict("codex " # checksum # " is installed already");
    null;
  };

  /// The codex becomes active, the active one inactive; it remembers which codex it replaced.
  func installCodex(caller : Principal, checksum : Text) : Result<?Text> {
    switch (checkInstall(checksum)) { case (?e) return #Err(e); case null {} };
    switch (activeCodex) {
      case (?c) { switch (Map.get(codices, Text.compare, c)) { case (?i) Map.add(codices, Text.compare, c, { i with status = #Inactive }); case null {} } };
      case null {};
    };
    Map.add(codices, Text.compare, checksum, { previous = activeCodex; status = #Active });
    codexHistory := Array.concat(codexHistory, [checksum]);
    activeCodex := ?checksum;
    audit("codex_install", caller, #Map([("codex", #Text(checksum))]), #Text(checksum));
    #Ok(?checksum);
  };

  /// The codex a revert restores: the one named, or the one the active codex replaced (model §11).
  func revertTarget(args : ?T.CodexRevertArgs) : Result<Text> {
    let ?active = activeCodex else return #Err(#Conflict("no codex is active"));
    let target = switch (args) {
      case (?{ codex = ?c }) c;
      case _ {
        let ?i = Map.get(codices, Text.compare, active) else return #Err(#Conflict("no codex is active"));
        let ?previous = i.previous else return #Err(#Conflict("the active codex replaced none"));
        previous;
      };
    };
    if (not Map.containsKey(codices, Text.compare, target)) return #Err(#NotFound);
    if (target == active) return #Err(#Conflict("codex " # target # " is active already"));
    #Ok(target);
  };

  /// Restores `target`: it is active again, and the codex it displaces is reverted. It never runs a hook.
  func revertCodex(caller : Principal, target : Text) : Result<?Text> {
    switch (activeCodex) {
      case (?c) { switch (Map.get(codices, Text.compare, c)) { case (?i) Map.add(codices, Text.compare, c, { i with status = #Reverted }); case null {} } };
      case null {};
    };
    switch (Map.get(codices, Text.compare, target)) {
      case (?i) Map.add(codices, Text.compare, target, { i with status = #Active });
      case null return #Err(#NotFound);
    };
    activeCodex := ?target;
    audit("codex_revert", caller, #Map([("codex", #Text(target))]), #Text(target));
    #Ok(null);
  };

  /// Governed by the root, whose direct policy applies it at once (model §11).
  public shared ({ caller }) func ggg_codex_revert(args : ?T.CodexRevertArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "codex.revert")) { case (?e) return #Err(e); case null {} };
    let ?root = findDepartment(ROOT_ID) else return #Err(#Unavailable("the realm has no root department"));
    let target = switch (revertTarget(args)) { case (#Err(e)) return #Err(e); case (#Ok(t)) t };
    govern(caller, "codex_revert", root, to_candid (args), "Revert to codex " # target, "Restores the codex " # target # ".", func() {
      switch (revertTarget(args)) { case (#Err(e)) #Err(e); case (#Ok(t)) revertCodex(caller, t) };
    });
  };

  // §11

  /// The active codex and the earlier ones, in install order.
  public query func ggg_codex_status(args : T.ListArgs) : async Result<T.CodexView> {
    let signing = { agents = []; delegable = []; supervision = #Required };
    let earlier = Iter.filter<Text>(codexHistory.vals(), func(c) { ?c != activeCodex });
    switch (page(earlier, args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ checksum = activeCodex; pending = null; healthy = activeCodex != null; signing; history = items; next });
    };
  };

  public query func ggg_notification_list(args : T.NotificationListArgs) : async Result<T.NotificationPage> {
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  public query func ggg_external_list(args : T.ListArgs) : async Result<T.ExternalPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_dispatch_list(args : T.DispatchListArgs) : async Result<T.DispatchPage> {
    none(args.cursor, args.limit);
  };

  public query func ggg_task_list(args : T.TaskListArgs) : async Result<T.TaskPage> {
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
      sync_sources = Iter.toArray(Iter.map<Source, T.SyncSource>(Map.values(sources), sourceView));
      trusted_principals = [];
      require_marketplace_approval = false;
      trusted_approvers = [];
      voting_threshold = votingThreshold;
      voting_quorum = votingQuorum;
      casting_vote = castingVote;
      open_registration = false;
      logo_url = null;
      background_image_url = null;
      installed_version = "ggg-fixture 0.5.0";
      network = "local";
      timezone = "Europe/Madrid";
      languages = [];
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
  public shared ({ caller }) func ggg_department_set_policy(_ : T.DepartmentPolicyArgs) : async Result<T.Governed> { notHere(caller, "org.set_policy", "changes no policy") };
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
  public shared ({ caller }) func ggg_transfer_revert(_ : T.TransferRevertArgs) : async Result<T.Governed> { nobody(caller, "transfer.delete") };
  public shared ({ caller }) func ggg_invoice_create(_ : T.InvoiceCreateArgs) : async Result<T.InvoiceCreated> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_invoice_check(_ : T.InvoiceCheckArgs) : async Result<T.Invoice> { nobody(caller, "self.invoice_refresh") };
  public shared ({ caller }) func ggg_invoice_refresh(_ : T.InvoiceRefreshArgs) : async Result<T.InvoicePage> { nobody(caller, "invoice.refresh") };
  public shared ({ caller }) func ggg_invoice_item_add(_ : T.InvoiceItemAddArgs) : async Result<T.Invoice> { nobody(caller, "treasury.manage") };
  public shared ({ caller }) func ggg_period_close(_ : Text) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_budget_amend(_ : T.BudgetAmendArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_allocation_rule_draft(_ : T.AllocationRuleDraftArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_allocation_rule_propose(_ : Text) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_payroll_run(_ : T.PayrollRunArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_loan_create(_ : T.LoanCreateArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_loan_repay(_ : T.LoanRepayArgs) : async Result<T.Loan> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
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
  public shared ({ caller }) func ggg_land_assess(_ : T.LandAssessArgs) : async Result<T.Land> { nobody(caller, "land.assess") };
  public shared ({ caller }) func ggg_land_freeze(_ : T.LandFreezeArgs) : async Result<T.Land> { nobody(caller, "nft.freeze") };
  public shared ({ caller }) func ggg_land_unfreeze(_ : Text) : async Result<T.Land> { nobody(caller, "nft.freeze") };
  public shared ({ caller }) func ggg_zone_define(_ : T.ZoneDefineArgs) : async Result<T.Governed> { nobody(caller, "realm.configure") };
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
  public shared ({ caller }) func ggg_procedure_define(_ : T.ProcedureDefineArgs) : async Result<T.Governed> { nobody(caller, "procedure.define") };
  public shared ({ caller }) func ggg_request_file(_ : T.RequestFileArgs) : async Result<T.Request> { nobody(caller, "request.file") };
  public shared ({ caller }) func ggg_request_set_due(_ : T.RequestSetDueArgs) : async Result<T.Request> { nobody(caller, "request.decide") };
  public shared ({ caller }) func ggg_request_decide(_ : T.RequestDecideArgs) : async Result<T.Request> { nobody(caller, "request.decide") };

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
  public shared ({ caller }) func ggg_tender_notice(_ : T.TenderNoticeArgs) : async Result<T.Tender> { nobody(caller, "tender.manage") };

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
  public shared ({ caller }) func ggg_codex_uninstall() : async Result<T.Governed> { nobody(caller, "codex.install") };
  public shared ({ caller }) func ggg_codex_activate(_ : T.CodexActivateArgs) : async Result<T.Governed> { nobody(caller, "codex.install") };
  public shared ({ caller }) func ggg_notification_read(_ : T.NotificationReadArgs) : async Result<T.NotificationsRead> { nobody(caller, "self.data_manage") };
  public shared ({ caller }) func ggg_notification_send(_ : T.NotificationSendArgs) : async Result<T.Delivery> { nobody(caller, "notification.send") };
  public shared ({ caller }) func ggg_external_add(_ : T.ExternalAddArgs) : async Result<T.Governed> { nobody(caller, "external.manage") };
  public shared ({ caller }) func ggg_external_report(_ : T.ExternalReportArgs) : async Result<T.Event> { nobody(caller, "external.report") };
  public shared ({ caller }) func ggg_dispatch_confirm(_ : T.DispatchConfirmArgs) : async Result<T.Dispatch> { nobody(caller, "dispatch.confirm") };
  public shared ({ caller }) func ggg_task_schedule(_ : T.TaskScheduleArgs) : async Result<T.Task> { nobody(caller, "task.schedule") };
  public shared ({ caller }) func ggg_task_reschedule(_ : T.TaskRescheduleArgs) : async Result<T.Task> { nobody(caller, "task.schedule") };
  public shared ({ caller }) func ggg_task_cancel(_ : Text) : async Result<T.Task> { nobody(caller, "task.schedule") };

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
  public shared ({ caller }) func ggg_document_publish(_ : T.DocumentPublishArgs) : async Result<T.Document> { nobody(caller, "document.manage") };
  public shared ({ caller }) func ggg_document_revoke(_ : T.DocumentRevokeArgs) : async Result<Nat> { nobody(caller, "document.manage") };
  public shared ({ caller }) func ggg_document_delete(_ : T.DocumentDeleteArgs) : async Result<T.DocumentDeleted> { nobody(caller, "document.manage") };

};
