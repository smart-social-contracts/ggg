/// Breaks GGG on purpose, to test that the conformance suite reports failures.
/// It doesn't declare GGG, its realm has no name, and it has no member or proposal methods.
import T "Ggg";

persistent actor {
  public query func icrc10_supported_standards() : async [{ name : Text; url : Text }] {
    [{ name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-10/ICRC-10.md" }];
  };

  public query func ggg_realm_info() : async T.Realm {
    {
      id = "1";
      name = "";
      manifesto = "";
      welcome_message = "";
      status = #Beta;
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
      installed_version = "0";
      network = "local";
    };
  };
};
