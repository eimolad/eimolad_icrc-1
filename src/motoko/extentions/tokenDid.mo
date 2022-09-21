module tokenDid = {
  public type AccountIdentifier = Text;
  public type ApproveRequest = {
    token : TokenIdentifier;
    subaccount : ?SubAccount;
    allowance : Balance;
    spender : Principal;
  };
  public type Balance = Nat;
  public type BalanceRequest = { token : TokenIdentifier; user : User };
  public type BalanceResponse = { #ok : Balance; #err : CommonError__1 };
  public type Balance__1 = Nat;
  public type CommonError = { #InvalidToken : TokenIdentifier; #Other : Text };
  public type CommonError__1 = {
    #InvalidToken : TokenIdentifier;
    #Other : Text;
  };
  public type Extension = Text;
  public type Memo = [Nat8];
  public type Metadata = {
    #fungible : {
      decimals : Nat8;
      metadata : ?[Nat8];
      name : Text;
      symbol : Text;
    };
    #nonfungible : { metadata : ?[Nat8] };
  };
  public type Result = { #ok : Balance__1; #err : CommonError };
  public type Result_1 = { #ok : Metadata; #err : CommonError };
  public type SubAccount = [Nat8];
  public type TokenIdentifier = Text;
  public type TokenIdentifier__1 = Text;
  public type TransferRequest = {
    to : User;
    token : TokenIdentifier;
    notify : Bool;
    from : User;
    memo : Memo;
    subaccount : ?SubAccount;
    amount : Balance;
  };
  public type TransferResponse = {
    #ok : Balance;
    #err : {
      #CannotNotify : AccountIdentifier;
      #InsufficientBalance;
      #InvalidToken : TokenIdentifier;
      #Rejected;
      #Unauthorized : AccountIdentifier;
      #Other : Text;
    };
  };
  // public let eGoldCanister = actor "rg7c3-gyaaa-aaaan-qacsq-cai" : actor
  // "rg7c3-gyaaa-aaaan-qacsq-cai"
  public type User = { #principal : Principal; #address : AccountIdentifier };
  public type tokenActor = actor {
    acceptCycles : shared () -> async ();
    approve : shared ApproveRequest -> async ();
    availableCycles : shared query () -> async Nat;
    balance : shared query BalanceRequest -> async BalanceResponse;
    extensions : shared query () -> async [Extension];
    metadata : shared query TokenIdentifier__1 -> async Result_1;
    supply : shared query TokenIdentifier__1 -> async Result;
    transfer : shared TransferRequest -> async TransferResponse;
  }
}