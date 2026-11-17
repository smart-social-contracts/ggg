/// A small ICRC-1 ledger for the sweep tests (model I-FED-5, I-FED-6): balances, a fee of 10, minting
/// by the minting account, and the reference ledger's deduplication: a transfer repeated with the same
/// arguments and created_at_time within 24 hours is answered with the block of the first (Duplicate), and
/// one older than that window, or ahead of the ledger's clock, is refused. `set_answer`, which only the
/// minting account may call, makes the ledger drop its answers, so a test can show what a GOS does when it
/// does not learn the outcome of a transfer.
import List "mo:core/List";
import Map "mo:core/Map";
import Nat64 "mo:core/Nat64";
import Principal "mo:core/Principal";
import Runtime "mo:core/Runtime";
import Text "mo:core/Text";
import Time "mo:core/Time";

persistent actor class Ledger(minter : Principal) {
  type Account = { owner : Principal; subaccount : ?Blob };
  type TransferArg = {
    from_subaccount : ?Blob;
    to : Account;
    amount : Nat;
    fee : ?Nat;
    memo : ?Blob;
    created_at_time : ?Nat64;
  };
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
  /// Answer: as any ledger. ApplyThenDrop: applies the transfer, but the caller gets no answer, as when a
  /// reply is lost. DropOnly: applies nothing and gives no answer, as when the ledger is unreachable.
  type Answer = { #Answer; #ApplyThenDrop; #DropOnly };

  let FEE = 10;
  let WINDOW : Nat64 = 24 * 3600 * 1_000_000_000;
  let DRIFT : Nat64 = 2 * 60 * 1_000_000_000;

  let balances = Map.empty<Text, Nat>();
  // Each transfer that carried a created_at_time, by everything it said, for deduplication.
  let seen = Map.empty<Text, Nat>();
  let blocks = List.empty<Text>();
  var answer : Answer = #Answer;

  func key(a : Account) : Text = Principal.toText(a.owner) # "/" # debug_show (a.subaccount);

  func balanceOf(a : Account) : Nat = switch (Map.get(balances, Text.compare, key(a))) {
    case (?b) b;
    case null 0;
  };

  public query func icrc1_balance_of(a : Account) : async Nat { balanceOf(a) };

  public query func icrc1_fee() : async Nat { FEE };

  public shared ({ caller }) func set_answer(a : Answer) : async () {
    if (caller != minter) Runtime.trap("only the minting account sets how the ledger answers");
    answer := a;
  };

  public shared ({ caller }) func icrc1_transfer(arg : TransferArg) : async { #Ok : Nat; #Err : TransferError } {
    if (answer == #DropOnly) Runtime.trap("the ledger gives no answer");
    let result = transfer(caller, arg);
    if (answer == #ApplyThenDrop) {
      // The awaited self-call commits the transfer; the trap after it loses only the answer.
      await async {};
      Runtime.trap("the ledger applied the transfer and lost its answer");
    };
    result;
  };

  func transfer(caller : Principal, arg : TransferArg) : { #Ok : Nat; #Err : TransferError } {
    let now = Nat64.fromIntWrap(Time.now());
    let from = { owner = caller; subaccount = arg.from_subaccount };
    let said = debug_show ((from, arg));
    switch (arg.created_at_time) {
      case (?t) {
        if (t + WINDOW + DRIFT < now) return #Err(#TooOld);
        if (t > now + DRIFT) return #Err(#CreatedInFuture({ ledger_time = now }));
        switch (Map.get(seen, Text.compare, said)) {
          case (?block) return #Err(#Duplicate({ duplicate_of = block }));
          case null {};
        };
      };
      case null {};
    };
    let minting = caller == minter;
    let fee = if (minting) 0 else FEE;
    switch (arg.fee) { case (?f) { if (f != fee) return #Err(#BadFee({ expected_fee = fee })) }; case null {} };
    if (not minting) {
      let balance = balanceOf(from);
      if (balance < arg.amount + fee) return #Err(#InsufficientFunds({ balance }));
      Map.add(balances, Text.compare, key(from), balance - arg.amount - fee : Nat);
    };
    Map.add(balances, Text.compare, key(arg.to), balanceOf(arg.to) + arg.amount);
    let block = List.size(blocks);
    List.add(blocks, said);
    if (arg.created_at_time != null) Map.add(seen, Text.compare, said, block);
    #Ok(block);
  };
};
