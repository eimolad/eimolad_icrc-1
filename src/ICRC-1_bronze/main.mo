import AID "../motoko/util/AccountIdentifier";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Core "../motoko/ext/Core";
import Cycles "mo:base/ExperimentalCycles";
import Error "mo:base/Error";
import ExtCore "../motoko/ext/Core";
import Float "mo:base/Float";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Nat16 "mo:base/Nat16";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Nat8 "mo:base/Nat8";
import Option "mo:base/Option";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";

actor class Ledger(init : {
                     minting_account : { owner : Principal; subaccount : ?Blob };
                     supply : Nat;
                     token_name : Text;
                     token_symbol : Text;
                     decimals : Nat8;
                     transfer_fee : Nat;
                  }) = this {

  public type Account = { owner : Principal; subaccount : ?Subaccount };
  public type Subaccount = Blob;
  public type Tokens = Nat;
  public type Memo = Blob;
  public type Timestamp = Nat64;
  public type Duration = Nat64;
  public type TxIndex = Nat;

  type AccountIdentifier = ExtCore.AccountIdentifier;
  type TokenIdentifier = ExtCore.TokenIdentifier;
  type Balance = ExtCore.Balance;
  type BalanceResponse = ExtCore.BalanceResponse;
  type Time = Time.Time;
  type User = Core.User;

  private stable var _balancesState : [(AccountIdentifier, Balance)] = [];
  private var _balances : HashMap.HashMap<AccountIdentifier, Balance> = HashMap.fromIter(_balancesState.vals(), 0, AID.equal, AID.hash);

  type TransferId = Nat32;
  private stable var _transferId : TransferId = 0; 

  private stable var _transactionsState : [(TransferId, Transaction)] = [];
  private var _transactions : HashMap.HashMap<TransferId, Transaction> = HashMap.fromIter(_transactionsState.vals(), 0, ExtCore.TokenIndex.equal, ExtCore.TokenIndex.hash);

  public type Value = { #Nat : Nat; #Int : Int; #Blob : Blob; #Text : Text; };

  let permittedDriftNanos : Duration = 60_000_000_000;
  let transactionWindowNanos : Duration = 24 * 60 * 60 * 1_000_000_000;
  let defaultSubaccount : Subaccount = Blob.fromArrayMut(Array.init(32, 0 : Nat8));

  public type TxKind = { #Burn; #Mint; #Transfer };

  public type Transfer = {
    to : User;
    from : User;
    memo : ?Memo;
    amount : Tokens;
    fee : ?Tokens;
    created_at_time : ?Timestamp;
  };

   public type ICRC1_Transfer = {
    to : Account;
    from_subaccount : ?Subaccount;
    memo : ?Memo;
    amount : Tokens;
    fee : ?Tokens;
    created_at_time : ?Timestamp;
  };

  type Eimolad_ICRC1_Transfer = {
      from : User;
      to : User;
      amount : Tokens;
      fee : ?Tokens;
      memo : ?Memo;
      created_at_time : ?Timestamp;
  };

  public type Transaction = {
    args : Transfer;
    kind : TxKind;
    // Effective fee for this transaction.
    fee : Tokens;
    timestamp : Timestamp;
  };

  public type TransferError = {
    #BadFee : { expected_fee : Tokens };
    #BadBurn : { min_burn_amount : Tokens };
    #InsufficientFunds : { balance : Tokens };
    #TooOld;
    #CreatedInFuture : { ledger_time: Timestamp };
    #Duplicate : { duplicate_of : TxIndex };
    #TemporarilyUnavailable;
    #GenericError : { error_code : Nat; message : Text };
  };

  public type TransferResult = {
    #Ok  : Tokens;
    #Err : TransferError;
  };
    private stable var feeAmount : Tokens = 0;
    private stable var feeCheckTime : Time = 7 * 24 * 60 * 60 * 1000 * 1000 * 1000;//week
    private stable var feeWallet : AccountIdentifier = "c544a3724fd0acb656aa288db82358cfb84ffe492a0c27c784841447c3a15717";
    private stable var snsCanister : Text = "4dgur-caaaa-aaaan-qapva-cai";
    private stable var sum : Nat = 1000;
    private stable var eimoladFee : Nat = 5;
    private stable var minCanisterSupply : Nat = 80;
    private stable var _minter : Account = init.minting_account;
    private stable var _minterAID : AccountIdentifier = AID.fromPrincipal(_minter.owner, _minter.subaccount);
    private stable var _supply : Balance = init.supply;
    private stable var _fee : Balance = init.transfer_fee;
    _balances.put(_minterAID, _supply);

  // Checks whether two accounts are semantically equal.
  func accountsEqual(lhs : Account, rhs : Account) : Bool {
    let lhsSubaccount = Option.get(lhs.subaccount, defaultSubaccount);
    let rhsSubaccount = Option.get(rhs.subaccount, defaultSubaccount);

    Principal.equal(lhs.owner, rhs.owner) and Blob.equal(lhsSubaccount, rhsSubaccount)
  };

  // Computes the balance of the specified account.
  func balance(account : User) : Balance {
    switch (account){
      case(#principal acc){
        let aid = AID.fromPrincipal(acc.owner, acc.subaccount);
         switch (_balances.get(aid)) {
          case (?balance) {
            return balance;
          };
          case (_) {
          return 0;
          };
        };
      };
      case(#address aid){
        switch (_balances.get(aid)) {
          case (?balance) {
            return balance;
            };
          case (_) {
          return 0;
          };
       };
      };
    };
  };

  // Computes the total token supply.
  func totalSupply() : Tokens {
    var res : Nat = 0;
    var currentSupply = switch (_balances.get(_minterAID)){
      case (?_sup) {_sup};
      case(_){0};
    };
    for ((aid, balance) in _balances.entries()) {
      res := res + balance;
    };  
    return res - currentSupply;
  };

  // Finds a transaction in the transaction HashMap.
  func findTransfer(transfer : Transfer) : ?TxIndex {
    var i = 0;
    for ((tx, transactions) in _transactions.entries()) {
      if (transactions.args == transfer) { return ?i; };
      i += 1;
    };
    null
  };

  // Checks if the principal is anonymous.
  func isAnonymous(p : Principal) : Bool {
    Blob.equal(Principal.toBlob(p), Blob.fromArray([0x04]))
  };

  // Traps if the specified blob is not a valid subaccount.
  func validateSubaccount(s : ?Subaccount) {
    let subaccount = Option.get(s, defaultSubaccount);
    assert (subaccount.size() == 32);
  };

  func validateMemo(m : ?Memo) {
    switch (m) {
      case (null) {};
      case (?memo) { assert (memo.size() <= 32); };
    }
  };

  system func preupgrade() {
    _balancesState := Iter.toArray(_balances.entries());
    _transactionsState := Iter.toArray(_transactions.entries());
  };
  system func postupgrade() {
    _balancesState := [];
    _transactionsState  := [];
  };

  public shared({ caller }) func icrc1_transfer(request : ICRC1_Transfer) : async TransferResult {
    if (isAnonymous(caller)) {
      throw Error.reject("anonymous user is not allowed to transfer funds");
    };

    let now = Nat64.fromNat(Int.abs(Time.now()));

    let txTime : Timestamp = Option.get(request.created_at_time, now);

    if ((txTime > now) and (txTime - now > permittedDriftNanos)) {
      return #Err(#CreatedInFuture { ledger_time = now });
    };

    if ((txTime < now) and (now - txTime > transactionWindowNanos + permittedDriftNanos)) {
      return #Err(#TooOld);
    };

    validateSubaccount(request.from_subaccount);
    validateSubaccount(request.to.subaccount);
    validateMemo(request.memo);

    let from = { owner = caller; subaccount = request.from_subaccount };

    let args : Transfer = {
      from = #principal(from);
      to = #principal(request.to);
      amount = request.amount;
      memo = request.memo;
      fee = request.fee;
      created_at_time = request.created_at_time;
    };

    if (Option.isSome(request.created_at_time)) {
      switch (findTransfer(args)) {
        case (?height) { return #Err(#Duplicate { duplicate_of = height }) };
        case null { };
      };
    };

    let minter = init.minting_account;

    let (kind, effectiveFee) = if (accountsEqual(from, minter)) {
      if (Option.get(request.fee, 0) != 0) {
        return #Err(#BadFee { expected_fee = 0 });
      };
      (#Mint, 0)
    } else if (accountsEqual(request.to, minter)) {
      if (Option.get(request.fee, 0) != 0) {
        return #Err(#BadFee { expected_fee = 0 });
      };

      if (request.amount < _fee) {
        return #Err(#BadBurn { min_burn_amount = _fee });
      };

      let debitBalance = balance(#principal(from));
      if (debitBalance < request.amount) {
        return #Err(#InsufficientFunds { balance = debitBalance });
      };

      (#Burn, 0)
    } else {
      let effectiveFee = _fee;
      if (Option.get(request.fee, effectiveFee) != effectiveFee) {
        return #Err(#BadFee { expected_fee = _fee });
      };

      let debitBalance = balance(#principal(from));
      if (debitBalance < request.amount + effectiveFee) {
        return #Err(#InsufficientFunds { balance = debitBalance });
      };

      (#Transfer, effectiveFee)
    };

    let tx : Transaction = {
      args = args;
      kind = kind;
      fee = effectiveFee;
      timestamp = now;
    };
    let toAID = AID.fromPrincipal(request.to.owner, request.to.subaccount);
    let fromAID = AID.fromPrincipal(from.owner, from.subaccount);

    let debitBalance = balance(#principal(from));
    var owner_balance_new : Balance = debitBalance - request.amount - effectiveFee;
    _balances.put(fromAID, owner_balance_new);
    var receiver_balance_new = switch (_balances.get(toAID)) {
      case (?receiver_balance) {
          receiver_balance + request.amount;
      };
      case (_) {
          request.amount;
      };
    };
    _balances.put(toAID, receiver_balance_new);
    let b = await addTransaction(tx);
    switch (_balances.get(_minterAID)){
      case(?balance){ // кусок кода для обновления supply
        if (balance <= Nat.div((_supply * minCanisterSupply),100)) {
          _balances.put(_minterAID, _supply);
        }
      };
      case(_){};
    };
    if ((from == _minter) and (AID.fromPrincipal(request.to.owner, request.to.subaccount) != feeWallet)){
      feeAmount := feeAmount + request.amount;
    };
    #Ok(request.amount);
  };

  public shared({ caller }) func eimolad_icrc1_transfer(request : Eimolad_ICRC1_Transfer) : async TransferResult {
    if (isAnonymous(caller)) {
      throw Error.reject("anonymous user is not allowed to transfer funds");
    };
    let to = #address(Core.User.toAID(request.to));
    let from = #address(Core.User.toAID(request.from));
    let now = Nat64.fromNat(Int.abs(Time.now()));

    let txTime : Timestamp = Option.get(request.created_at_time, now);

    if ((txTime > now) and (txTime - now > permittedDriftNanos)) {
      return #Err(#CreatedInFuture { ledger_time = now });
    };

    if ((txTime < now) and (now - txTime > transactionWindowNanos + permittedDriftNanos)) {
      return #Err(#TooOld);
    };
    switch (request.from){
      case(#principal pr){
        validateSubaccount(pr.subaccount);
      };
      case(#address ad){};
    };
        switch (request.to){
      case(#principal pr){
        validateSubaccount(pr.subaccount);
      };
      case(#address ad){};
    };
    validateMemo(request.memo);

    let args : Transfer = {
      from = from;
      to = to;
      amount = request.amount;
      memo = request.memo;
      fee = request.fee;
      created_at_time = request.created_at_time;
    };

    if (Option.isSome(request.created_at_time)) {
      switch (findTransfer(args)) {
        case (?height) { return #Err(#Duplicate { duplicate_of = height }) };
        case null { };
      };
    };


    let (kind, effectiveFee) = if (Core.User.equal(from, #address(_minterAID))) {
      if (Option.get(request.fee, 0) != 0) {
        return #Err(#BadFee { expected_fee = 0 });
      };
      (#Mint, 0)
    } else if (Core.User.equal(to, #address(_minterAID))) {
      if (Option.get(request.fee, 0) != 0) {
        return #Err(#BadFee { expected_fee = 0 });
      };

      if (request.amount < _fee) {
        return #Err(#BadBurn { min_burn_amount = _fee });
      };

      let debitBalance = balance(from);
      if (debitBalance < request.amount) {
        return #Err(#InsufficientFunds { balance = debitBalance });
      };

      (#Burn, 0)
    } else {
      let effectiveFee = _fee;
      if (Option.get(request.fee, effectiveFee) != effectiveFee) {
        return #Err(#BadFee { expected_fee = _fee });
      };

      let debitBalance = balance(from);
      if (debitBalance < request.amount + effectiveFee) {
        return #Err(#InsufficientFunds { balance = debitBalance });
      };

      (#Transfer, effectiveFee)
    };

    let tx : Transaction = {
      args = args;
      kind = kind;
      fee = effectiveFee;
      timestamp = now;
    };
    let toAID = switch (to){case(#address address){address}};
    let fromAID = switch (from){case(#address address){address}};

    let debitBalance = balance(from);
    var owner_balance_new : Balance = debitBalance - request.amount - effectiveFee;
    _balances.put(fromAID, owner_balance_new);
    var receiver_balance_new = switch (_balances.get(toAID)) {
      case (?receiver_balance) {
          receiver_balance + request.amount;
      };
      case (_) {
          request.amount;
      };
    };
    _balances.put(toAID, receiver_balance_new);
    let b = await addTransaction(tx);
    switch (_balances.get(_minterAID)){
      case(?balance){ // update supply
        if (balance <= Nat.div((_supply * minCanisterSupply),100)) {
          _balances.put(_minterAID, _supply);
        }
      };
      case(_){};
    };
    if ((request.from == #address(_minterAID)) and (request.to != #address(feeWallet))){
      feeAmount := feeAmount + request.amount;
    };
    #Ok(request.amount);
  };

// ===============================Eimolad===================================//
type ResultTrans = {
      trans : [Transaction];
      size : Nat32;
  };
  
  public func getICRCTransactions(p : Nat32, count : Nat32) : async ResultTrans{ //rewrite soon
    let size = Nat32.fromNat(_transactions.size());
    let lastEl : Int32 = Int32.fromNat32(_transferId - 1);
    let firstEl : Int32 = Int32.fromNat32(_transferId) - Int32.fromNat32(size);
    var i : Int32 = (lastEl - Int32.fromNat32(p) * Int32.fromNat32(count)); 
    var buf : Buffer.Buffer<Transaction> = Buffer.Buffer(0);
    while ((i > (lastEl - Int32.fromNat32(p) * Int32.fromNat32(count)) - Int32.fromNat32(count)) and (size != 0) and (i >= firstEl)){
      switch(_transactions.get(Int32.toNat32(i))){
          case(?ch){buf.add(ch)};
          case(_){};
        };
      i := i - 1;
    };
    let res : ResultTrans = {
        trans = buf.toArray();
        size = size;
    };
    return res;
  };

 public func findTransactions(aid : AccountIdentifier) : async [Transaction]{ // get trans by aid
    var buf : Buffer.Buffer<Transaction> = Buffer.Buffer(0);
    for ((id, tr) in _transactions.entries()){
      switch (tr.args.from){
       case (#address fr){
          if (fr == aid){
          buf.add(tr);
      };
        };
        case(#principal fr)(
          if (AID.fromPrincipal(fr.owner, fr.subaccount) == aid){
          buf.add(tr);}
        );
      };
      switch (tr.args.to){
       case (#address to){
          if (to == aid){
          buf.add(tr);
      };
        };
        case(#principal to)(
          if (AID.fromPrincipal(to.owner, to.subaccount) == aid){
          buf.add(tr);}
        );
      };
    };
    let res = buf.toArray();
    return res;
};

  private func addTransaction (args : Transaction) : async Result.Result<Text, ()>{ 
    let transferId = _transferId;
    _transactions.put(transferId, args);
    _transferId := _transferId + 1;
    return #ok("successful record of transaction");
};

 private func checkTransfersMonth () : async () {
    for ((id, tr) in _transactions.entries()){
      let now = Nat64.fromNat(Int.abs(Time.now()));
      var claimTime : Nat64 = 3 * 30 * 24 * 60 * 60 * 1000 * 1000 * 1000;
      if (Nat64.div((now - tr.timestamp), claimTime) >= 1) { // 
        _transactions.delete(id);
      };
    };
  };

  private stable var t : Time = Time.now();
  private stable var checkTime : Time = 30 * 24 * 60 * 60 * 1000 * 1000 * 1000;//30 * 24 * 3600 000 000 000;
  private stable var feeLastCheck: Time = Time.now();
  private stable var lastCheck: Time = Time.now();
  system func heartbeat() : async () {
    if (Int.div((Time.now() - feeLastCheck), feeCheckTime) >= 1) {
      feeLastCheck := Time.now();
      if (feeAmount >= sum) { // checking the commission accrual conditions
          let tr = await eimolad_icrc1_transfer({
            from = #address(_minterAID);
            to = #address(feeWallet);
            amount = Nat.div(feeAmount, sum) * eimoladFee * 10;
            fee = null;
            memo = null;
            created_at_time = null;});
        };
      feeAmount := Nat.rem(feeAmount, sum);
    };
    if (Int.div((Time.now() - lastCheck), checkTime) >= 1) {
    lastCheck  := Time.now();
    await checkTransfersMonth();
    };
  };

  public func eimolad_balance (account : User) : async Balance {
    balance(account);  
  };

  type CanisterMemorySize = Nat;

  public func getCanisterMemorySize() : async CanisterMemorySize {
    Prim.rts_memory_size();
    };

  public shared(msg) func transferFromCanister (to : User, amount : Nat) : async TransferResult{ 
  assert(msg.caller == Principal.fromText("ylwtf-viaaa-aaaan-qaddq-cai")); 
  var args : Eimolad_ICRC1_Transfer = {
    from = #address(AID.fromPrincipal(_minter.owner, _minter.subaccount));
    to = to;
    amount = amount;
    fee = null;
    memo = null;
    created_at_time = null;
  };
  let tr = await eimolad_icrc1_transfer(args);
  };

public func icrc_1_TransferToPrincipal (to : Text, amount : Nat) : async TransferResult {

   var args : ICRC1_Transfer = {
      from_subaccount = ?defaultSubaccount;
      to = {owner = Principal.fromText(to); subaccount = ?defaultSubaccount};
      amount = amount;
      fee = null;
      memo = null;
      created_at_time = null;
    };
    let tr = await icrc1_transfer(args);
  };

  public shared(msg) func getBalances () : async [(AccountIdentifier, Balance)]{
    assert(msg.caller == Principal.fromText(snsCanister));
    Iter.toArray(_balances.entries());
  };
  
  public shared(msg) func changeICRCfee (newFee : Nat) : async Result.Result<Text, ()>{ // icrc fee
    assert(msg.caller == Principal.fromText(snsCanister));
    _fee := newFee;
    return #ok("successful change of ICRC-1 fee")
  };

  public shared(msg) func changefee (newFee : Nat) : async Result.Result<Text, ()>{
    assert(msg.caller == Principal.fromText(snsCanister));
    eimoladFee := newFee;
    return #ok("successful change of fee")
  };
  public shared(msg) func getFee () : async Nat{
    eimoladFee;
  };

  public shared(msg) func changeCapacity (newCap : Nat) : async Result.Result<Text, ()>{
    assert(msg.caller == Principal.fromText(snsCanister));
    _supply := newCap;
    return #ok("successful change of Capacity")
  };
  public shared(msg) func getCapacity () : async Nat{
    _supply;
  };
  
  public shared(msg) func changeSum (newSum : Nat) : async Result.Result<Text, ()>{
    assert(msg.caller == Principal.fromText(snsCanister));
    sum := newSum;
    return #ok("successful change of Token's sum")
  };
  public shared(msg) func getSum () : async Nat{
    sum;
  };

  public shared(msg) func changeFeeWallet (newFeeWallet : AccountIdentifier) : async Result.Result<Text, ()>{
    assert(msg.caller == Principal.fromText(snsCanister));
    feeWallet := newFeeWallet;
    return #ok("successful change of fee Wallet")
  };

  public shared(msg) func getFeeWallet () : async AccountIdentifier{
    feeWallet;
  };

  public shared(msg) func changeFeeCheckTime (newFeeCheckTime : Time) :async Result.Result<Text, ()>{
    assert(msg.caller == Principal.fromText(snsCanister));
    feeCheckTime := newFeeCheckTime;
    return #ok("successful change of fee check time")
  };

  public shared(msg) func getFeeCheckTime () : async Time{
    feeCheckTime;
  };

  public shared(msg) func changeMinCanisterSupply (newSupply : Nat) : async Result.Result<Text, ()>{ 
  assert(msg.caller == Principal.fromText(snsCanister));
    minCanisterSupply := newSupply;
    return #ok("successful change of minimal border of canister's supply")
  };

  public shared(msg) func getMinCanisterSupply () : async Nat{
    minCanisterSupply;
  };
  
  public shared(msg) func getCirculateBalance () : async Nat{
    totalSupply();
  };

  public type TokenInfo = {
    royalty : Nat;
    royaltyWallet : Text;
    min_CB_value : Nat;
    token_standart : Text;
    token_symbol : Text;
    token_canister : Text;
    snsCanister : Text;
    current_CB_value : Balance;
    CB_capacity : Nat; 
  };

  public func getTokenInfo() : async TokenInfo {
    let tokenInfo : TokenInfo = {
      royalty = eimoladFee;
      royaltyWallet = feeWallet;
      min_CB_value = minCanisterSupply;
      token_standart = "ICRC-1";
      token_symbol = init.token_symbol;
      token_canister = Principal.toText(Principal.fromActor(this));
      snsCanister = snsCanister;
      current_CB_value = balance(#address(_minterAID));
      CB_capacity = _supply;
    };
  };
  
// ===============================Eimolad===================================//

  public query func icrc1_balance_of(account : Account) : async Nat {
    balance(#principal(account));
  };

  public query func icrc1_total_supply() : async Tokens {
    totalSupply();
  };

  public query func icrc1_minting_account() : async ?Account {
    ?init.minting_account
  };

  public query func icrc1_name() : async Text {
    init.token_name
  };

  public query func icrc1_symbol() : async Text {
    init.token_symbol
  };

  public query func icrc1_decimals() : async Nat8 {
    init.decimals
  };

  public query func icrc1_fee() : async Nat {
    _fee
  };

  public query func icrc1_metadata() : async [(Text, Value)] {
    [
      ("icrc1:name", #Text(init.token_name)),
      ("icrc1:symbol", #Text(init.token_symbol)),
      ("icrc1:decimals", #Nat(Nat8.toNat(init.decimals))),
      ("icrc1:fee", #Nat(_fee)),
    ]
  };

  public query func icrc1_supported_standards() : async [{ name : Text; url : Text }] {
    [
      { name = "ICRC-1"; url = "https://github.com/dfinity/ICRC-1" }
    ]
  };

  //Internal cycle management - good general case
  public func acceptCycles() : async () {
    let available = Cycles.available();
    let accepted = Cycles.accept(available);
    assert (accepted == available);
  };
  public query func availableCycles() : async Nat {
    return Cycles.balance();
  };
//=============================assets==================================//

type File = {
    ctype : Text;//"image/jpeg"
    data : [Blob];
  };

  type Asset = {
    name : Text;
    payload : File;
  };

  private stable var _assets : [Asset] = [];

  public shared(msg) func addAsset(asset : Asset) : async Nat {
    assert(msg.caller == Principal.fromText("xocga-4vh64-bidcg-3uxjz-fffxn-exbj4-mgbvl-hlnv6-5syll-ghhkw-eqe"));
    _assets := Array.append(_assets, [asset]);
    _assets.size() - 1;
  };

//HTTP
  type HeaderField = (Text, Text);
  type HttpResponse = {
    status_code: Nat16;
    headers: [HeaderField];
    body: Blob;
    streaming_strategy: ?HttpStreamingStrategy;
  };
  type HttpRequest = {
    method : Text;
    url : Text;
    headers : [HeaderField];
    body : Blob;
  };
  type HttpStreamingCallbackToken =  {
    content_encoding: Text;
    index: Nat;
    key: Text;
    sha256: ?Blob;
  };

  type HttpStreamingStrategy = {
    #Callback: {
        callback: query (HttpStreamingCallbackToken) -> async (HttpStreamingCallbackResponse);
        token: HttpStreamingCallbackToken;
    };
  };

  type HttpStreamingCallbackResponse = {
    body: Blob;
    token: ?HttpStreamingCallbackToken;
  };
  let NOT_FOUND : HttpResponse = {status_code = 404; headers = []; body = Blob.fromArray([]); streaming_strategy = null};
  let BAD_REQUEST : HttpResponse = {status_code = 400; headers = []; body = Blob.fromArray([]); streaming_strategy = null};
  
  public query func http_request(request : HttpRequest) : async HttpResponse {
    let path = Iter.toArray(Text.tokens(request.url, #text("/")));
    switch(_getParam(request.url, "asset")) {
      case (?atext) {
        switch(_getAssetId(atext)){
          case(?assetid){
            let asset : Asset = _assets[assetid];
            return _processFile(Nat.toText(assetid), asset.payload);
          };
          case (_){};
        };
      };
      case (_){};
    };
    
    return {
      status_code = 200;
      headers = [("content-type", "text/plain")];
      body = Text.encodeUtf8 (
        "Cycle Balance:                            ~" # debug_show (Cycles.balance()/1000000000000) # "T\n"
      );
      streaming_strategy = null;
    };
  };
  public query func http_request_streaming_callback(token : HttpStreamingCallbackToken) : async HttpStreamingCallbackResponse {
    switch(_getAssetId(token.key)) {
      case null return {body = Blob.fromArray([]); token = null};
      case (?assetid) {
        let asset : Asset = _assets[assetid];
        let res = _streamContent(token.key, token.index, asset.payload.data);
        return {
          body = res.0;
          token = res.1;
        };
      };
    };
  };
  private func _getAssetId(t : Text) : ?Nat {
    var n : Nat = 0;
    while(n < _assets.size()) {
      if (t == Nat.toText(n)) {
        return ?n;
      } else {
        n += 1;
      };
    };
    return null;
  };
  private func _processFile(tokenid : TokenIdentifier, file : File) : HttpResponse {
    if (file.data.size() > 1 ) {
      let (payload, token) = _streamContent(tokenid, 0, file.data);
      return {
        status_code = 200;
        headers = [("Content-Type", file.ctype), ("cache-control", "public, max-age=15552000")];
        body = payload;
        streaming_strategy = ?#Callback({
          token = Option.unwrap(token);
          callback = http_request_streaming_callback;
        });
      };
    } else {
      return {
        status_code = 200;
        headers = [("content-type", file.ctype), ("cache-control", "public, max-age=15552000")];
        body = file.data[0];
        streaming_strategy = null;
      };
    };
  };
  
  private func _getParam(url : Text, param : Text) : ?Text {
    var _s : Text = url;
    Iter.iterate<Text>(Text.split(_s, #text("/")), func(x, _i) {
      _s := x;
    });
    Iter.iterate<Text>(Text.split(_s, #text("?")), func(x, _i) {
      if (_i == 1) _s := x;
    });
    var t : ?Text = null;
    var found : Bool = false;
    Iter.iterate<Text>(Text.split(_s, #text("&")), func(x, _i) {
      if (found == false) {
        Iter.iterate<Text>(Text.split(x, #text("=")), func(y, _ii) {
          if (_ii == 0) {
            if (Text.equal(y, param)) found := true;
          } else if (found == true) t := ?y;
        });
      };
    });
    return t;
  };
  private func _streamContent(id : Text, idx : Nat, data : [Blob]) : (Blob, ?HttpStreamingCallbackToken) {
    let payload = data[idx];
    let size = data.size();

    if (idx + 1 == size) {
        return (payload, null);
    };

    return (payload, ?{
        content_encoding = "gzip";
        index = idx + 1;
        sha256 = null;
        key = id;
    });
  };
  public shared(msg) func streamAsset(id : Nat, isThumb : Bool, payload : Blob) : async () {
    assert(msg.caller == Principal.fromText("xocga-4vh64-bidcg-3uxjz-fffxn-exbj4-mgbvl-hlnv6-5syll-ghhkw-eqe"));
    var tassets : [var Asset] = Array.thaw<Asset>(_assets);
    var asset : Asset = tassets[id];
      var arrTmp = Blob.toArray(asset.payload.data[0]);
      var newArr = Array.append(arrTmp, Blob.toArray(payload));
      var newData = Blob.fromArray(newArr);
      asset := {
        name = asset.name;
        payload = {
          ctype = asset.payload.ctype;
          data = [newData];
        };
      };
    tassets[id] := asset;
    // D.print(debug_show(tassets[id]));
    _assets := Array.freeze(tassets);
  };

  public shared(msg) func rewriteAsset(name : Text, asset : Asset) : async ?Nat {
    assert(msg.caller == Principal.fromText("xocga-4vh64-bidcg-3uxjz-fffxn-exbj4-mgbvl-hlnv6-5syll-ghhkw-eqe"));
    var i : Nat = 0;
    for(a in _assets.vals()){
      if (a.name == name) {
        var tassets : [var Asset]  = Array.thaw<Asset>(_assets);
        // var asset : Asset = tassets[i];
        tassets[i] := asset;
        _assets := Array.freeze(tassets);
        return ?i;
      };
      i += 1;
    };
    return null;
  };
//=============================assets==================================//
};