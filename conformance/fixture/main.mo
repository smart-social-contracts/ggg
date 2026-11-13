/// A minimal GGG GOS, used to test the conformance suite. It implements every method of ggg.did.
/// Members are fixed at install time. They may propose, vote, manage proposals (open, finalize,
/// execute and stop them), set the realm's governance rule (governance_update, which the root's direct
/// policy applies at once), read the realm, manage their own profile, and submit and review attributes
/// (every member holds attribute.review here, without a scope, so each reads every pending attribute
/// and decides all but their own, and the audit log keeps an attribute's id, never its kind or value);
/// every other permission is held by nobody, so those operations are refused. There are five departments:
/// the root, with a direct policy, so a governed call on a realm-wide proposal is applied at once; a
/// council under it, deciding 2 of 3 with a 60 % quorum, so a governed call on one of its proposals
/// files a proposal instead; two committees under the council, each deciding alone, so that a
/// proposal of the council can carry a call on a committee's records where a committee's cannot carry
/// one on its sibling's (I-GOV-13); and a plenary of five seats under the root, deciding by a majority of
/// the votes cast with half of its seats voting, chaired by the first member, whose casting vote
/// decides a tie in a second vote (I-GOV-3, I-GOV-14).
/// Members may also edit a department (department_edit, governed by that department, or by the lowest
/// department above both the old and the new parent when it moves) and delete one that has none below
/// it (department_delete, governed by its parent), so a committee can be moved or removed while a
/// proposal that acts on it waits; they hold org.set_policy for that, and department_set_policy is
/// refused. They also create funds and draft and propose budget lines (fund_create, budget_draft,
/// budget_propose, each governed by the fund's owner, or by the root for every fund's lines), with
/// org.manage_budget; a period is a name that period_open records in order, budget_extend copies the
/// previous period's adopted lines fund by fund, and transfer_create moves no money but refuses a
/// category outside a fund's adopted budget (model §5). A transfer is charged to its adopted expense
/// line, from its committed money or its available credit, and is refused when that is short;
/// budget_stage reserves and commits a line's money, a transfer with a due date is scheduled until
/// transfer_pay, and transfer_revert, with transfer.delete, cancels a scheduled one and gives its money
/// back (I-FIN-9, I-FIN-10). They register tokens and quarters, join a capital, set its sweep rules and
/// sweep a quarter's money into it (treasury.manage, quarter.register, quarter.join_federation): its
/// money is what its own account holds on the token's ledger, and it sweeps only when quarter_sweep
/// asks (I-FED-5 to 7). They make, amend and terminate contracts
/// (contract_create, contract_amend and contract_terminate, with contract.create_under_mandate,
/// contract.amend and contract.terminate): no mandate or tender exists here, so the root owns every
/// contract and its direct policy applies an amendment at once, unless a proposal carries it, and
/// contract_get reads a contract with its amendments (I-GOV-16). A transfer for a contract is refused
/// past the contract's value, and an amendment below what has been paid on it (I-FIN-11). They register organizations, of a kind
/// or Other, and an organization's admins edit it, its kind too (I-ORG-9), with organization.add and
/// organization.edit; no organization seats representatives. No department has seats: every member may vote on a
/// department's proposal (its tally.eligible), and its threshold is measured against its policy's n
/// (tally.seats), as I-GOV-3 says: two yes votes carry a council proposal whether two or twenty
/// members vote. The fixture never ends a department vote early (I-GOV-7 allows it, it does not
/// require it): that needs veto holders, who must hold a seat (I-ORG-5). Nor does it settle a
/// proposal as its vote ends or run an accepted action as it finalizes (I-GOV-12): proposal_finalize
/// records the outcome of a vote that has ended, and proposal_execute runs the action. Nobody has
/// granted a delegation, so nobody acts on another's behalf. Every other domain is empty, which the
/// model allows. A proposal's rule is its scope's, the realm's over the votes cast, a
/// department's m/n over its policy's n, or the plenary's majority of the votes cast, unless the
/// proposer states a stricter one, which the fixture stores and applies (I-GOV-3). A tie in the
/// plenary's first vote is recorded by proposal_finalize, which opens the second vote (I-GOV-14).
/// A proposal keeps the tags it was filed with, and the list filters by them (I-GOV-15); with no drafts,
/// no proposal's tags are ever replaced.
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
import Char "mo:core/Char";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Map "mo:core/Map";
import Nat "mo:core/Nat";
import Nat32 "mo:core/Nat32";
import Nat64 "mo:core/Nat64";
import Option "mo:core/Option";
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
  let MAX_TAGS = 16; // a proposal's tags, and the tags a list filters by
  let MAX_TAG_SIZE = 64; // code points
  /// The realm's governance rule, set with governance_update: the voting window, and the threshold,
  /// quorum and casting vote of a realm-wide proposal.
  var votingWindow : T.Duration = 7 * 24 * 3600 * 1_000_000_000;
  var votingThreshold : T.Ratio = 50_000_000; // 50 %
  var votingQuorum : T.Ratio = 0;
  var castingVote : ?Principal = null;
  /// The rule that decides a proposal (I-GOV-3). The scope's unless the proposer states a stricter
  /// threshold, quorum or basis; the casting vote, and whether a department's majority of the votes cast
  /// applies, are the scope's.
  type Rule = { threshold : T.Ratio; quorum : T.Ratio; threshold_of : T.ThresholdBasis; casting_vote : ?Principal; majority_of_cast : Bool };
  func defaultRule() : Rule = { threshold = votingThreshold; quorum = votingQuorum; threshold_of = #Cast; casting_vote = castingVote; majority_of_cast = false };
  /// The rule of a proposal of `department` (I-GOV-3): the realm's, over the votes cast and with its
  /// casting vote, for the root; for a department whose policy counts the votes cast, a majority of them,
  /// with the policy's quorum and the head's casting vote; for any other, m/n of its policy, rounded
  /// down, over its n seats, with the policy's quorum.
  func scopeRule(department : T.Department) : Rule {
    if (department.is_root) return defaultRule();
    let { m; n; quorum } = department.policy;
    if (department.policy.threshold_of == ?#Cast) {
      return { threshold = WHOLE / 2; quorum; threshold_of = #Cast; casting_vote = department.head; majority_of_cast = true };
    };
    { threshold = m * WHOLE / n; quorum; threshold_of = #Eligible; casting_vote = null; majority_of_cast = false };
  };
  let NOT_SCHEDULED = "only a proposal whose execution is scheduled can be stopped";
  let NO_MORE_BUDGETING = "closes no period and keeps no allocation rules, payroll or loans";
  let NO_INVOICING = "registers tokens and sweeps money, but issues no NFT, invoice or report";
  let NO_QUARTER_CHANGES = "registers quarters, but never deregisters or reconfigures one";
  let OUT_OF_SCOPE = "a department's proposal carries only the calls that department, or one below it, governs";

  func now() : T.Timestamp = Nat64.fromNat(Int.abs(Time.now()));

  let ROOT_ID = "root";
  let DIRECT : T.Policy = { m = 1; n = 1; quorum = 0; veto = []; threshold_of = null };

  func department(id : Text, description : Text, parent : ?Text, policy : T.Policy) : T.Department = {
    id; description; kind = null; parent; is_root = parent == null; head = null; policy; target_policy = null; fund = null;
  };

  /// The root decides alone; the council under it, 2 of 3; the two committees under the council, alone;
  /// the plenary under the root, by a majority of the votes cast, chaired by the first member.
  /// department_edit may move a department, so the tree is read as it stands at each check.
  let departments = Map.empty<Text, T.Department>();
  for (d in [
    department(ROOT_ID, "The realm itself.", null, DIRECT),
    department(
      "council",
      "A council under the realm, deciding 2 of 3 with a 60 % quorum.",
      ?ROOT_ID,
      { m = 2; n = 3; quorum = 60_000_000; veto = []; threshold_of = null },
    ),
    department("roads", "A committee under the council, deciding alone.", ?"council", DIRECT),
    department("parks", "A committee under the council, deciding alone.", ?"council", DIRECT),
    {
      department(
        "plenary",
        "A plenary of five seats under the realm, deciding by a majority of the votes cast with half of its seats voting.",
        ?ROOT_ID,
        { m = 1; n = 5; quorum = 50_000_000; veto = []; threshold_of = ?#Cast },
      ) with kind = ?"plenary";
      head = if (initMembers.size() > 0) ?initMembers[0] else null;
    },
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
  // The members' attributes (model §2) by the n of their id `A-<n>`; a member's `human` is their
  // principal here.
  let attributes = Map.empty<Nat, T.Attribute>();
  var nextAttribute = 1;
  var nextProposal = 1;
  // Funds and budget lines (model §5): enough to govern a budget by its fund's owner (D19).
  let funds = Map.empty<Text, T.Fund>();
  /// The ledger's fee, the one entry a GOS books itself and the only one exempt from an adopted budget:
  /// reserved, so no transfer or budget line names it (model §5, D30).
  let FEE_CATEGORY = "ledger_fee";
  /// A sweep's entries, booked by the realm itself and neither revenue nor spending: reserved too (I-FED-7).
  let SWEEP_CATEGORY = "sweep";
  let budgets = Map.empty<Nat, T.Budget>();
  var nextBudget = 1;
  // Transfers by id. The realm holds no token here, so a transfer that names none is in REALM.
  let transfers = Map.empty<Text, T.Transfer>();
  var nextTransfer = 1;
  let REALM_TOKEN = "REALM";
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
      case "ggg_budget_draft" {
        let a : ?T.BudgetDraftArgs = from_candid (arg);
        switch (a) { case (?d) { switch (reservedCategory(?d.category)) { case (?e) return ?e; case null true } }; case null false };
      };
      case "ggg_budget_propose" { let a : ?T.BudgetProposeArgs = from_candid (arg); a != null };
      case "ggg_transfer_create" {
        let a : ?T.TransferCreateArgs = from_candid (arg);
        switch (a) { case (?t) { switch (reservedCategory(t.category)) { case (?e) return ?e; case null true } }; case null false };
      };
      case "ggg_codex_install" { let a : ?T.CodexSource = from_candid (arg); a != null };
      case "ggg_codex_revert" {
        let a : ?(?T.CodexRevertArgs) = from_candid (arg);
        switch (a) {
          case (?(?{ codex = ?_ })) true;
          case (?_) return ?#InvalidArgument(REVERT_NAMES_CODEX);
          case null false;
        };
      };
      case "ggg_profile_update" { let a : ?T.ProfileUpdateArgs = from_candid (arg); a != null };
      case "ggg_contract_amend" { let a : ?T.ContractAmendArgs = from_candid (arg); a != null };
      case "ggg_budget_stage" { let a : ?T.BudgetStageArgs = from_candid (arg); a != null };
      case "ggg_transfer_revert" { let a : ?T.TransferRevertArgs = from_candid (arg); a != null };
      case "ggg_sweep_resolve" { let a : ?T.SweepResolveArgs = from_candid (arg); a != null };
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
      case "ggg_budget_stage" {
        let ?args : ?T.BudgetStageArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        let ?line = Array.find<T.Budget>(Iter.toArray(Map.values(budgets)), func(b) { b.id == args.budget }) else return #Err(#NotFound);
        switch (fundOwner(line.fund)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d };
      };
      case "ggg_transfer_revert" {
        let ?args : ?T.TransferRevertArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        let ?transfer = Map.get(transfers, Text.compare, args.transfer) else return #Err(#NotFound);
        switch (fundOwner(transfer.sender.id)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d };
      };
      case "ggg_sweep_resolve" {
        let ?args : ?T.SweepResolveArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        let ?sweep = Map.get(sweeps, Text.compare, args.sweep) else return #Err(#NotFound);
        switch (fundOwner(sweep.fund)) { case (#Err(e)) return #Err(e); case (#Ok(d)) d };
      };
      case "ggg_contract_amend" {
        let ?args : ?T.ContractAmendArgs = from_candid (arg) else return #Err(#InvalidArgument("arg does not decode"));
        // No contract here names a mandate or a tender, so the root owns each one (model §1).
        if (not Map.containsKey(contracts, Text.compare, args.contract)) return #Err(#NotFound);
        ROOT_ID;
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
      let filed = fileProposal(caller, title, description, scope, null, null, call, scopeRule(governing), null, [], []);
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
      grant = null;
      prepared_by = null;
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
  /// casting vote, and a department's majority of the votes cast, are the scope's.
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
    #Ok({ scope with threshold; quorum; threshold_of });
  };

  /// The member a proposal was filed for: the grantor when it was filed on their behalf.
  func filedFor(p : T.Proposal) : Principal {
    switch (p.on_behalf_of) { case (?grantor) grantor; case null p.proposer };
  };

  /// Unicode's control characters (category Cc): U+0000 to U+001F and U+007F to U+009F.
  func isControl(c : Char) : Bool {
    let code = Char.toNat32(c);
    code < 0x20 or (code >= 0x7F and code <= 0x9F);
  };

  /// Whether a tag has a control character anywhere, or whitespace at either end (I-GOV-15).
  func badTagCharacters(t : Text) : Bool {
    let chars = Text.toArray(t);
    if (chars.size() == 0) return false;
    Char.isWhitespace(chars[0]) or Char.isWhitespace(chars[chars.size() - 1]) or Array.any<Char>(chars, isControl);
  };

  /// Refuses tags that break I-GOV-15: too many, empty or too long (in code points, which Text.size
  /// counts), padded with whitespace or holding a control character, or one named twice.
  func checkTags(tags : [Text]) : ?T.GggError {
    if (tags.size() > MAX_TAGS) return ?#InvalidArgument("a proposal has at most 16 tags");
    let named = Map.empty<Text, ()>();
    for (t in tags.vals()) {
      if (Text.size(t) == 0 or Text.size(t) > MAX_TAG_SIZE) return ?#InvalidArgument("a tag is 1 to 64 code points");
      if (badTagCharacters(t)) return ?#InvalidArgument("a tag has no control characters and no whitespace at either end");
      if (Map.containsKey(named, Text.compare, t)) return ?#InvalidArgument("the tags name " # t # " twice");
      Map.add(named, Text.compare, t, ());
    };
    null;
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

  /// The caller's own attributes, of one kind when `kind` is given.
  public query ({ caller }) func ggg_attribute_list(args : T.AttributeListArgs) : async Result<T.AttributePage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    let mine = Iter.filter<T.Attribute>(Map.values(attributes), func(a) {
      a.human == Principal.toText(caller) and (switch (args.kind) { case (?k) a.kind == k; case null true });
    });
    page(mine, args.cursor, args.limit);
  };

  /// The attributes awaiting review, kind and value in clear, for the holders of attribute.review
  /// (model §2, I-PRV-1). The cursor is the id of the last attribute returned and the page continues
  /// after it, so deciding a page skips none.
  public query ({ caller }) func ggg_attribute_pending_list(args : T.ListArgs) : async Result<T.AttributePage> {
    switch (requireMember(caller, "attribute.review")) { case (?e) return #Err(e); case null {} };
    let after = switch (args.cursor) {
      case null 0;
      case (?c) { let ?n = attributeNumber(c) else return #Err(#InvalidArgument("unknown cursor")); n };
    };
    let pending = Iter.filter<(Nat, T.Attribute)>(Map.entries(attributes), func((n, a)) { n > after and a.status == #Pending });
    let size = pageSize(args.limit);
    let items = Iter.toArray(Iter.map<(Nat, T.Attribute), T.Attribute>(Iter.take(pending, size + 1), func((_, a)) { a }));
    if (items.size() > size) {
      #Ok({ items = Array.sliceToArray(items, 0, size); next = ?items[size - 1].id });
    } else {
      #Ok({ items; next = null });
    };
  };

  /// The n of an attribute id `A-<n>`.
  func attributeNumber(id : Text) : ?Nat {
    let ?rest = Text.stripStart(id, #text "A-") else return null;
    Nat.fromText(rest);
  };

  public query func ggg_delegable_operations() : async Result<[T.DelegableOperation]> {
    #Ok([]);
  };

  /// No member holds self.delegate, so there is no group anyone here can grant.
  public query ({ caller }) func ggg_delegation_groups(args : T.DelegationGroupsArgs) : async Result<T.DelegationGroupPage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    none(args.cursor, args.limit);
  };

  /// Nobody has granted a delegation, so no grant has the id asked for.
  public query ({ caller }) func ggg_delegation_activity(args : T.DelegationActivityArgs) : async Result<T.EventPage> {
    switch (requireMember(caller, "self.data_view")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("self.data_view"));
    #Err(#NotFound);
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
        "attribute.submit",
        "attribute.review",
        "proposal.create",
        "proposal.vote",
        "governance.update",
        "org.set_policy",
        "org.manage_budget",
        "transfer.create",
        "transfer.delete",
        "treasury.view",
        "treasury.manage",
        "quarter.register",
        "quarter.join_federation",
        "contract.create_under_mandate",
        "contract.amend",
        "contract.terminate",
        "organization.add",
        "organization.edit",
        "codex.install",
        "codex.revert",
        "realm.data_view",
        "realm.monitor",
        "self.confirm",
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
  /// Files an attribute of the caller's, pending review. The audit event keeps its id, never its kind
  /// or value (I-PRV-1).
  public shared ({ caller }) func ggg_attribute_submit(args : T.AttributeSubmitArgs) : async Result<T.Attribute> {
    switch (requireMember(caller, "attribute.submit")) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.kind) == 0 or Text.size(args.value) == 0) return #Err(#InvalidArgument("kind and value are not empty"));
    let attribute : T.Attribute = {
      id = "A-" # Nat.toText(nextAttribute);
      human = Principal.toText(caller);
      kind = args.kind;
      value = args.value;
      issuer = switch (args.issuer) { case (?i) i; case null "" };
      ref = args.ref;
      status = #Pending;
      verified_at = null;
      expires_at = args.expires_at;
    };
    Map.add(attributes, Nat.compare, nextAttribute, attribute);
    nextAttribute += 1;
    audit("attribute_submit", caller, #Map([("attribute", #Text(attribute.id))]), #Text(attribute.id));
    #Ok(attribute);
  };

  /// Decides a pending attribute. The audit event keeps its id and the decision, never its kind or
  /// value (I-PRV-1).
  public shared ({ caller }) func ggg_attribute_review(args : T.AttributeReviewArgs) : async Result<T.Attribute> {
    switch (requireMember(caller, "attribute.review")) { case (?e) return #Err(e); case null {} };
    let ?n = attributeNumber(args.attribute) else return #Err(#NotFound);
    let ?a = Map.get(attributes, Nat.compare, n) else return #Err(#NotFound);
    if (a.human == Principal.toText(caller)) {
      return #Err(#Forbidden({ permission = ?"attribute.review"; message = "Nobody decides their own attribute (I-ALL-3)." }));
    };
    if (a.status != #Pending) return #Err(#Conflict("attribute " # a.id # " is decided already"));
    let (reviewed, decision) = switch (args.status) {
      case (#Verified) ({ a with status = #Verified; verified_at = ?now() }, "verified");
      case (#Rejected) ({ a with status = #Rejected }, "rejected");
    };
    Map.add(attributes, Nat.compare, n, reviewed);
    audit("attribute_review", caller, #Map([("attribute", #Text(a.id))]), #Text(decision));
    #Ok(reviewed);
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
  // Pending actions (model §2). Nobody delegates here, so none is ever filed. Any signed-in principal reads
  // its own: a delegate that is no member reads the outcome of what it prepared.

  public query ({ caller }) func ggg_action_get(_ : Text) : async Result<?T.PendingAction> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    #Ok(null);
  };

  public query ({ caller }) func ggg_action_list(args : T.ActionListArgs) : async Result<T.PendingActionPage> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    none(args.cursor, args.limit);
  };

  /// Approving or declining is the member's own act: refused under any grant before the action is looked up.
  func decide(caller : Principal, on_behalf_of : ?Principal) : Result<T.PendingAction> {
    switch (requireMember(caller, "self.confirm")) { case (?e) return #Err(e); case null {} };
    if (on_behalf_of != null) {
      return #Err(#Forbidden({ permission = ?"self.confirm"; message = "Approving or declining a pending action is the member's own act: never under a grant." }));
    };
    #Err(#NotFound);
  };
  public shared ({ caller }) func ggg_action_approve(args : T.ActionApproveArgs) : async Result<T.PendingAction> {
    decide(caller, args.on_behalf_of);
  };
  public shared ({ caller }) func ggg_action_decline(args : T.ActionDeclineArgs) : async Result<T.PendingAction> {
    decide(caller, args.on_behalf_of);
  };
  public shared ({ caller }) func ggg_action_withdraw(_ : Text) : async Result<T.PendingAction> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    #Err(#NotFound);
  };
  public shared ({ caller }) func ggg_action_collect(_ : Text) : async Result<Blob> {
    if (Principal.isAnonymous(caller)) return #Err(#Unauthenticated);
    #Err(#NotFound);
  };

  /// Why a generic call on a grantor's behalf is refused here: it must carry a method of ggg.did other than
  /// the generic calls themselves, for someone other than the caller; and nobody has granted a delegation.
  func noGenericCall(caller : Principal, method : Text, on_behalf_of : Principal) : T.GggError {
    if (Principal.isAnonymous(caller)) return #Unauthenticated;
    if (not Text.startsWith(method, #text "ggg_") or method == "ggg_call_for" or method == "ggg_read_for") {
      return #InvalidArgument(method # " cannot be carried by the generic call");
    };
    if (on_behalf_of == caller) return #InvalidArgument("on_behalf_of is the caller");
    #Forbidden({ permission = null; message = "No active delegation from that principal covers " # method # "." });
  };
  public shared ({ caller }) func ggg_call_for(args : T.CallForArgs) : async Result<T.CallForReply> {
    #Err(noGenericCall(caller, args.method, args.on_behalf_of));
  };
  public query ({ caller }) func ggg_read_for(args : T.ReadForArgs) : async Result<Blob> {
    #Err(noGenericCall(caller, args.method, args.on_behalf_of));
  };

  /// Revoking every grant is the member's own act: with on_behalf_of it is refused, whoever the caller is.
  public shared ({ caller }) func ggg_delegation_revoke_all(args : T.DelegationRevokeAllArgs) : async Result<T.DelegationsRevoked> {
    switch (requireMember(caller, "self.delegate")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) {
      return #Err(#Forbidden({ permission = ?"self.delegate"; message = "Revoking every grant is the member's own act: never under a grant." }));
    };
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

  /// Whether `period` already holds `category` of `fund` as a line of the other kind than `kind`, in any
  /// status: within a fund and period a category is either revenue or expense (model §5).
  func otherKindHeld(fund : Text, period : Text, category : Text, kind : T.BudgetKind) : Bool {
    for (b in Map.values(budgets)) {
      if (b.fund == fund and b.period == period and b.category == category and b.kind != kind) return true;
    };
    false;
  };

  /// `ledger_fee` is reserved for the fee's ledger entry, which the realm books itself (model §5, D30).
  func reservedCategory(category : ?Text) : ?T.GggError {
    if (category == ?FEE_CATEGORY) return ?#InvalidArgument("category " # FEE_CATEGORY # " is reserved for the ledger's fee, which the realm books itself");
    if (category == ?SWEEP_CATEGORY) return ?#InvalidArgument("category " # SWEEP_CATEGORY # " is reserved for sweeps, which the realm books itself");
    null;
  };

  func checkDraft(args : T.BudgetDraftArgs) : ?T.GggError {
    switch (reservedCategory(?args.category)) { case (?e) return ?e; case null {} };
    if (otherKindHeld(args.fund, args.period, args.category, args.kind)) {
      return ?#InvalidArgument("category " # args.category # " of " # args.fund # " in " # args.period # " is of the other kind");
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
      reserved = 0;
      committed = 0;
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
    switch (checkCarried(lines)) { case (?e) return #Err(e); case null {} };
    // Line by line, in the order drafted: the fund's extended lines and an earlier adopted line of the
    // same category are amended, the spending booked against the latter carried over, then the line is
    // adopted; so a dropped category does not come back and one line stands per fund, period and
    // category, within one adoption too (D24, D30).
    for ((n, line) in lines.vals()) {
      var carried = { reserved = 0; committed = 0; actual = 0 };
      label replace for ((m, b) in Iter.toArray(Map.entries(budgets)).vals()) {
        if (b.fund != line.fund or b.period != line.period) continue replace;
        if (b.status == #Extended) Map.add(budgets, Nat.compare, m, { b with status = #Amended });
        if (b.status == #Adopted and b.category == line.category) {
          Map.add(budgets, Nat.compare, m, { b with status = #Amended });
          carried := { reserved = carried.reserved + b.reserved; committed = carried.committed + b.committed; actual = carried.actual + b.actual };
        };
      };
      let adopted = {
        line with status = #Adopted;
        reserved = line.reserved + carried.reserved;
        committed = line.committed + carried.committed;
        actual = line.actual + carried.actual;
      };
      Map.add(budgets, Nat.compare, n, adopted);
    };
    audit("budget_propose", caller, #Map([("period", #Text(args.period)), ("lines", #Nat(lines.size()))]), #Text("ok"));
    #Ok(null);
  };

  /// What an adopted line holds besides its available credit, which a line replacing it carries (I-FIN-9).
  func held(b : T.Budget) : T.Money = b.reserved + b.committed + b.actual;

  /// Refuses an adoption with a line that would hold more than it plans, with what it carries (I-FIN-9).
  func checkCarried(lines : [(Nat, T.Budget)]) : ?T.GggError {
    for ((_, line) in lines.vals()) {
      for (b in Map.values(budgets)) {
        let replaced = b.status == #Adopted and b.fund == line.fund and b.period == line.period and b.category == line.category;
        if (replaced and held(b) > line.planned) {
          return ?#Conflict("line " # line.id # " plans " # Nat.toText(line.planned) # ", less than the " # Nat.toText(held(b)) # " that " # b.id # " holds");
        };
      };
    };
    null;
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

  /// Copies the lines that stood at the previous period's end (adopted, extended or closed with it) into
  /// `period` as extended, fund by fund, for the funds with no extended, proposed or adopted line in it
  /// yet, leaving out a category the new period holds as the other kind (model §5). Replies how many
  /// lines it copied.
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
        label carry for ((_, b) in linesOf(f.id, earlier, [#Adopted, #Extended, #Closed]).vals()) {
          if (otherKindHeld(f.id, period, b.category, b.kind)) continue carry;
          let n = nextBudget;
          nextBudget += 1;
          Map.add(budgets, Nat.compare, n, { b with id = "B-" # Nat.toText(n); period; status = #Extended; proposal = null; reserved = 0; committed = 0 });
          copied += 1;
        };
      };
    };
    if (copied == 0) return #Err(#Conflict("no fund is left to extend into " # period));
    audit("budget_extend", caller, #Map([("period", #Text(period)), ("lines", #Nat(copied))]), #Text("ok"));
    #Ok(copied);
  };

  /// The line a transfer is charged to (I-FIN-9). An adopted budget is exhaustive for its fund: in the
  /// current period, a transfer from a fund with an adopted budget names a category with an adopted
  /// expense line, and is charged to it; one with no category is the category "transfer" (model §5,
  /// D24). A fund with no adopted budget charges no line.
  func chargedLine(args : T.TransferCreateArgs) : Result<?(Nat, T.Budget)> {
    switch (reservedCategory(args.category)) { case (?e) return #Err(e); case null {} };
    let ?period = currentPeriod() else return #Ok(null);
    let adopted = linesOf(args.fund, period, [#Adopted]);
    if (adopted.size() == 0) return #Ok(null);
    let named = switch (args.category) { case (?c) c; case null "transfer" };
    switch (Array.find<(Nat, T.Budget)>(adopted, func((_, b)) { b.category == named and b.kind == #Expense })) {
      case (?line) #Ok(?line);
      case null #Err(#Conflict("the adopted budget of " # args.fund # " for " # period # " has no expense line for " # named));
    };
  };

  func available(b : T.Budget) : Nat = b.planned - held(b);

  func describe(b : T.Budget) : Text = "line " # b.id # " (" # b.fund # ", " # b.period # ", " # b.category # ")";

  /// Refuses a transfer its line cannot pay: from its committed money when `committed`, else from its
  /// available credit. The message names the line and says by how much it is short (I-FIN-9).
  func checkCharge(line : T.Budget, amount : T.Money, committed : Bool) : ?T.GggError {
    let (has, what) = if (committed) (line.committed, "committed") else (available(line), "available");
    if (amount <= has) return null;
    ?#Conflict(describe(line) # " has " # Nat.toText(has) # " " # what # "; the transfer of " # Nat.toText(amount) # " is " # Nat.toText(amount - has) # " short");
  };

  /// What has been paid on a contract: its transfers that neither failed nor were cancelled, so a
  /// scheduled one, which is owed, counts (I-FIN-11).
  func paidOn(contract : Text) : Nat {
    var sum = 0;
    for (t in Map.values(transfers)) {
      if (t.contract == ?contract and t.status != #Failed and t.status != #Cancelled) sum += t.amount;
    };
    sum;
  };

  /// A transfer for a contract is in the contract's symbol and leaves the payments on it within its
  /// value (I-FIN-11).
  func checkPayment(args : T.TransferCreateArgs) : ?T.GggError {
    let ?id = args.contract else return null;
    let ?contract = Map.get(contracts, Text.compare, id) else return ?#NotFound;
    let symbol = switch (args.symbol) { case (?s) s; case null REALM_TOKEN };
    if (symbol != contract.symbol) return ?#InvalidArgument("a transfer for contract " # id # " is in " # contract.symbol);
    let left = contract.value - paidOn(id) : Nat;
    if (args.amount <= left) return null;
    ?#Conflict("contract " # id # " has " # Nat.toText(left) # " left of its value; the transfer of " # Nat.toText(args.amount) # " is " # Nat.toText(args.amount - left) # " over");
  };

  /// The line and the checks a transfer meets before it is filed, and again when it applies.
  func checkSpending(args : T.TransferCreateArgs) : Result<?(Nat, T.Budget)> {
    switch (checkPayment(args)) { case (?e) return #Err(e); case null {} };
    let line = switch (chargedLine(args)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l };
    switch (line) {
      case (?(_, b)) { switch (checkCharge(b, args.amount, args.committed == ?true)) { case (?e) return #Err(e); case null {} } };
      case null {};
    };
    #Ok(line);
  };

  /// Governed by the fund's owner (I-FIN-2). This fixture moves no money: it charges the budget line and
  /// records the transfer, completed at once, or scheduled when it has a due date (I-FIN-9, I-FIN-10).
  public shared ({ caller }) func ggg_transfer_create(args : T.TransferCreateArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "transfer.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("transfer.create"));
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_transfer_create", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (checkSpending(args)) { case (#Err(e)) return #Err(e); case (#Ok(_)) {} };
    switch (args.due_at) {
      case (?due) { if (due <= now()) return #Err(#InvalidArgument("due_at must lie in the future")) };
      case null {};
    };
    govern(caller, "transfer_create", governing, arg, "Transfer from " # args.fund, "Transfers from the fund " # args.fund # ".", func() {
      spend(caller, args);
    });
  };

  func spend(caller : Principal, args : T.TransferCreateArgs) : Result<?Text> {
    let line = switch (checkSpending(args)) { case (#Err(e)) return #Err(e); case (#Ok(l)) l };
    let committed = line != null and args.committed == ?true;
    switch (line) {
      case (?(n, b)) {
        let charged = if (committed) ({ b with committed = b.committed - args.amount : Nat }) else b;
        Map.add(budgets, Nat.compare, n, { charged with actual = b.actual + args.amount });
      };
      case null {};
    };
    let id = "T-" # Nat.toText(nextTransfer);
    nextTransfer += 1;
    let transfer : T.Transfer = {
      id;
      sender = { kind = "Fund"; id = args.fund };
      to = args.to;
      symbol = switch (args.symbol) { case (?s) s; case null REALM_TOKEN };
      amount = args.amount;
      ledger_tx = null;
      invoice = null;
      status = if (args.due_at == null) #Completed else #Scheduled;
      at = now();
      payroll = null;
      due_at = args.due_at;
      budget = switch (line) { case (?(_, b)) ?b.id; case null null };
      committed;
      contract = args.contract;
    };
    Map.add(transfers, Text.compare, id, transfer);
    audit("transfer_create", caller, #Map([("fund", #Text(args.fund)), ("amount", #Nat(args.amount))]), #Text(id));
    #Ok(?id);
  };

  /// Pays a scheduled transfer. Not governed: transfer_create decided it (I-FIN-10). This fixture moves
  /// no money, so it completes at once.
  public shared ({ caller }) func ggg_transfer_pay(id : Text) : async Result<T.Transfer> {
    switch (requireMember(caller, "transfer.create")) { case (?e) return #Err(e); case null {} };
    let ?transfer = Map.get(transfers, Text.compare, id) else return #Err(#NotFound);
    if (transfer.status != #Scheduled) return #Err(#Conflict("only a scheduled transfer is paid"));
    let paid = { transfer with status = #Completed };
    Map.add(transfers, Text.compare, id, paid);
    audit("transfer_pay", caller, #Map([("transfer", #Text(id))]), #Text(id));
    #Ok(paid);
  };

  /// Governed by the owner of the transfer's fund. Only a scheduled transfer can be reverted here, since
  /// this fixture moves no money and no transfer is ever pending (I-FIN-10).
  public shared ({ caller }) func ggg_transfer_revert(args : T.TransferRevertArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "transfer.delete")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_transfer_revert", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (checkRevert(args.transfer)) { case (#Err(e)) return #Err(e); case (#Ok(_)) {} };
    govern(caller, "transfer_revert", governing, arg, "Cancel transfer " # args.transfer, "Cancels the scheduled transfer " # args.transfer # ".", func() {
      cancelTransfer(caller, args.transfer);
    });
  };

  func checkRevert(id : Text) : Result<T.Transfer> {
    let ?transfer = Map.get(transfers, Text.compare, id) else return #Err(#NotFound);
    if (transfer.status != #Scheduled) return #Err(#Conflict("only a scheduled transfer can be reverted here"));
    #Ok(transfer);
  };

  /// Cancels a scheduled transfer and gives back what it charged, to the stage it came from, on the line
  /// that now stands for its fund, period and category (I-FIN-9).
  func cancelTransfer(caller : Principal, id : Text) : Result<?Text> {
    let transfer = switch (checkRevert(id)) { case (#Err(e)) return #Err(e); case (#Ok(t)) t };
    switch (standingLine(transfer.budget)) {
      case (?(n, b)) {
        let back = { b with actual = b.actual - transfer.amount : Nat };
        Map.add(budgets, Nat.compare, n, if (transfer.committed) ({ back with committed = b.committed + transfer.amount }) else back);
      };
      case null {};
    };
    Map.add(transfers, Text.compare, id, { transfer with status = #Cancelled });
    audit("transfer_revert", caller, #Map([("transfer", #Text(id))]), #Text(id));
    #Ok(null);
  };

  /// The adopted line of the same fund, period and category as the line `budget` names: that line, or the
  /// one that replaced it and carried its money.
  func standingLine(budget : ?Text) : ?(Nat, T.Budget) {
    let ?id = budget else return null;
    let ?(_, named) = Array.find<(Nat, T.Budget)>(Iter.toArray(Map.entries(budgets)), func((_, b)) { b.id == id }) else return null;
    Array.find<(Nat, T.Budget)>(linesOf(named.fund, named.period, [#Adopted]), func((_, b)) { b.category == named.category });
  };

  public query func ggg_transfer_list(args : T.TransferListArgs) : async Result<T.TransferPage> {
    let wanted = func(t : T.Transfer) : Bool {
      let fundMatches = switch (args.fund) { case (?f) t.sender.id == f; case null true };
      let statusMatches = switch (args.status) { case (?s) t.status == s; case null true };
      fundMatches and statusMatches;
    };
    page(Iter.filter<T.Transfer>(Map.values(transfers), wanted), args.cursor, args.limit);
  };

  // ---- Budget stages (I-FIN-9)

  /// Governed by the owner of the line's fund.
  public shared ({ caller }) func ggg_budget_stage(args : T.BudgetStageArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "org.manage_budget")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_budget_stage", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (staged(args)) { case (#Err(e)) return #Err(e); case (#Ok(_)) {} };
    govern(caller, "budget_stage", governing, arg, "Stage budget line " # args.budget, "Moves the reserved and committed money of budget line " # args.budget # ".", func() {
      stageBudget(caller, args);
    });
  };

  /// The line `args` names, with its reserved and committed money moved, or why they cannot move.
  func staged(args : T.BudgetStageArgs) : Result<(Nat, T.Budget)> {
    let ?(n, line) = Array.find<(Nat, T.Budget)>(Iter.toArray(Map.entries(budgets)), func((_, b)) { b.id == args.budget }) else return #Err(#NotFound);
    if (line.status != #Adopted or line.kind != #Expense) return #Err(#InvalidArgument(describe(line) # " is not an adopted expense line"));
    if (args.reserve == 0 and args.commit == 0) return #Err(#InvalidArgument("the stage moves no money"));
    let reserved = line.reserved + args.reserve;
    let committed = line.committed + args.commit;
    if (reserved < 0 or committed < 0) return #Err(#Conflict(describe(line) # " would hold less than nothing reserved or committed"));
    let holds = Int.abs(reserved) + Int.abs(committed) + line.actual;
    if (holds > line.planned) {
      return #Err(#Conflict(describe(line) # " plans " # Nat.toText(line.planned) # "; this stage would take it " # Nat.toText(holds - line.planned) # " above"));
    };
    #Ok((n, { line with reserved = Int.abs(reserved); committed = Int.abs(committed) }));
  };

  func stageBudget(caller : Principal, args : T.BudgetStageArgs) : Result<?Text> {
    let (n, line) = switch (staged(args)) { case (#Err(e)) return #Err(e); case (#Ok(found)) found };
    Map.add(budgets, Nat.compare, n, line);
    audit("budget_stage", caller, #Map([("budget", #Text(line.id))]), #Text(line.id));
    #Ok(null);
  };

  public query func ggg_budget_list(args : T.BudgetListArgs) : async Result<T.BudgetPage> {
    let wanted = func(b : T.Budget) : Bool {
      let fundMatches = switch (args.fund) { case (?f) b.fund == f; case null true };
      let periodMatches = switch (args.period) { case (?p) b.period == p; case null true };
      fundMatches and periodMatches;
    };
    page(Iter.filter<T.Budget>(Map.values(budgets), wanted), args.cursor, args.limit);
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

  // ---- Organizations (I-ORG-9). They seat no representatives here.
  let organizations = Map.empty<Text, T.Organization>();

  public query func ggg_organization_get(args : T.GetArgs) : async Result<?T.OrganizationDetail> {
    let ?organization = Map.get(organizations, Text.compare, args.id) else return #Ok(null);
    switch (none<T.Seat>(args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ organization; seats = items; next });
    };
  };

  /// The organizations with the status and the kind named, if they are.
  public query func ggg_organization_list(args : T.OrganizationListArgs) : async Result<T.OrganizationPage> {
    let wanted = func(o : T.Organization) : Bool {
      let statusMatches = switch (args.status) { case (?s) o.status == s; case null true };
      let kindMatches = switch (args.kind) { case (?k) o.kind == k; case null true };
      statusMatches and kindMatches;
    };
    page(Iter.filter<T.Organization>(Map.values(organizations), wanted), args.cursor, args.limit);
  };

  /// The member who registers an organization becomes its admin; it is Other unless a kind is given.
  public shared ({ caller }) func ggg_organization_register(args : T.OrganizationRegisterArgs) : async Result<T.Organization> {
    switch (requireMember(caller, "organization.add")) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.organization) == 0) return #Err(#InvalidArgument("the organization's name is empty"));
    if (Map.containsKey(organizations, Text.compare, args.organization)) return #Err(#Conflict("the organization is already registered"));
    let organization : T.Organization = {
      id = args.organization;
      description = args.description;
      status = #Active;
      admins = [caller];
      kind = switch (args.kind) { case (?k) k; case null #Other };
    };
    Map.add(organizations, Text.compare, organization.id, organization);
    audit("organization_register", caller, #Map([("organization", #Text(organization.id))]), #Text(organization.id));
    #Ok(organization);
  };

  /// Only an active organization's admins edit it (I-ORG-8).
  public shared ({ caller }) func ggg_organization_edit(args : T.OrganizationEditArgs) : async Result<T.Organization> {
    switch (requireMember(caller, "organization.edit")) { case (?e) return #Err(e); case null {} };
    let ?organization = Map.get(organizations, Text.compare, args.organization) else return #Err(#NotFound);
    if (not Array.any<Principal>(organization.admins, func(a) { a == caller })) {
      return #Err(#Forbidden({ permission = ?"organization.edit"; message = "Only the organization's admins may edit it." }));
    };
    if (organization.status != #Active) return #Err(#Conflict("nobody acts for a suspended or dissolved organization"));
    let edited = {
      organization with
      description = switch (args.description) { case (?d) d; case null organization.description };
      admins = switch (args.admins) { case (?a) a; case null organization.admins };
      kind = switch (args.kind) { case (?k) k; case null organization.kind };
    };
    Map.add(organizations, Text.compare, edited.id, edited);
    audit("organization_edit", caller, #Map([("organization", #Text(edited.id))]), #Text(edited.id));
    #Ok(edited);
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

  /// The proposals with the status named, if one is, and at least one of the tags named, if any are.
  public query func ggg_proposal_list(args : T.ProposalListArgs) : async Result<T.ProposalPage> {
    let tags = switch (args.tags) { case (?t) t; case null [] };
    if (tags.size() > MAX_TAGS) return #Err(#InvalidArgument("a list filters by at most 16 tags"));
    // No tag longer than a tag can be has been set (I-GOV-15), so none could match.
    for (t in tags.vals()) {
      if (Text.size(t) > MAX_TAG_SIZE) return #Err(#InvalidArgument("a tag to list by is at most 64 code points"));
    };
    let wanted = func(p : T.Proposal) : Bool {
      let statusMatches = switch (args.status) { case (?s) p.status == s; case null true };
      let tagged = tags.size() == 0 or Array.any<Text>(p.tags, func(t) { Array.any<Text>(tags, func(w) { w == t }) });
      statusMatches and tagged;
    };
    page(Iter.filter<T.Proposal>(Map.values(proposals), wanted), args.cursor, args.limit);
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
    let tags = switch (args.tags) { case (?t) t; case null [] };
    switch (checkTags(tags)) { case (?e) return #Err(e); case null {} };
    switch (args.effective_at) {
      case (?e) { if (e <= now()) return #Err(#InvalidArgument("effective_at must lie in the future")) };
      case null {};
    };
    let rule = switch (statedRule(args)) { case (#Err(e)) return #Err(e); case (#Ok(r)) r };
    let p = fileProposal(caller, args.title, args.description, args.department, args.kind, args.matter, args.action, rule, args.effective_at, links, tags);
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
    tags : [Text],
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
      prepared_by = null;
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
      tags;
      majority_of_cast = ?rule.majority_of_cast;
      first_vote = null;
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

  /// Only a draft's tags can be replaced (I-GOV-15), and proposals here are filed already open.
  public shared ({ caller }) func ggg_proposal_set_tags(args : T.ProposalSetTagsArgs) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.create")) { case (?e) return #Err(e); case null {} };
    if (args.on_behalf_of != null) return #Err(noDelegation("proposal.create"));
    let (_, p) = switch (findProposal(args.proposal)) { case null return #Err(#NotFound); case (?found) found };
    if (filedFor(p) != caller) {
      return #Err(#Forbidden({ permission = ?"proposal.create"; message = "Only the member a proposal was filed for may tag it." }));
    };
    #Err(#Conflict("only a draft's tags can be replaced"));
  };

  /// Proposals here are filed already open, so there is never a draft to open.
  public shared ({ caller }) func ggg_proposal_open(id : Text) : async Result<T.Proposal> {
    switch (requireMember(caller, "proposal.manage")) { case (?e) return #Err(e); case null {} };
    switch (findProposal(id)) {
      case null #Err(#NotFound);
      case (?_) #Err(#Conflict("only a draft can be opened"));
    };
  };

  /// Where the yes votes stand against a proposal's threshold (I-GOV-3). They reach a department's
  /// threshold of its policy's n, and exceed a realm-wide threshold of the eligible voters; over the
  /// votes cast, standing exactly at the threshold is a tie. Under a department's majority of the votes
  /// cast, a threshold of n reached is not enough: the votes cast still decide, at a majority.
  type Standing = { #Above; #Tie; #Below };

  func standing(p : T.Proposal) : Standing {
    let { yes; no; eligible; seats } = p.tally;
    switch (p.threshold_of, seats) {
      case (#Cast, _) overCast(yes, no, p.threshold);
      case (#Eligible, ?n) {
        if (yes * WHOLE < p.threshold * n) return #Below;
        if (p.majority_of_cast == ?true) overCast(yes, no, WHOLE / 2) else #Above;
      };
      case (#Eligible, null) {
        let all = switch (eligible) { case (?e) e; case null yes + no };
        if (yes * WHOLE > p.threshold * all) #Above else #Below;
      };
    };
  };

  func overCast(yes : Nat, no : Nat, threshold : T.Ratio) : Standing {
    // Abstentions alone are no tie: a tie needs a yes or a no (I-GOV-3).
    if (yes + no == 0) return #Below;
    let share = yes * WHOLE;
    let needed = threshold * (yes + no);
    if (share > needed) #Above else if (share == needed) #Tie else #Below;
  };

  /// Whether enough members voted, abstentions included. A department that counts the votes cast
  /// measures its quorum against its policy's n, so that a vacancy never lowers it; any other proposal
  /// against its eligible voters.
  func quorumMet(p : T.Proposal) : Bool {
    let { yes; no; abstain; eligible; seats } = p.tally;
    let size = if (p.majority_of_cast == ?true) seats else eligible;
    switch (size) { case (?m) (yes + no + abstain) * WHOLE >= p.quorum * m; case null true };
  };

  /// Whether the casting member voted yes. A tie is theirs to decide; absent, or voting otherwise, it rejects.
  func castingYes(n : Nat, p : T.Proposal) : Bool {
    let ?caster = p.casting_vote else return false;
    switch (Map.get(ballots(n), Principal.compare, caster)) {
      case (?v) v.choice == #Yes;
      case null false;
    };
  };

  func endedLate(p : T.Proposal, ended : T.Timestamp) : Bool {
    switch (p.effective_at) { case (?e) ended > e; case null false };
  };

  /// Whether a vote that ended in time gets a second vote: a department's first vote over the votes cast
  /// that met its quorum and tied (I-GOV-14).
  func tiedFirstVote(p : T.Proposal, ended : T.Timestamp) : Bool {
    p.majority_of_cast == ?true and p.first_vote == null and not endedLate(p, ended) and quorumMet(p) and standing(p) == #Tie;
  };

  /// The proposal's second vote, opened at `t` (I-GOV-14): the same rule and voters, the first vote's
  /// count kept, the ballots empty, and a window as long as the first one's.
  func secondVote(n : Nat, p : T.Proposal, t : T.Timestamp) : T.Proposal {
    Map.remove(votes, Nat.compare, n);
    Map.remove(everyoneVotedAt, Nat.compare, n);
    let deadline = switch (p.opens_at, p.deadline) { case (?opened, ?d) ?(t + (d - opened)); case _ null };
    { p with opens_at = ?t; deadline; first_vote = ?p.tally; tally = { p.tally with yes = 0; no = 0; abstain = 0 } };
  };

  /// How a vote that ended at `ended` and is finalized at `t` turns out. A vote that ended after
  /// `effective_at` expires the proposal, whatever was decided. Otherwise quorum and threshold decide,
  /// a tie by the casting vote, and an accepted proposal with an action whose `effective_at` is still
  /// ahead is scheduled. A motion has nothing to execute, so it stays accepted; so does an action whose
  /// `effective_at` has passed by the time the vote is finalized, which then executes at once.
  func outcome(n : Nat, p : T.Proposal, ended : T.Timestamp, t : T.Timestamp) : T.ProposalStatus {
    if (endedLate(p, ended)) return #Expired;
    let carried = switch (standing(p)) { case (#Above) true; case (#Tie) castingYes(n, p); case (#Below) false };
    if (not (quorumMet(p) and carried)) return #Rejected;
    switch (p.action, p.effective_at) {
      case (#Motion, _) #Accepted;
      case (_, ?e) { if (e > t) #ExecutionScheduled else #Accepted };
      case (_, null) #Accepted;
    };
  };

  /// Records the outcome of a vote that has ended, or opens the second vote when a first one tied.
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
    let tied = tiedFirstVote(p, ended);
    let finalized = if (tied) secondVote(n, p, t) else ({ p with status = outcome(n, p, ended, t) });
    Map.add(proposals, Nat.compare, n, finalized);
    settled(finalized);
    let recorded = if (tied) "second vote" else debug_show (finalized.status);
    audit("proposal_finalize", caller, #Map([("proposal", #Text(p.id))]), #Text(recorded));
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
  /// ggg_fund_create, ggg_budget_draft, ggg_budget_propose, ggg_transfer_create, ggg_codex_install,
  /// which may await another realm, and ggg_codex_revert.
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
      case "ggg_contract_amend" {
        let ?args : ?T.ContractAmendArgs = from_candid (arg) else return undecodable();
        amendContract(caller, args, ?p.id);
      };
      case "ggg_budget_stage" {
        let ?args : ?T.BudgetStageArgs = from_candid (arg) else return undecodable();
        stageBudget(caller, args);
      };
      case "ggg_transfer_revert" {
        let ?args : ?T.TransferRevertArgs = from_candid (arg) else return undecodable();
        cancelTransfer(caller, args.transfer);
      };
      case "ggg_sweep_resolve" {
        let ?args : ?T.SweepResolveArgs = from_candid (arg) else return undecodable();
        resolveSweep(caller, args);
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
        let (?{ codex = ?_ }) = args else return (#Failed, ?#Error(REVERT_NAMES_CODEX));
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

  // ---- Contracts (I-GOV-16). No mandate or tender exists here, so the root owns every contract.
  let MAX_SPLIT = 64; // the fiscal periods a contract's value is spread over
  let contracts = Map.empty<Text, T.Contract>();
  let amendments = Map.empty<Text, List.List<T.ContractAmendment>>(); // by contract, oldest first
  var nextContract = 1;

  func termsOf(c : T.Contract) : T.ContractTerms = { value = c.value; split = c.split; starts_at = c.starts_at; ends_at = c.ends_at };

  func ended(c : T.Contract) : Bool = c.status == #Terminated or c.status == #Fulfilled;

  /// Refuses terms that break I-GOV-16: a split over more than 64 periods, naming one twice or none,
  /// or not adding up to the value; or a start after the end.
  func checkTerms(t : T.ContractTerms) : ?T.GggError {
    if (t.split.size() > MAX_SPLIT) return ?#InvalidArgument("a contract is spread over at most 64 periods");
    let named = Map.empty<Text, ()>();
    var total = 0;
    for ({ period; amount } in t.split.vals()) {
      if (Text.size(period) == 0) return ?#InvalidArgument("a period of the split is not named");
      if (Map.containsKey(named, Text.compare, period)) return ?#InvalidArgument("the split names " # period # " twice");
      Map.add(named, Text.compare, period, ());
      total += amount;
    };
    if (t.split.size() > 0 and total != t.value) {
      return ?#InvalidArgument("the split adds up to " # Nat.toText(total) # ", not the value " # Nat.toText(t.value));
    };
    switch (t.starts_at, t.ends_at) {
      case (?start, ?end) { if (start > end) return ?#InvalidArgument("starts_at is after ends_at") };
      case _ {};
    };
    null;
  };

  let MAX_FRAMEWORK_REFERENCE = 128; // code points
  let MAX_FRAMEWORK_WINNERS = 32;

  /// The framework a contract is a call-off under: a reference and winners of the right size, a holder this
  /// realm knows, and, when winners are listed, one of them among the contract's parties (I-PRC-6). No
  /// External exists here, so an External holder is never known.
  func checkFramework(args : T.ContractCreateArgs) : ?T.GggError {
    let ?framework = args.framework else return null;
    let size = Text.size(framework.reference);
    if (size == 0 or size > MAX_FRAMEWORK_REFERENCE) return ?#InvalidArgument("a framework's reference is 1 to 128 code points");
    if (framework.winners.size() > MAX_FRAMEWORK_WINNERS) return ?#InvalidArgument("a framework lists at most 32 winners");
    switch (framework.holder) {
      case (#External(_)) return ?#NotFound;
      case (#Realm(realm)) { if (realm == me()) return ?#InvalidArgument("a tender of this realm is named by the contract's tender") };
    };
    if (framework.winners.size() == 0) return null;
    let isWinner = func(party : T.Ref) : Bool = party.kind == "Organization" and Array.any<Text>(framework.winners, func(w) { w == party.id });
    if (Array.any<T.Ref>(args.parties, isWinner)) null else ?#InvalidArgument("none of the contract's parties is a winner of its framework");
  };

  public shared ({ caller }) func ggg_contract_create(args : T.ContractCreateArgs) : async Result<T.Contract> {
    switch (requireMember(caller, "contract.create_under_mandate")) { case (?e) return #Err(e); case null {} };
    if (args.mandate != null or args.tender != null) return #Err(#NotFound);
    if (args.lot != null) return #Err(#InvalidArgument("a lot is named only with the tender it belongs to"));
    switch (checkFramework(args)) { case (?e) return #Err(e); case null {} };
    if (Text.size(args.title) == 0) return #Err(#InvalidArgument("title is empty"));
    let split = switch (args.split) { case (?s) s; case null [] };
    switch (checkTerms({ value = args.value; split; starts_at = args.starts_at; ends_at = args.ends_at })) {
      case (?e) return #Err(e);
      case null {};
    };
    let contract : T.Contract = { args with id = Nat.toText(nextContract); status = #Active; split };
    nextContract += 1;
    Map.add(contracts, Text.compare, contract.id, contract);
    audit("contract_create", caller, #Map([("contract", #Text(contract.id))]), #Text(contract.id));
    #Ok(contract);
  };

  public shared ({ caller }) func ggg_contract_terminate(id : Text) : async Result<T.Contract> {
    switch (requireMember(caller, "contract.terminate")) { case (?e) return #Err(e); case null {} };
    let ?contract = Map.get(contracts, Text.compare, id) else return #Err(#NotFound);
    if (ended(contract)) return #Err(#Conflict("the contract has already ended"));
    let terminated = { contract with status = #Terminated };
    Map.add(contracts, Text.compare, id, terminated);
    audit("contract_terminate", caller, #Map([("contract", #Text(id))]), #Text(id));
    #Ok(terminated);
  };

  /// Governed by the contract's owner, the root here, whose direct policy applies it at once.
  public shared ({ caller }) func ggg_contract_amend(args : T.ContractAmendArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "contract.amend")) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_contract_amend", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    switch (amendedTerms(args)) { case (#Err(e)) return #Err(e); case (#Ok(_)) {} };
    let title = "Amend contract " # args.contract;
    govern(caller, "contract_amend", governing, arg, title, "Changes the value, split or dates of contract " # args.contract # ".", func() {
      amendContract(caller, args, null);
    });
  };

  /// The contract `args` amends and its terms after the amendment, or why it cannot be amended.
  func amendedTerms(args : T.ContractAmendArgs) : Result<(T.Contract, T.ContractTerms)> {
    let ?contract = Map.get(contracts, Text.compare, args.contract) else return #Err(#NotFound);
    if (ended(contract)) return #Err(#Conflict("a terminated or fulfilled contract is not amended"));
    let before = termsOf(contract);
    let after : T.ContractTerms = {
      value = switch (args.value) { case (?v) v; case null before.value };
      split = switch (args.split) { case (?s) s; case null before.split };
      starts_at = switch (args.starts_at) { case (?t) ?t; case null before.starts_at };
      ends_at = switch (args.ends_at) { case (?t) ?t; case null before.ends_at };
    };
    if (after == before) return #Err(#InvalidArgument("the amendment changes no term"));
    switch (checkTerms(after)) { case (?e) return #Err(e); case null {} };
    let paid = paidOn(contract.id);
    if (after.value < paid) return #Err(#Conflict("a value of " # Nat.toText(after.value) # " is below the " # Nat.toText(paid) # " paid on the contract"));
    #Ok((contract, after));
  };

  /// Applies an amendment and records it with the proposal that carried it, if any (I-GOV-16).
  func amendContract(caller : Principal, args : T.ContractAmendArgs, proposal : ?Text) : Result<?Text> {
    let (contract, after) = switch (amendedTerms(args)) { case (#Err(e)) return #Err(e); case (#Ok(found)) found };
    let history = switch (Map.get(amendments, Text.compare, contract.id)) {
      case (?h) h;
      case null { let h = List.empty<T.ContractAmendment>(); Map.add(amendments, Text.compare, contract.id, h); h };
    };
    let amendment : T.ContractAmendment = {
      id = contract.id # "." # Nat.toText(List.size(history) + 1);
      contract = contract.id;
      before = termsOf(contract);
      after;
      proposal;
      at = now();
    };
    List.add(history, amendment);
    let amendedContract = { contract with value = after.value; split = after.split; starts_at = after.starts_at; ends_at = after.ends_at };
    Map.add(contracts, Text.compare, contract.id, amendedContract);
    audit("contract_amend", caller, #Map([("contract", #Text(contract.id))]), #Text(amendment.id));
    #Ok(?amendment.id);
  };

  public query func ggg_contract_get(args : T.GetArgs) : async Result<?T.ContractDetail> {
    let ?contract = Map.get(contracts, Text.compare, args.id) else return #Ok(null);
    let history = switch (Map.get(amendments, Text.compare, contract.id)) { case (?h) List.values(h); case null Iter.empty() };
    switch (page(history, args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok(?{ contract; amendments = items; next });
    };
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
      case (#Ok({ items; next })) {
        let configured = Option.map<T.TreasuryConfig, T.Treasury>(treasuryConfig, func(config) { { id = "1"; config; debt_outstanding = 0 } });
        #Ok({ treasury = configured; tokens = Iter.toArray(Map.values(tokens)); nft_tokens = []; funds = items; next });
      };
    };
  };

  /// The entries this realm books: those of sweeps (I-FED-7).
  public query func ggg_ledger_view(args : T.LedgerArgs) : async Result<T.LedgerPage> {
    let wanted = func(e : T.LedgerEntry) : Bool {
      (args.transaction == null or args.transaction == ?e.transaction) and (args.symbol == null or args.symbol == ?e.symbol) and (args.kind == null or args.kind == ?e.kind) and (args.fund == null or args.fund == e.fund) and (args.period == null or args.period == e.period);
    };
    page(Iter.filter<T.LedgerEntry>(List.values(ledgerEntries), wanted), args.cursor, args.limit);
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
    let capital = if (isCapital()) ?Principal.toText(me()) else Option.map<Principal, Text>(myCapital, Principal.toText);
    switch (page(Map.values(quarters), args.cursor, args.limit)) {
      case (#Err(e)) #Err(e);
      case (#Ok({ items; next })) #Ok({ capital; items; next; zones = null; sweep = null });
    };
  };

  public query func ggg_join_targets(_ : ?T.JoinTargetsArgs) : async Result<T.JoinTargets> {
    #Ok({ default = null; targets = []; mode = null });
  };

  // ---- Treasury, quarters and sweeps (model §5, §10, I-FED-5 to 7). This realm is a capital once it
  // registers a quarter, and a quarter once it joins a capital. Its money in a token is what its own
  // account holds on the token's ledger: it keeps no running balance per fund, so a sweep rule's fund
  // holds all of it. It sweeps only when quarter_sweep asks, after asking its capital for the rules.

  let tokens = Map.empty<Text, T.Token>();
  var treasuryConfig : ?T.TreasuryConfig = null;
  let quarters = Map.empty<Text, T.Quarter>();
  var myCapital : ?Principal = null;
  // The sweep rules quarter_sync last returned, on a quarter.
  var sweepConfig : ?T.SweepConfig = null;
  // This quarter's sweeps by id; on a capital, each quarter's as `<quarter>/<id>`.
  let sweeps = Map.empty<Text, T.Sweep>();
  var nextSweep = 1;
  let ledgerEntries = List.empty<T.LedgerEntry>();
  var nextTransaction = 1;
  let DAY : T.Timestamp = 24 * 3600 * 1_000_000_000;
  // A sweep is sent again only this long after it was recorded: an hour inside the 24-hour window in
  // which an ICRC-1 ledger recognises a repeat (I-FED-6).
  let RESEND_LIMIT : T.Timestamp = 23 * 3600 * 1_000_000_000;
  let DEFAULT_TREASURY : T.TreasuryConfig = { epoch = DAY; anchor_month = 1; source_fund = ""; auto_allocate = false; sweep = [] };

  type Ledger = actor {
    icrc1_balance_of : shared query T.Account -> async Nat;
    icrc1_transfer : shared TransferArg -> async { #Ok : Nat; #Err : TransferError };
  };
  type TransferArg = { from_subaccount : ?Blob; to : T.Account; amount : Nat; fee : ?Nat; memo : ?Blob; created_at_time : ?Nat64 };
  type TransferError = {
    #BadFee : { expected_fee : Nat };
    #BadBurn : { min_burn_amount : Nat };
    #InsufficientFunds : { balance : Nat };
    #TooOld;
    #CreatedInFuture : { ledger_time : Nat64 };
    #Duplicate : { duplicate_of : Nat };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };
  /// What a quarter calls on its capital.
  type Capital = actor {
    ggg_quarter_sync : shared () -> async Result<T.QuarterDirectory>;
    ggg_quarter_sweep_report : shared T.Sweep -> async Result<T.Sweep>;
  };
  func ledgerOf(token : T.Token) : Ledger = actor (Principal.toText(token.ledger));
  func capitalAt(p : Principal) : Capital = actor (Principal.toText(p));

  func isCapital() : Bool = Map.size(quarters) > 0;
  func treasury() : T.TreasuryConfig = switch (treasuryConfig) { case (?c) c; case null DEFAULT_TREASURY };
  func epochOf(t : T.Timestamp) : T.Timestamp { let e = treasury().epoch; if (e == 0) t else t - t % e };

  /// Governed by the root, whose direct policy applies it at once. Only a capital sets sweep rules.
  public shared ({ caller }) func ggg_treasury_configure(args : T.TreasuryConfigureArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "treasury.manage")) { case (?e) return #Err(e); case null {} };
    switch (checkSweepRules(args.sweep)) { case (?e) return #Err(e); case null {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_treasury_configure", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "treasury_configure", governing, arg, "Configure the treasury", "Changes the treasury's configuration.", func() {
      let c = treasury();
      treasuryConfig := ?{
        epoch = Option.get(args.epoch, c.epoch);
        anchor_month = Option.get(args.anchor_month, c.anchor_month);
        source_fund = Option.get(args.source_fund, c.source_fund);
        auto_allocate = Option.get(args.auto_allocate, c.auto_allocate);
        sweep = Option.get(args.sweep, c.sweep);
      };
      audit("treasury_configure", caller, #Map([]), #Text("ok"));
      #Ok(null);
    });
  };

  /// Sweep rules name a fund of this capital and a token it registered, one rule per quarter fund and token.
  func checkSweepRules(rules : ?[T.SweepRule]) : ?T.GggError {
    let ?all = rules else return null;
    if (not isCapital()) return ?#InvalidArgument("only a capital sets sweep rules");
    let named = Map.empty<Text, ()>();
    for (rule in all.vals()) {
      if (not Map.containsKey(funds, Text.compare, rule.into) or not Map.containsKey(tokens, Text.compare, rule.symbol)) return ?#NotFound;
      let key = rule.fund # " in " # rule.symbol;
      if (Map.containsKey(named, Text.compare, key)) return ?#InvalidArgument("two sweep rules for " # key);
      Map.add(named, Text.compare, key, ());
    };
    null;
  };

  /// Governed by the root, whose direct policy applies it at once.
  public shared ({ caller }) func ggg_token_register(args : T.TokenRegisterArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "treasury.manage")) { case (?e) return #Err(e); case null {} };
    if (Map.containsKey(tokens, Text.compare, args.symbol)) return #Err(#Conflict("the token " # args.symbol # " is registered"));
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_token_register", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "token_register", governing, arg, "Register " # args.symbol, "Registers the token " # args.symbol # ".", func() {
      let token = { id = args.symbol; ledger = args.ledger; indexer = args.indexer; decimals = Option.get(args.decimals, 8 : Nat8); fee = Option.get(args.fee, 0) };
      Map.add(tokens, Text.compare, args.symbol, token);
      audit("token_register", caller, #Map([("symbol", #Text(args.symbol))]), #Text(args.symbol));
      #Ok(?args.symbol);
    });
  };

  /// Governed by the root, whose direct policy applies it at once. A quarter registers no quarters.
  public shared ({ caller }) func ggg_quarter_register(args : T.QuarterRegisterArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "quarter.register")) { case (?e) return #Err(e); case null {} };
    let id = Principal.toText(args.canister);
    if (myCapital != null) return #Err(#Conflict("a quarter registers no quarters"));
    if (Map.containsKey(quarters, Text.compare, id)) return #Err(#Conflict("the quarter " # id # " is registered"));
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_quarter_register", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "quarter_register", governing, arg, "Register quarter " # id, "Registers the quarter " # id # ".", func() {
      let quarter : T.Quarter = {
        id;
        name = Option.get(args.name, id);
        index = Map.size(quarters);
        status = #Active;
        population = 0;
        codex_id = null;
        codex_version = null;
        compliance = #Unknown;
        last_sync = null;
        last_activity_at = null;
      };
      Map.add(quarters, Text.compare, id, quarter);
      audit("quarter_register", caller, #Map([("quarter", #Text(id))]), #Text(id));
      #Ok(?id);
    });
  };

  /// Governed by the root, whose direct policy applies it at once.
  public shared ({ caller }) func ggg_quarter_join_federation(args : T.JoinFederationArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "quarter.join_federation")) { case (?e) return #Err(e); case null {} };
    if (myCapital != null or isCapital()) return #Err(#Conflict("this realm is in a federation already"));
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_quarter_join_federation", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "quarter_join_federation", governing, arg, "Join a federation", "Joins the federation of " # Principal.toText(args.capital) # ".", func() {
      myCapital := ?args.capital;
      audit("quarter_join_federation", caller, #Map([("capital", #Text(Principal.toText(args.capital)))]), #Text("ok"));
      #Ok(null);
    });
  };

  func callingQuarter(caller : Principal) : ?T.Quarter = Map.get(quarters, Text.compare, Principal.toText(caller));

  func notAQuarter(caller : Principal) : T.GggError {
    if (Principal.isAnonymous(caller)) #Unauthenticated else #Forbidden({ permission = ?"quarter.sync"; message = "Only a registered quarter calls this." });
  };

  /// From a registered quarter (I-FED-4): the directory, no zones, and the sweep rules with the account
  /// that receives sweeps.
  public shared ({ caller }) func ggg_quarter_sync() : async Result<T.QuarterDirectory> {
    let ?quarter = callingQuarter(caller) else return #Err(notAQuarter(caller));
    Map.add(quarters, Text.compare, quarter.id, { quarter with last_sync = ?now() });
    #Ok({
      capital = ?Principal.toText(me());
      items = Iter.toArray(Map.values(quarters));
      next = null;
      zones = ?[];
      sweep = ?{ to = { owner = me(); subaccount = null }; rules = treasury().sweep };
    });
  };

  /// Sweeps now (I-FED-5). It asks the capital for the rules first, and keeps the last ones it had when
  /// the capital does not answer; then, rule by rule, it reports the sweeps the capital has not booked,
  /// sends again a sweep whose outcome is unknown, or records and sends this epoch's.
  public shared ({ caller }) func ggg_quarter_sweep(args : T.QuarterSweepArgs) : async Result<[T.Sweep]> {
    switch (requireMember(caller, "treasury.manage")) { case (?e) return #Err(e); case null {} };
    let ?capital = myCapital else return #Err(#Conflict("only a quarter sweeps"));
    let synced = try { ?(await (with timeout = CALL_TIMEOUT) capitalAt(capital).ggg_quarter_sync()) } catch (_) { null };
    switch (synced) { case (?#Ok({ sweep = ?config })) sweepConfig := ?config; case _ {} };
    let ?config = sweepConfig else return #Ok([]);
    let touched = List.empty<T.Sweep>();
    for (rule in config.rules.vals()) {
      if (args.fund == null or args.fund == ?rule.fund) {
        List.addAll(touched, (await* sweepRule(capital, config.to, rule)).vals());
      };
    };
    audit("quarter_sweep", caller, #Map([]), #Nat(List.size(touched)));
    #Ok(List.toArray(touched));
  };

  func ofRule(s : T.Sweep, rule : T.SweepRule) : Bool = s.quarter == Principal.toText(me()) and s.fund == rule.fund and s.symbol == rule.symbol;

  func sweepsOf(rule : T.SweepRule, wanted : T.Sweep -> Bool) : [T.Sweep] {
    Iter.toArray(Iter.filter<T.Sweep>(Map.values(sweeps), func(s) { ofRule(s, rule) and wanted(s) }));
  };

  /// A sweep that stops the rule's next one: its outcome unknown, or waiting for a person (I-FED-5).
  func blocking(s : T.Sweep) : Bool = s.status == #Sending or s.status == #NeedsCheck;

  func sweepRule(capital : Principal, to : T.Account, rule : T.SweepRule) : async* [T.Sweep] {
    let touched = List.empty<T.Sweep>();
    for (sent in sweepsOf(rule, func(s) { s.status == #Sent }).vals()) List.add(touched, await* report(capital, sent));
    let open = sweepsOf(rule, blocking);
    if (open.size() > 0) {
      List.add(touched, await* attempt(capital, open[0]));
      return List.toArray(touched);
    };
    switch (await* newSweep(to, rule)) {
      case (?recorded) List.add(touched, await* attempt(capital, recorded));
      case null {};
    };
    List.toArray(touched);
  };

  /// This epoch's sweep of the rule, recorded before any money moves: the fund's money less what it keeps
  /// and the fee, when that is more than nothing.
  func newSweep(to : T.Account, rule : T.SweepRule) : async* ?T.Sweep {
    let epoch = epochOf(now());
    let sweptAlready = func() : Bool { sweepsOf(rule, func(s) { s.epoch == epoch or blocking(s) }).size() > 0 };
    if (sweptAlready() or not Map.containsKey(funds, Text.compare, rule.fund)) return null;
    let ?token = Map.get(tokens, Text.compare, rule.symbol) else return null;
    let held = try { await (with timeout = CALL_TIMEOUT) ledgerOf(token).icrc1_balance_of({ owner = me(); subaccount = null }) } catch (_) { return null };
    // Another call may have recorded this epoch's sweep while the balance was read.
    if (sweptAlready() or held <= rule.keep + token.fee) return null;
    let id = "SW-" # Nat.toText(nextSweep);
    nextSweep += 1;
    let sweep : T.Sweep = {
      id;
      quarter = Principal.toText(me());
      fund = rule.fund;
      symbol = rule.symbol;
      into = rule.into;
      to;
      epoch;
      amount = held - rule.keep - token.fee : Nat;
      fee = token.fee;
      created_at = now();
      block = null;
      status = #Sending;
      reason = null;
      reported_at = null;
    };
    ?store(sweep);
  };

  func store(s : T.Sweep) : T.Sweep {
    Map.add(sweeps, Text.compare, s.id, s);
    s;
  };

  /// The sweep as it stands now: a call that awaited may find it moved on by another.
  func latest(s : T.Sweep) : T.Sweep = switch (Map.get(sweeps, Text.compare, s.id)) { case (?now) now; case null s };

  /// Sends a Sending sweep's transfer, the same one every time (I-FED-5), and only until RESEND_LIMIT
  /// after it was recorded (I-FED-6); a sweep the ledger gave a block is booked and reported.
  func attempt(capital : Principal, s : T.Sweep) : async* T.Sweep {
    if (s.status != #Sending) return s;
    if (now() >= s.created_at + RESEND_LIMIT) return store({ s with status = #NeedsCheck });
    let ?token = Map.get(tokens, Text.compare, s.symbol) else return s;
    let transfer = { from_subaccount = null; to = s.to; amount = s.amount; fee = ?s.fee; memo = ?Text.encodeUtf8(s.id); created_at_time = ?s.created_at };
    let answer = try { ?(await (with timeout = CALL_TIMEOUT) ledgerOf(token).icrc1_transfer(transfer)) } catch (_) { null };
    let current = latest(s);
    if (current.status != #Sending) return current;
    switch (answer) {
      case null current; // the outcome is unknown: the same transfer is sent again at the next sweep
      case (?#Ok(block)) await* sent(capital, current, block);
      case (?#Err(#Duplicate({ duplicate_of }))) await* sent(capital, current, duplicate_of);
      case (?#Err(#TooOld)) store({ current with status = #NeedsCheck });
      case (?#Err(e)) store({ current with status = #Failed; reason = ?debug_show (e) });
    };
  };

  func sent(capital : Principal, s : T.Sweep, block : Nat) : async* T.Sweep {
    let recorded = store({ s with status = #Sent; block = ?block });
    bookSweepOut(recorded);
    await* report(capital, recorded);
  };

  /// Tells the capital about a Sent sweep; it is Booked once the capital answers that it booked it.
  func report(capital : Principal, s : T.Sweep) : async* T.Sweep {
    let answer = try { ?(await (with timeout = CALL_TIMEOUT) capitalAt(capital).ggg_quarter_sweep_report(s)) } catch (_) { null };
    let current = latest(s);
    switch (answer) {
      case (?#Ok(_)) { if (current.status == #Sent) store({ current with status = #Booked; reported_at = ?now() }) else current };
      case _ current;
    };
  };

  /// From a registered quarter: books a Sent sweep into its `into` fund, once (I-FED-7).
  public shared ({ caller }) func ggg_quarter_sweep_report(s : T.Sweep) : async Result<T.Sweep> {
    let ?quarter = callingQuarter(caller) else return #Err(notAQuarter(caller));
    if (s.status != #Sent or s.block == null) return #Err(#InvalidArgument("only a sent sweep, with its block, is reported"));
    let booked = { s with id = quarter.id # "/" # s.id; quarter = quarter.id; status = #Booked; reported_at = ?now() };
    switch (Map.get(sweeps, Text.compare, booked.id)) {
      case (?earlier) {
        if (sameMove(earlier, booked)) return #Ok(earlier);
        return #Err(#Conflict("the sweep " # booked.id # " was booked with other figures"));
      };
      case null {};
    };
    if (not Map.containsKey(funds, Text.compare, s.into)) return #Err(#NotFound);
    ignore store(booked);
    bookSweepIn(booked);
    audit("quarter_sweep_report", caller, #Map([("sweep", #Text(booked.id))]), #Text(booked.id));
    #Ok(booked);
  };

  func sameMove(a : T.Sweep, b : T.Sweep) : Bool {
    a.fund == b.fund and a.symbol == b.symbol and a.into == b.into and a.to == b.to and a.epoch == b.epoch and a.amount == b.amount and a.fee == b.fee and a.created_at == b.created_at and a.block == b.block;
  };

  /// Governed by the owner of the swept fund. Settles a NeedsCheck sweep from what the ledger shows (I-FED-6).
  public shared ({ caller }) func ggg_sweep_resolve(args : T.SweepResolveArgs) : async Result<T.Governed> {
    switch (requireMember(caller, "treasury.manage")) { case (?e) return #Err(e); case null {} };
    switch (needingCheck(args.sweep)) { case (#Err(e)) return #Err(e); case (#Ok(_)) {} };
    let arg = to_candid (args);
    let governing = switch (governingDepartment("ggg_sweep_resolve", arg)) { case (#Err(e)) return #Err(e); case (#Ok(g)) g };
    govern(caller, "sweep_resolve", governing, arg, "Resolve sweep " # args.sweep, "Settles the sweep " # args.sweep # " from what the ledger shows.", func() {
      resolveSweep(caller, args);
    });
  };

  func needingCheck(id : Text) : Result<T.Sweep> {
    let ?s = Map.get(sweeps, Text.compare, id) else return #Err(#NotFound);
    if (s.status != #NeedsCheck) return #Err(#Conflict("only a sweep that needs checking is resolved"));
    #Ok(s);
  };

  /// A block found makes the sweep Sent, booked here and reported at the next sweep; none makes it Failed.
  func resolveSweep(caller : Principal, args : T.SweepResolveArgs) : Result<?Text> {
    let s = switch (needingCheck(args.sweep)) { case (#Err(e)) return #Err(e); case (#Ok(s)) s };
    switch (args.block) {
      case (?block) bookSweepOut(store({ s with status = #Sent; block = ?block }));
      case null ignore store({ s with status = #Failed; reason = ?"resolved: the ledger holds no such transfer" });
    };
    audit("sweep_resolve", caller, #Map([("sweep", #Text(s.id))]), #Text(s.id));
    #Ok(null);
  };

  public query func ggg_sweep_list(args : T.SweepListArgs) : async Result<T.SweepPage> {
    let wanted = func(s : T.Sweep) : Bool {
      let quarterMatches = switch (args.quarter) { case (?q) s.quarter == q; case null true };
      let statusMatches = switch (args.status) { case (?st) s.status == st; case null true };
      quarterMatches and statusMatches;
    };
    page(Iter.filter<T.Sweep>(Map.values(sweeps), wanted), args.cursor, args.limit);
  };

  // ---- The books of sweeps (I-FED-7): money moved between the realm's quarter and its capital, neither
  // revenue nor spending, in the reserved category `sweep`, with the ledger's fee in `ledger_fee`.

  /// On the quarter: `amount` and the fee out of the fund's cash, to `sweep` and `ledger_fee`.
  func bookSweepOut(s : T.Sweep) {
    let tx = newTransaction();
    book(tx, s, s.fund, #Asset, "cash", 0, s.amount + s.fee, s.id);
    book(tx, s, s.fund, #Equity, SWEEP_CATEGORY, s.amount, 0, s.id);
    book(tx, s, s.fund, #Expense, FEE_CATEGORY, s.fee, 0, s.id);
  };

  /// On the capital: `amount` into the `into` fund's cash, from `sweep`.
  func bookSweepIn(s : T.Sweep) {
    let tx = newTransaction();
    book(tx, s, s.into, #Asset, "cash", s.amount, 0, s.id);
    book(tx, s, s.into, #Equity, SWEEP_CATEGORY, 0, s.amount, s.id);
  };

  func newTransaction() : Text {
    let tx = "TX-" # Nat.toText(nextTransaction);
    nextTransaction += 1;
    tx;
  };

  func book(transaction : Text, s : T.Sweep, fund : Text, kind : T.LedgerKind, category : Text, debit : T.Money, credit : T.Money, sweep : Text) {
    if (debit == 0 and credit == 0) return;
    List.add(ledgerEntries, {
      id = "LE-" # Nat.toText(List.size(ledgerEntries) + 1);
      transaction;
      kind;
      category;
      debit;
      credit;
      symbol = s.symbol;
      fund = ?fund;
      period = currentPeriod();
      transfer = null;
      invoice = null;
      user = null;
      organization = null;
      contract = null;
      case_ = null;
      penalty = null;
      appeal = null;
      sweep = ?sweep;
      at = now();
      description = "Sweep " # sweep # " (block " # debug_show (s.block) # ")";
    });
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
    let ?installed = Map.get(codices, Text.compare, target) else return #Err(#NotFound);
    if (target == active) return #Err(#Conflict("codex " # target # " is active already"));
    if (installed.status == #Pending) return #Err(#Conflict("codex " # target # " is pending: codex_activate activates it"));
    #Ok(target);
  };

  let REVERT_NAMES_CODEX = "a revert filed as a proposal names the codex it restores";

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
    // A filed revert names the codex resolved now, so what is voted on is what runs (model §11).
    let named : ?T.CodexRevertArgs = ?{ codex = ?target };
    govern(caller, "codex_revert", root, to_candid (named), "Revert to codex " # target, "Restores the codex " # target # ".", func() {
      switch (revertTarget(named)) { case (#Err(e)) #Err(e); case (#Ok(t)) revertCodex(caller, t) };
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
      is_quarter = myCapital != null;
      is_capital = isCapital();
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
  public shared ({ caller }) func ggg_representative_add(_ : T.RepresentativeAddArgs) : async Result<T.Appointment> { nobody(caller, "organization.edit") };
  public shared ({ caller }) func ggg_representative_remove(_ : Text) : async Result<T.Appointment> { nobody(caller, "organization.edit") };
  public shared ({ caller }) func ggg_organization_set_status(_ : T.OrganizationStatusArgs) : async Result<T.Governed> { nobody(caller, "organization.delete") };

  // §5
  public shared ({ caller }) func ggg_nft_token_register(_ : T.NFTTokenRegisterArgs) : async Result<T.Governed> { notHere(caller, "treasury.manage", NO_INVOICING) };
  public shared ({ caller }) func ggg_invoice_create(_ : T.InvoiceCreateArgs) : async Result<T.InvoiceCreated> { notHere(caller, "treasury.manage", NO_INVOICING) };
  public shared ({ caller }) func ggg_invoice_check(_ : T.InvoiceCheckArgs) : async Result<T.Invoice> { nobody(caller, "self.invoice_refresh") };
  public shared ({ caller }) func ggg_invoice_refresh(_ : T.InvoiceRefreshArgs) : async Result<T.InvoicePage> { nobody(caller, "invoice.refresh") };
  public shared ({ caller }) func ggg_invoice_item_add(_ : T.InvoiceItemAddArgs) : async Result<T.Invoice> { notHere(caller, "treasury.manage", NO_INVOICING) };
  public shared ({ caller }) func ggg_period_close(_ : Text) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_budget_amend(_ : T.BudgetAmendArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_allocation_rule_draft(_ : T.AllocationRuleDraftArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_allocation_rule_propose(_ : Text) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_payroll_run(_ : T.PayrollRunArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_loan_create(_ : T.LoanCreateArgs) : async Result<T.Governed> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_loan_repay(_ : T.LoanRepayArgs) : async Result<T.Loan> { notHere(caller, "org.manage_budget", NO_MORE_BUDGETING) };
  public shared ({ caller }) func ggg_report_issue(_ : T.ReportIssueArgs) : async Result<T.FinancialReport> { notHere(caller, "treasury.manage", NO_INVOICING) };
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
  public shared ({ caller }) func ggg_land_zone_set(_ : T.LandZoneSetArgs) : async Result<T.Governed> { nobody(caller, "realm.configure") };
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
  public shared ({ caller }) func ggg_tender_lot_void(_ : T.TenderLotVoidArgs) : async Result<T.Governed> { nobody(caller, "tender.manage") };
  public shared ({ caller }) func ggg_tender_notice(_ : T.TenderNoticeArgs) : async Result<T.Tender> { nobody(caller, "tender.manage") };

  // §10
  public shared ({ caller }) func ggg_quarter_deregister(_ : Text) : async Result<T.Governed> { notHere(caller, "quarter.register", NO_QUARTER_CHANGES) };
  public shared ({ caller }) func ggg_quarter_configure(_ : T.QuarterConfigureArgs) : async Result<T.Governed> { notHere(caller, "quarter.register", NO_QUARTER_CHANGES) };
  public shared ({ caller }) func ggg_quarter_secede() : async Result<T.Governed> { nobody(caller, "quarter.secede") };
  public shared ({ caller }) func ggg_self_change_quarter(_ : T.ChangeQuarterArgs) : async Result<T.Forward> { nobody(caller, "self.change_quarter") };
  public shared ({ caller }) func ggg_federal_vote_propose(_ : T.FederalVoteProposeArgs) : async Result<T.FederalVote> { nobody(caller, "federal_vote.propose") };
  public shared ({ caller }) func ggg_federal_vote_cancel(_ : Text) : async Result<T.Governed> { nobody(caller, "federal_vote.manage") };
  public shared func ggg_federal_vote_finalize(_ : Text) : async Result<T.FederalVote> { #Err(#NotFound) };
  public shared ({ caller }) func ggg_federation_message(_ : T.FederationMessageArgs) : async Result<?T.Value> { nobody(caller, "quarter.sync") };
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
