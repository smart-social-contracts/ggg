/// Breaks GGG-1 on purpose, to test that the conformance suite reports failures.
/// It does not declare GGG-1, its realm has no name, and it has no member or proposal methods.
persistent actor {
  public query func icrc10_supported_standards() : async [{ name : Text; url : Text }] {
    [{ name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md" }];
  };

  public query func ggg1_realm_info() : async {
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
  } {
    {
      name = "";
      manifesto = "";
      welcome_message = "";
      status = #Beta;
      accounting_currency = null;
      logo_url = null;
      background_image_url = null;
      open_registration = false;
      is_capital = false;
      implementation = { name = "broken"; version = "0"; url = null };
      member_count = null;
    };
  };
};
