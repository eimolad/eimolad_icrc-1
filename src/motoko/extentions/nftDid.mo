// This is a generated Motoko binding.
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module nftDid = {
  public type AccountIdentifier = Text;
  public type AccountIdentifier__1 = Text;
  public type AssetHandle = Text;
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
  public type CanisterMemorySize = Nat;
  public type CommonError = { #InvalidToken : TokenIdentifier; #Other : Text };
  public type CommonError__1 = {
    #InvalidToken : TokenIdentifier;
    #Other : Text;
  };
  public type Extension = Text;
  public type HeaderField = (Text, Text);
  public type HttpRequest = {
    url : Text;
    method : Text;
    body : [Nat8];
    headers : [HeaderField];
  };
  public type HttpResponse = {
    body : [Nat8];
    headers : [HeaderField];
    streaming_strategy : ?HttpStreamingStrategy;
    status_code : Nat16;
  };
  public type HttpStreamingCallbackResponse = {
    token : ?HttpStreamingCallbackToken;
    body : [Nat8];
  };
  public type HttpStreamingCallbackToken = {
    key : Text;
    sha256 : ?[Nat8];
    index : Nat;
    content_encoding : Text;
  };
  public type HttpStreamingStrategy = {
    #Callback : {
      token : HttpStreamingCallbackToken;
      callback : shared query HttpStreamingCallbackToken -> async HttpStreamingCallbackResponse;
    };
  };
  public type ListRequest = {
    token : TokenIdentifier__1;
    from_subaccount : ?SubAccount__1;
    price : ?Nat64;
  };
  public type Listing = { locked : ?Time; seller : Principal; price : Nat64 };
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
  public type Result = {
    #ok : [(TokenIndex, ?Listing, ?[Nat8])];
    #err : CommonError;
  };
  public type Result_1 = { #ok : [TokenIndex]; #err : CommonError };
  public type Result_2 = { #ok : Balance__1; #err : CommonError };
  public type Result_3 = { #ok; #err : CommonError };
  public type Result_4 = { #ok; #err : Text };
  public type Result_5 = { #ok : (AccountIdentifier__1, Nat64); #err : Text };
  public type Result_6 = { #ok : Metadata; #err : CommonError };
  public type Result_7 = { #ok : AccountIdentifier__1; #err : CommonError };
  public type Result_8 = { #ok : Text; #err : Text };
  public type Result_9 = {
    #ok : (AccountIdentifier__1, ?Listing);
    #err : CommonError;
  };
  public type Result_10 = { #ok : Text; #err };
  public type Sale = {
    expires : Time;
    subaccount : SubAccount__1;
    tokens : [TokenIndex];
    buyer : AccountIdentifier__1;
    price : Nat64;
  };
  public type SaleSettings = {
    startTime : Time;
    whitelist : Bool;
    totalToSell : Nat;
    sold : Nat;
    bulkPricing : [(Nat64, Nat64)];
    whitelistTime : Time;
    salePrice : Nat64;
    remaining : Nat;
    price : Nat64;
  };
  public type SaleTransaction = {
    time : Time;
    seller : Principal;
    tokens : [TokenIndex];
    buyer : AccountIdentifier__1;
    price : Nat64;
  };
  public type Settlement = {
    subaccount : SubAccount__1;
    seller : Principal;
    buyer : AccountIdentifier__1;
    price : Nat64;
  };
  public type SubAccount = [Nat8];
  public type SubAccount__1 = [Nat8];
  public type Time = Int;
  public type TokenIdentifier = Text;
  public type TokenIdentifier__1 = Text;
  public type TokenIndex = Nat32;
  public type Transaction = {
    token : TokenIdentifier__1;
    time : Time;
    seller : Principal;
    buyer : AccountIdentifier__1;
    price : Nat64;
  };
  public type TransferId = Nat32;
  public type TransferInfo = {
    to : User__1;
    token : TokenIdentifier__1;
    from : User__1;
    time : Time;
    amount : Nat;
  };
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
  public type User = { #principal : Principal; #address : AccountIdentifier };
  public type User__1 = {
    #principal : Principal;
    #address : AccountIdentifier;
  };
  public type nftActor = actor {
    acceptCycles : shared () -> async ();
    addAsset : shared (AssetHandle, Nat32, Text, Text, Text) -> async ();
    addThumbnail : shared (AssetHandle, [Nat8]) -> async ();
    adminKillHeartbeat : shared () -> async ();
    adminStartHeartbeat : shared () -> async ();
    allPayments : shared query () -> async [(Principal, [SubAccount__1])];
    allSettlements : shared query () -> async [(TokenIndex, Settlement)];
    assetTokenMap : shared query () -> async [(AssetHandle, TokenIndex)];
    assetsToTokens : shared query [AssetHandle] -> async [TokenIndex];
    approve : shared ApproveRequest -> async ();
    availableCycles : shared query () -> async Nat;
    balance : shared query BalanceRequest -> async BalanceResponse;
    bearer : shared query TokenIdentifier__1 -> async Result_7;
    changeFeeCheckTime : shared Time -> async Result_10;
    changeFeeWallet : shared AccountIdentifier__1 -> async Result_10;
    changeSum : shared Nat -> async Result_10;
    changefee : shared Nat -> async Result_10;
    clearPayments : shared (Principal, [SubAccount__1]) -> async ();
    cronCapEvents : shared () -> async ();
    cronDisbursements : shared () -> async ();
    cronSettlements : shared () -> async ();
    details : shared query TokenIdentifier__1 -> async Result_9;
    extensions : shared query () -> async [Extension];
    failedSales : shared query () -> async [
        (AccountIdentifier__1, SubAccount__1)
      ];
    findTransactions : shared AccountIdentifier__1 -> async [TransferInfo];
    findTransactionsByTID : shared TokenIdentifier__1 -> async [TransferInfo];
    getBalances : shared () -> async [(AccountIdentifier__1, Balance__1)];
    getCanisterMemorySize : shared () -> async CanisterMemorySize;
    getMinter : shared query () -> async Principal;
    getNftSupply : shared () -> async Nat32;
    getRegistry : shared () -> async [(TokenIndex, AccountIdentifier__1)];
    getTokens : shared query () -> async [(TokenIndex, Metadata)];
    getTransactions : shared () -> async [(TransferId, TransferInfo)];
    getCirculateBalance : shared () -> async Nat;
    getFee : shared () -> async Nat;
    getFeeCheckTime : shared () -> async Time;
    getFeeWallet : shared () -> async AccountIdentifier__1;
    getSum : shared () -> async Nat;
    getSupply : shared () -> async Nat32;
    getTotalSupply : shared () -> async Nat32;
    historicExport : shared () -> async Bool;
    http_request : shared query HttpRequest -> async HttpResponse;
    initCap : shared () -> async ();
    list : shared ListRequest -> async Result_3;
    listings : shared query () -> async [(TokenIndex, Listing, Metadata)];
    lock : shared (
        TokenIdentifier__1,
        Nat64,
        AccountIdentifier__1,
        SubAccount__1,
      ) -> async Result_7;
    metadata : shared query TokenIdentifier__1 -> async Result_6;
    payments : shared query () -> async ?[SubAccount__1];
    reserve : shared (
        Nat64,
        Nat64,
        AccountIdentifier__1,
        SubAccount__1,
      ) -> async Result_5;
    retreive : shared AccountIdentifier__1 -> async Result_4;
    saleTransactions : shared query () -> async [SaleTransaction];
    salesSettings : shared query AccountIdentifier__1 -> async SaleSettings;
    salesSettlements : shared query () -> async [(AccountIdentifier__1, Sale)];
    setMinter : shared Principal -> async ();
    settle : shared TokenIdentifier__1 -> async Result_3;
    settlements : shared query () -> async [
        (TokenIndex, AccountIdentifier__1, Nat64)
      ];
    stats : shared query () -> async (
        Nat64,
        Nat64,
        Nat64,
        Nat64,
        Nat,
        Nat,
        Nat,
      );
    supply : shared query TokenIdentifier__1 -> async Result_2;
    toAddress : shared query (Text, Nat) -> async AccountIdentifier__1;
    tokens : shared query AccountIdentifier__1 -> async Result_1;
    tokens_ext : shared query AccountIdentifier__1 -> async Result;
    transactions : shared query () -> async [Transaction];
    transfer : shared TransferRequest -> async TransferResponse;
  }
}