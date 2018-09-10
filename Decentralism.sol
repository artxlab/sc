pragma solidity ^0.4.24;

//==============================================================================
//     _    _  _ _|_ _  .
//    (/_\/(/_| | | _\  .
//==============================================================================
contract Devents {
    // fired whenever a player registers a name
    event onNewName
    (
        address indexed playerAddress,
        string playerName,
        bool isNewPlayer,
        address affiliateAddress,
        uint256 amountPaid,
        uint256 timeStamp
    );

    // fired at end of buy or reload
    event onEndTx
    (
        string playerName,
        address playerAddress,
        uint256 ethIn,
        uint256 keysBought,
        uint256 potAmount
    );

    // fired whenever theres a withdraw
    event onWithdraw
    (
        address playerAddress,
        string playerName,
        uint256 ethOut,
        uint256 timeStamp
    );

    // fired whenever a withdraw forces end round to be ran
    event onWithdrawAndDistribute
    (
        address playerAddress,
        string playerName,
        uint256 ethOut
    );

    // (fomo3d long only) fired whenever a player tries a buy after round timer
    // hit zero, and causes end round to be ran.
    event onBuyAndDistribute
    (
        address playerAddress,
        bytes32 playerName,
        uint256 ethIn,
        uint256 compressedData,
        uint256 compressedIDs,
        address winnerAddr,
        bytes32 winnerName,
        uint256 amountWon,
        uint256 newPot,
        uint256 P3DAmount,
        uint256 genAmount
    );

    // (fomo3d long only) fired whenever a player tries a reload after round timer
    // hit zero, and causes end round to be ran.
    event onReLoadEnd
    (
        address playerAddress,
        string playerName,
        uint256 amountWon,
        uint256 pot
    );

    // fired whenever an affiliate is paid
    event onAffiliatePayout
    (
        address affiliateAddress,
        string affiliateName,
        uint256 amount,
        uint256 timeStamp
    );

}

//==============================================================================
//   _ _  _ _|_ _ _  __|_   _ _ _|_    _   .
//  (_(_)| | | | (_|(_ |   _\(/_ | |_||_)  .
//====================================|=========================================

contract modularLong is Devents {}

contract Decentralism is modularLong {
    using SafeMath for *;
    using NameFilter for string;
    using DKeysCalc for uint256;
    struct WinnerGroup {
        uint256 price;
        string id;
        address[] addr;
    }

    // for Decentralism
    uint256 constant delay_ = 120 seconds;
    uint256 public startTime_;
    uint256 public initEth_ = 1000000;
    bool private start_ = false;
    bool private end_ = false;
    uint256 mask_ = 0;
    uint256 accDelay_ = 0;
    uint256 keys_ = 0;
    uint256 pot_ = 0;
    uint256 eth_ = 0;
    uint256 com_ = 0;
    address private win_;
    uint256 private totalBalance_;

    address[] public addressIndexes;

    mapping (address => Ddatasets.Player) public plyrs_;   // (pID => data) player data
    mapping (string => address) referMap_;
    mapping (address => bool) public winner_;

    WinnerGroup winnerGroup1_;
    WinnerGroup winnerGroup2_;
    WinnerGroup winnerGroup3_;
    address[] _result;

    //==============================================================================
    //     _ _  _  __|_ _    __|_ _  _  .
    //    (_(_)| |_\ | | |_|(_ | (_)|   .  (initial data setup upon contract deploy)
    //==============================================================================
    constructor()
    public
    {
        startTime_ = now;

    }
    //==============================================================================
    //     _ _  _  _|. |`. _  _ _  .
    //    | | |(_)(_||~|~|(/_| _\  .  (these are safety checks)
    //==============================================================================
    /**
     * @dev used to make sure no one can interact with contract until it has
     * been activated.
     */
    modifier isActivated() {
        require(start_ == true, "its not ready yet.  check ?eta in discord");
        _;
    }

    /**
     * @dev prevents contracts from interacting with fomo3d
     */
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }

    /**
     * @dev sets boundaries for incoming tx
     */
    modifier isWithinLimits(uint256 _eth) {
        require(_eth >= 1000000000, "pocket lint: not a valid currency");
        require(_eth <= 100000000000000000000000, "no vitalik, no");
        _;
    }

    //==============================================================================
    //     _    |_ |. _   |`    _  __|_. _  _  _  .
    //    |_)|_||_)||(_  ~|~|_|| |(_ | |(_)| |_\  .  (use these to interact with contract)
    //====|=========================================================================
    /**
     * @dev emergency buy uses last stored affiliate ID and team snek
     */
    function()
    isActivated()
    isHuman()
    isWithinLimits(msg.value)
    public
    payable
    {
        Ddatasets.EventReturns memory _eventData_;

        // buy core
        buyCoreNew(msg.sender, plyrs_[msg.sender].laff, msg.value, _eventData_);
    }

    /**
     * @dev converts all incoming ethereum to keys.
     * -functionhash- 0x8f38f309 (using ID for affiliate)
     * -functionhash- 0x98a0871d (using address for affiliate)
     * -functionhash- 0xa65b37a1 (using name for affiliate)
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     *
     */
    function buyXidNew(string _affCode, uint256 _est)
    isActivated()
    isHuman()
    isWithinLimits(msg.value)
    public
    payable
    {
        Ddatasets.EventReturns memory _eventData_;
        require (referMap_[_affCode] != 0, "Invalid Referral code");

        // fetch player address
        address _addr = msg.sender;
        address _aff = referMap_[_affCode];
        plyrs_[_addr].est.push(_est);

        // manage affiliate residuals
        // if no affiliate code was given or player tried to use their own, lolz
        if (_aff == 0 || _aff == _addr)
        {
            // use last stored affiliate code
            _aff = plyrs_[msg.sender].laff;

            // if affiliate code was given & its not the same as previously stored
        } else if (_aff != plyrs_[msg.sender].laff) {
            // update last affiliate
            plyrs_[msg.sender].laff = _aff;
        }

        // buy core
        buyCoreNew(_addr, _aff, msg.value, _eventData_);
    }

    /**
     * @dev essentially the same as buy, but instead of you sending ether
     * from your wallet, it uses your unwithdrawn earnings.
     * -functionhash- 0x349cdcac (using ID for affiliate)
     * -functionhash- 0x82bfc739 (using address for affiliate)
     * -functionhash- 0x079ce327 (using name for affiliate)
     * @param _affCode the ID/address/name of the player who gets the affiliate fee
     * @param _est amount of earnings to use (remainder returned to gen vault)
     */
    function reLoadXidNew(string _affCode, uint256 _est)
    isActivated()
    isHuman()
    isWithinLimits(msg.value)
    public
    payable
    {
        // set up our tx event data
        Ddatasets.EventReturns memory _eventData_;
        require (referMap_[_affCode] != 0, "Invalid Referral code");

        // fetch player id
        address _addr = msg.sender;
        address _aff = referMap_[_affCode];
        plyrs_[_addr].est.push(_est);

        // manage affiliate residuals
        // if no affiliate code was given or player tried to use their own, lolz
        if (_aff == 0 || _aff == _addr)
        {
            // use last stored affiliate code
            _aff = plyrs_[msg.sender].laff;

            // if affiliate code was given & its not the same as previously stored
        } else if (_aff != plyrs_[msg.sender].laff) {
            // update last affiliate
            plyrs_[msg.sender].laff = _aff;
        }

        // reload core
        reLoadCoreNew(_addr, _aff, msg.value, _eventData_);
    }

    /**
     * @dev withdraws all of your earnings.
     * -functionhash- 0x3ccfd60b
     */
    function withdraw()
    isActivated()
    isHuman()
    public
    {
        // grab time
        uint256 _now = now;

        // fetch player ID
        address _addr = msg.sender;

        // setup temp var for player eth
        uint256 _eth;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // check to see if round has ended and no one has run round end yet
        if (_ethInc > _ethDec)
        {
            // set up our tx event data
            Ddatasets.EventReturns memory _eventData_;

            // end the round (distributes pot)
            if (!end_) {
                end_ = true;
            }

            _eventData_ = endRound(_eventData_);

            // get their earnings
            _eth = withdrawEarningsXAddr(_addr);

            // gib moni
            if (_eth > 0)
                _addr.transfer(_eth);

            // fire withdraw and distribute event
            emit Devents.onWithdrawAndDistribute
            (
                msg.sender,
                plyrs_[_addr].name,
                _eth
            );

            // in any other situation
        } else {
            // get their earnings
            _eth = withdrawEarningsXAddr(_addr);

            // gib moni
            if (_eth > 0)
                _addr.transfer(_eth);

            // fire withdraw event
            emit Devents.onWithdraw(msg.sender, plyrs_[_addr].name, _eth, _now);
        }
    }

    /**
     * @dev use these to register names.  they are just wrappers that will send the
     * registration requests to the PlayerBook contract.  So registering here is the
     * same as registering there.  UI will always display the last name you registered.
     * but you will still own all previously registered names to use as affiliate
     * links.
     * - must pay a registration fee.
     * - name must be unique
     * - names will be converted to lowercase
     * - name cannot start or end with a space
     * - cannot have more than 1 space in a row
     * - cannot be only numbers
     * - cannot start with 0x
     * - name must be at least 1 char
     * - max length of 32 characters long
     * - allowed characters: a-z, 0-9, and space
     * -functionhash- 0x921dec21 (using ID for affiliate)
     * -functionhash- 0x3ddd4698 (using address for affiliate)
     * -functionhash- 0x685ffd83 (using name for affiliate)
     * @param _name players desired name
     * @param _affCode affiliate ID, address, or name of who referred you
     * (this might cost a lot of gas)
     */
    function registerID(string _name, string _affCode, string _selfReferCode)
    isHuman()
    public
    payable
    {
        address _addr = msg.sender;
        uint256 _paid = msg.value;
        (bool _isNewPlayer, address _affID) = registerIDFromDapp(_name, _affCode, _selfReferCode);

        // fire event
        emit Devents.onNewName(_addr, _name, _isNewPlayer, _affID, _paid, now);
    }


    //==============================================================================
    //     _  _ _|__|_ _  _ _  .
    //    (_|(/_ |  | (/_| _\  . (for UI & viewing things on etherscan)
    //=====_|=======================================================================

    function checkReferCode(string _affCode)
    public
    view
    returns(bool)
    {

        if (referMap_[_affCode] != 0)
            return true;
        else
            return false;
    }

    function getReferCode(address _addr)
    public
    view
    returns(string)
    {
        return plyrs_[_addr].referCode;
    }

    function setReferCode(address _addr, string _referCode)
    public
    {
        plyrs_[_addr].referCode = _referCode;
    }
    /**
     * @dev return the price buyer will pay for next 1 individual key.
     * -functionhash- 0x018a25e8
     * @return price for next key bought (in wei format)
     */
    function getBuyPrice()
    public
    view
    returns(uint256)
    {

        // grab time
        uint256 _now = now;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // are we in a round?
        if (_ethDec > _ethInc)
            return ( (keys_.add(1000000000000000000)).ethRec(1000000000000000000) );
        else {
            // rounds over.  need price for new round
            return ( 75000000000000 ); // init
        }
    }


    /**
     * @dev returns player earnings per vaults
     * -functionhash- 0x63066434
     * @return winnings vault
     * @return general vault
     * @return affiliate vault
     */
    function getPlayerVaultsXAddr(address _addr)
    public
    view
    returns(uint256 ,uint256, uint256)
    {

        uint256 _ethDec = calculateEndEth(now);
        uint256 _ethInc = totalBalance_;

        // if round has ended.  but round end has not been run (so contract has not distributed winnings)
        if (_ethDec < _ethInc)
        {
//            if (end_ == false) {
//                Ddatasets.EventReturns memory _eventData_;
//                endRound(_eventData_);
//                end_ = true;
//                // TODO: calculate
//            }

            // if player is winner
            if (winner_[_addr] == true)
            {
                return
                (
                // TODO
                (plyrs_[_addr].win),
                (plyrs_[_addr].gen).add(  getPlayerVaultsHelperXAddr(_addr).sub(mask_)   ),
                plyrs_[_addr].aff
                );
                // if player is not the winåner
            } else {
                return
                (
                plyrs_[_addr].win,
                (plyrs_[_addr].gen).add(  getPlayerVaultsHelperXAddr(_addr).sub(mask_)  ),
                plyrs_[_addr].aff
                );
            }

            // if round is still going on, or round has ended and round end has been ran
        } else {
            return
            (
            plyrs_[_addr].win,
            (plyrs_[_addr].gen).add(calcUnMaskedEarningsXAddr(_addr)),
            plyrs_[_addr].aff
            );
        }
    }

    /**
     * solidity hates stack limits.  this lets us avoid that hate
     */
    function getPlayerVaultsHelperXAddr(address _addr)
    private
    view
    returns(uint256)
    {
        return(  ((((mask_).add(((pot_).mul(1000000000000000000)) / keys_)).mul(plyrs_[_addr].keys)) / 1000000000000000000)  );
    }

    /**
     * @dev returns player info based on address.  if no address is given, it will
     * use msg.sender
     * -functionhash- 0xee0b5d8b
     * @param _addr address of the player you want to lookup
     * @return player ID
     * @return player name
     * @return keys owned (current round)
     * @return winnings vault
     * @return general vault
     * @return affiliate vault
	 * @return player round eth
     */
    function getPlayerInfoByAddress(address _addr)
    public
    view
    returns(string, uint256, uint256, uint256, uint256, uint256)
    {

        if (_addr == address(0))
        {
            _addr == msg.sender;
        }

        return
        (
        plyrs_[_addr].name,                   //1
        plyrs_[_addr].keys,         //2
        plyrs_[_addr].win,                    //3
        (plyrs_[_addr].gen).add(calcUnMaskedEarningsXAddr(_addr)),       //4
        plyrs_[_addr].aff,                //5
        plyrs_[_addr].eth
        );
    }

    //==============================================================================
    //     _ _  _ _   | _  _ . _  .
    //    (_(_)| (/_  |(_)(_||(_  . (this + tools + calcs + modules = our softwares engine)
    //=====================_|=======================================================

    /**
     * not used by decentralism
     * @dev logic runs whenever a buy order is executed.  determines how to handle
     * incoming eth depending on if we are in an active round or not
     */
    function buyCoreNew(address _addr, address _affID, uint256 _eth, Ddatasets.EventReturns memory _eventData_)
    private
    {

        // grab time
        uint256 _now = now;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // if round is active
        if (end_ == false && _ethDec > _ethInc)
        {
            // call core
            coreNew(_addr, _eth, _affID, _eventData_);

            // if round is not active
        } else if (end_ == false){
            // check to see if end round needs to be ran
            end_ = true;

            _eventData_ = endRound(_eventData_);

            // put eth in players vault
            plyrs_[_addr].gen = plyrs_[_addr].gen.add(msg.value);

            // TODO
        } else {
            // put eth in players vault
            plyrs_[_addr].gen = plyrs_[_addr].gen.add(msg.value);

            // TODO what should be sent out
        }
    }

    /**
     * @dev logic runs whenever a reload order is executed.  determines how to handle
     * incoming eth depending on if we are in an active round or not
     */
    function reLoadCoreNew(address _addr, address _affID, uint256 _eth, Ddatasets.EventReturns memory _eventData_)
    private
    {

        // grab time
        uint256 _now = now;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // if round is active
        if (end_ == false && _ethDec > _ethInc)
        {
            // get earnings from all vaults and return unused to gen vault
            // because we use a custom safemath library.  this will throw if player
            // tried to spend more eth than they have.
            plyrs_[_addr].gen = withdrawEarningsXAddr(_addr).sub(_eth);

            // call core
            coreNew(_addr, _eth, _affID, _eventData_);

            // if round is end
        } else if (end_ == false) {
            // end the round (distributes pot) & start new round
            end_ = true;
            _eventData_ = endRound(_eventData_);


            // fire buy and distribute event
            emit Devents.onReLoadEnd
            (
                msg.sender,
                plyrs_[_addr].name,
                plyrs_[_addr].win,
                pot_
            );
        }
    }


    /**
     * @dev this is the core logic for any buy/reload that happens while a round
     * is live.
     */
    function coreNew(address _addr, uint256 _eth, address _affID, Ddatasets.EventReturns memory _eventData_)
    private
    {

        // early round eth limiter
        if (eth_ < 100000000000000000000 && plyrs_[_addr].eth.add(_eth) > 1000000000000000000)
        {
            uint256 _availableLimit = (1000000000000000000).sub(plyrs_[_addr].eth);
            uint256 _refund = _eth.sub(_availableLimit);
            plyrs_[_addr].gen = plyrs_[_addr].gen.add(_refund);
            _eth = _availableLimit;
        }

        // if eth left is greater than min eth allowed (sorry no pocket lint)
        if (_eth > 1000000000)
        {

            // mint the new keys
            uint256 _keys = (eth_).keysRec(_eth);

            // if they bought at least 1 whole key
            if (_keys >= 1000000000000000000)
            {
                accDelay_ = accDelay_.add(delay_);

                // set the new leader bool to true
                _eventData_.compressedData = _eventData_.compressedData + 100;
            }

            // update player
            plyrs_[_addr].keys = _keys.add(plyrs_[_addr].keys);
            plyrs_[_addr].eth = _eth.add(plyrs_[_addr].eth);

            // update global
            keys_ = _keys.add(keys_);
            totalBalance_ = _eth.add(totalBalance_);

            // distribute eth
            _eventData_ = distributeExternalNew(_addr, _eth, _affID, _eventData_);
            _eventData_ = distributeInternalNew(_addr, _eth, _keys, _eventData_);

            // call end tx function to fire end tx event.
            endTxNew(_addr, _eth, _keys, _eventData_);
        }
    }

    //==============================================================================
    //     _ _ | _   | _ _|_ _  _ _  .
    //    (_(_||(_|_||(_| | (_)| _\  .
    //==============================================================================

    /**
     * @dev calculates unmasked earnings (just calculates, does not update mask)
     * @return earnings in wei format
     */
    function calcUnMaskedEarningsXAddr(address _addr)
    private
    view
    returns(uint256)
    {
        return(  (((mask_).mul(plyrs_[_addr].keys)) / (1000000000000000000)).sub(plyrs_[_addr].mask) );
    }

    /**
     * @dev returns the amount of keys you would get given an amount of eth.
     * -functionhash- 0xce89c80c
     * @param _eth amount of eth sent in
     * @return keys received
     */
    function calcKeysReceivedNew(uint256 _eth)
    public
    view
    returns(uint256)
    {
        // grab time
        uint256 _now = now;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // are we in a round?
        if (end_ == false && _ethDec > _ethInc)
            return ( (totalBalance_).keysRec(_eth) );
        else // rounds over.  need keys for new round
            return ( (_eth).keys() );
    }

    /**
     * @dev returns current eth price for X keys.
     * -functionhash- 0xcf808000
     * @param _keys number of keys desired (in 18 decimal format)
     * @return amount of eth needed to send
     */
    function iWantXKeysNew(uint256 _keys)
    public
    view
    returns(uint256)
    {

        // grab time
        uint256 _now = now;

        uint256 _ethDec = calculateEndEth(_now);
        uint256 _ethInc = totalBalance_;

        // are we in a round?
        if (end_ == false && _ethDec > _ethInc)
            return ( (keys_.add(_keys)).ethRec(_keys) );
        else // rounds over.  need price for new round
            return ( (_keys).eth() );
    }

    function calculateEndEth(uint256 time) public view returns (uint256) {
        uint256 T = time - startTime_;
        uint256 D;
        uint256 _now = now;
        uint _localAccDelay = accDelay_;
        if(_localAccDelay == 0) {
            D = 0; // now is larger than time of purchasing
        }else{
            D = (_localAccDelay.sub(_now.sub(time)))/2;
        }
        return (((initEth_).mul(1000000000000000000)).mul((T).add(1)))/(((T).add(D)).add(1));
    }

    // Get at lease three winners
    // So there might be more than three winners
    function getWinner() internal returns(address[]) {
        uint initiCount_ = 0;
        for(uint256 i = 0; i < addressIndexes.length; i++) {
            uint256 priceDiff_;
            address playerAddr_ = addressIndexes[i];
            Ddatasets.Player memory player_ = plyrs_[playerAddr_];

            for(uint j=0;j<player_.est.length;j++){

                if(totalBalance_ > player_.est[j]){
                    priceDiff_ = totalBalance_ - player_.est[j];
                }else{
                    priceDiff_ = player_.est[j] - totalBalance_;
                }

                if (initiCount_==0) {
                    winnerGroup3_.addr.push(player_.addr);
                    winnerGroup3_.price = priceDiff_;
                    initiCount_++;
                }else if (initiCount_==1) {
                    initiCount_++;
                    if(priceDiff_==winnerGroup3_.price){
                        winnerGroup3_.addr.push(player_.addr);
                    }else if(priceDiff_>winnerGroup3_.price){
                        //                        Ddatasets.WinnerGroup tempGroup_;
                        //                        tempGroup_.addr.push(player_.addr);
                        //                        tempGroup_.price = priceDiff_;
                        // not sure about object copy
                        winnerGroup2_.addr = winnerGroup3_.addr;
                        winnerGroup2_.price = winnerGroup3_.price;
                        winnerGroup3_.addr.length = 0;
                        winnerGroup3_.addr.push(player_.addr);
                        winnerGroup3_.price = priceDiff_;
                    }else{
                        winnerGroup2_.addr.push(player_.addr);
                        winnerGroup2_.price = priceDiff_;
                    }
                } else if (initiCount_==2) {
                    initiCount_++;
                    if(priceDiff_==winnerGroup3_.price){
                        winnerGroup3_.addr.push(player_.addr);
                    }else if(priceDiff_>winnerGroup3_.price){
                        //                        Ddatasets.WinnerGroup tempGroup_;
                        //                        tempGroup_.addr.push(player_.addr);
                        //                        tempGroup_.price = priceDiff_;
                        winnerGroup2_.addr = winnerGroup3_.addr;
                        winnerGroup2_.price = winnerGroup3_.price;
                        winnerGroup3_.addr.length = 0;
                        winnerGroup3_.addr.push(player_.addr);
                        winnerGroup3_.price = priceDiff_;
                    }else if(priceDiff_<winnerGroup3_.price && priceDiff_>winnerGroup2_.price){
                        //                        Ddatasets.WinnerGroup tempGroup_;
                        //                        tempGroup_.addr.push(player_.addr);
                        //                        tempGroup_.price = priceDiff_;
                        winnerGroup1_.addr = winnerGroup2_.addr;
                        winnerGroup1_.price = winnerGroup2_.price;
                        winnerGroup2_.addr.length = 0;
                        winnerGroup2_.addr.push(player_.addr);
                        winnerGroup2_.price = priceDiff_;
                    }else if(priceDiff_==winnerGroup2_.price){
                        winnerGroup2_.addr.push(player_.addr);
                    }else{
                        winnerGroup1_.addr.push(player_.addr);
                        winnerGroup1_.price = priceDiff_;
                    }
                } else {
                    if(priceDiff_==winnerGroup3_.price){
                        winnerGroup3_.addr.push(player_.addr);
                    }else if(priceDiff_<winnerGroup3_.price && priceDiff_>winnerGroup2_.price){
                        winnerGroup3_.addr.length = 0;
                        winnerGroup3_.addr.push(player_.addr);
                        winnerGroup3_.price = priceDiff_;
                    }else if(priceDiff_==winnerGroup2_.price){
                        winnerGroup2_.addr.push(player_.addr);
                    }else if(priceDiff_<winnerGroup2_.price && priceDiff_>winnerGroup1_.price){
                        winnerGroup3_.addr = winnerGroup2_.addr;
                        winnerGroup3_.price = winnerGroup2_.price;
                        winnerGroup2_.addr.length = 0;
                        winnerGroup2_.addr.push(player_.addr);
                        winnerGroup2_.price = priceDiff_;
                    }else if(priceDiff_==winnerGroup1_.price){
                        winnerGroup1_.addr.push(player_.addr);
                    }else{
                        winnerGroup3_.addr = winnerGroup2_.addr;
                        winnerGroup3_.price = winnerGroup2_.price;
                        winnerGroup2_.addr = winnerGroup1_.addr;
                        winnerGroup2_.price = winnerGroup1_.price;
                        winnerGroup1_.addr.length = 0;
                        winnerGroup1_.addr.push(player_.addr);
                        winnerGroup1_.price = priceDiff_;
                    }
                }
            }
        }

        return (selectAddress());

    }

    // evenly giving the money to winners
    function distributePotToWinner(address[] _winners, uint256 _eth) public{
        uint256 _amount = _eth / _winners.length;
        for(uint256 i = 0; i < _winners.length; i++){
            winner_[_winners[i]] = true;
            plyrs_[_winners[i]].win += _amount;
        }
    }

    // select all address from winner group
    // there might be three winners
    function selectAddress()
    public
    returns(address[])
    {

        if(winnerGroup3_.addr.length == 0) { // nobody played
            return _result;
        } else if(winnerGroup2_.addr.length == 0) { // G2 has nothing means only has one group winner, will happen in a scenario that only a price is in place and all players place this price

            for(uint256 i = 0; i < winnerGroup3_.addr.length; i++) {

                _result.push(winnerGroup3_.addr[i]);
            }

            return _result;

        } else if(winnerGroup1_.addr.length == 0) {

            for(i = 0; i < winnerGroup2_.addr.length; i++) {

                _result.push(winnerGroup2_.addr[i]);
            }

            if(_result.length > 3) {
                return _result;
            }

            for(i = 0; i < winnerGroup3_.addr.length; i++) {

                _result.push(winnerGroup3_.addr[i]);
            }

            return _result;
        }


        for(i = 0; i < winnerGroup1_.addr.length; i++) {

            _result.push(winnerGroup1_.addr[i]);
        }

        // After pushing winner group1, if there are more than 3 candidates already, quit
        if(_result.length > 3) {
            return _result;
        }

        for(i = 0; i < winnerGroup2_.addr.length; i++) {

            _result.push(winnerGroup2_.addr[i]);
        }

        // DITTO
        if(_result.length > 3) {
            return _result;
        }

        for(i = 0; i < winnerGroup3_.addr.length; i++) {

            _result.push(winnerGroup3_.addr[i]);
        }


        return _result;
    }

    //==============================================================================
    //    _|_ _  _ | _  .
    //     | (_)(_)|_\  .
    //==============================================================================

    /**
     * @dev ends the round. manages paying out winner/splitting up pot
     */
    function endRound(Ddatasets.EventReturns memory _eventData_)
    private
    returns (Ddatasets.EventReturns)
    {
        // get winners first
        address[] memory winners = getWinner();

        // grab our pot amount
        uint256 _pot = pot_;

        // calculate our winner share, community rewards, gen share,
        // p3d share, and amount reserved for next pot
        uint256 _win = (_pot.mul(90)) / 100;

        // TODO: how to design the community in this contract
        com_ = (_pot.mul(10)) / 100;

        distributePotToWinner(winners, _win);
        _eventData_.potAmount = pot_;

        return(_eventData_);
    }

    /**
     * @dev moves any unmasked earnings to gen vault.  updates earnings mask
     */
    function updateGenVaultXAddr(address _addr)
    private
    {
        uint256 _earnings = calcUnMaskedEarningsXAddr(_addr);
        if (_earnings > 0)
        {
            // put in gen vault
            plyrs_[_addr].gen = _earnings.add(plyrs_[_addr].gen);
            // zero out their earnings by updating mask
            plyrs_[_addr].mask = _earnings.add(plyrs_[_addr].mask);
        }
    }

    /**
     * @dev distributes eth based on fees to com, aff, and p3d
     */
    function distributeExternalNew(address _addr, uint256 _eth, address _affID, Ddatasets.EventReturns memory _eventData_)
    private
    returns(Ddatasets.EventReturns)
    {

        // distribute share to affiliate
        uint256 _aff = _eth / 10;

        // decide what to do with affiliate share of fees
        // affiliate must not be self, and must have a name registered
        if (_affID != _addr && plyrs_[_affID].addr != address(0)) {
            plyrs_[_affID].aff = _aff.add(plyrs_[_affID].aff);
            plyrs_[_addr].aff = _aff.add(plyrs_[_addr].aff);

            // TODO
            emit Devents.onAffiliatePayout(_affID, plyrs_[_affID].name, _aff, now);
            // TODO : change the format of events
        } else {

            // put it to pot_ if no refer information provided
            pot_ = pot_.add(_aff.mul(2));
        }

        // distribute gen share (thats what updateMasks() does) and adjust
        // balances for dust.
        //        uint256 _dust = updateMasksXAddr(_addr, _gen, _keys);
        //        if (_dust > 0)
        //            _gen = _gen.sub(_dust);

        return(_eventData_);
    }

    /**
     * @dev distributes eth based on fees to gen and pot
     */
    function distributeInternalNew(address _addr, uint256 _eth, uint256 _keys, Ddatasets.EventReturns memory _eventData_)
    private
    returns(Ddatasets.EventReturns)
    {

        uint256 _now = now;
        uint256 T = _now - startTime_;
        uint256 D;
        if(accDelay_ == 0) {
            D = 0; // now is larger than time of purchasing
        }else{
            D = (accDelay_.sub(now.sub(_now)))/2;
        }

        // calculate pot
        uint256 _pot = _eth .mul(((((((60).mul(1000000000000000000)).mul((T).add(1)))/(((T).add(D)).add(1))).add(10)) / 100 ));
        uint256 _gen = _eth .mul(((80).sub((((((60).mul(1000000000000000000)).mul((T).add(1)))/(((T).add(D)).add(1))).add(10))) / 100 ));

        _eth = _eth.sub(_pot);

        // distribute gen share (thats what updateMasks() does) and adjust
        // balances for dust.
        uint256 _dust = updateMasksXAddr(_addr, _gen, _keys);
        if (_dust > 0)
            _eth = _eth.sub(_dust);

        // add eth to pot
        pot_ = _pot.add(_dust.add(pot_));

        // set up event data
        _eventData_.potAmount = _pot;

        return(_eventData_);
    }

    /**
     * @dev updates masks for round and player when keys are bought
     * @return dust left over
     */
    function updateMasksXAddr(address _addr, uint256 _gen, uint256 _keys)
    private
    returns(uint256)
    {
        /* MASKING NOTES
            earnings masks are a tricky thing for people to wrap their minds around.
            the basic thing to understand here.  is were going to have a global
            tracker based on profit per share for each round, that increases in
            relevant proportion to the increase in share supply.

            the player will have an additional mask that basically says "based
            on the rounds mask, my shares, and how much i've already withdrawn,
            how much is still owed to me?"
        */

        // calc profit per key & round mask based on this buy:  (dust goes to pot)
        uint256 _ppt = (_gen.mul(1000000000000000000) / keys_);
        mask_ = _ppt.add(mask_);

        // calculate player earning from their own buy (only based on the keys
        // they just bought).  & update player earnings mask
        uint256 _pearn = (_ppt.mul(_keys)) / (1000000000000000000);
        plyrs_[_addr].mask = (((mask_.mul(_keys)) / (1000000000000000000)).sub(_pearn)).add(plyrs_[_addr].mask);

        // calculate & return dust
        return(_gen.sub((_ppt.mul(keys_)) / (1000000000000000000)));
    }

    /**
     * @dev adds up unmasked earnings, & vault earnings, sets them all to 0
     * @return earnings in wei format
     */
    function withdrawEarningsXAddr(address _addr)
    private
    returns(uint256)
    {
        // update gen vault
        updateGenVaultXAddr(_addr);

        // from vaults
        uint256 _earnings = (plyrs_[_addr].win).add(plyrs_[_addr].gen).add(plyrs_[_addr].aff);
        if (_earnings > 0)
        {
            plyrs_[_addr].win = 0;
            plyrs_[_addr].gen = 0;
            plyrs_[_addr].aff = 0;
        }

        return(_earnings);
    }

    /**
     * @dev prepares compression data and fires event for buy or reload tx's
     */
    function endTxNew(address _addr, uint256 _eth, uint256 _keys, Ddatasets.EventReturns memory _eventData_)
    private
    {

        emit Devents.onEndTx
        (
            plyrs_[_addr].name,
            msg.sender,
            _eth,
            _keys,
            _eventData_.potAmount
        );
    }

    /**
     * @dev registers a name.  UI will always display the last name you registered.
     * but you will still own all previously registered names to use as affiliate
     * links.
     * - must pay a registration fee.
     * - name must be unique
     * - names will be converted to lowercase
     * - name cannot start or end with a space
     * - cannot have more than 1 space in a row
     * - cannot be only numbers
     * - cannot start with 0x
     * - name must be at least 1 char
     * - max length of 32 characters long
     * - allowed characters: a-z, 0-9, and space
     * -functionhash- 0x921dec21 (using ID for affiliate)
     * -functionhash- 0x3ddd4698 (using address for affiliate)
     * -functionhash- 0x685ffd83 (using name for affiliate)
     * @param _nameString players desired name
     * @param _affCode affiliate ID, address, or name of who refered you
     * (this might cost a lot of gas)
     */
    function registerIDFromDapp(string _nameString, string _affCode, string _selfReferCode)
    isHuman()
    private
    returns (bool,address)
    {

        // filter name + condition checks
//        bytes32 _id = NameFilter.nameFilter(_nameString);

        // set up address
        address _addr = msg.sender;

        // set up our tx event data and determine if player is new or not
        bool _isNewPlayer = false;

        if (plyrs_[_addr].addr == address(0))
        {
            _isNewPlayer = true;
        }

        // we allow player to change their names
        plyrs_[_addr].name = _nameString;
        plyrs_[_addr].addr = _addr;
        plyrs_[_addr].referCode = _selfReferCode;

        // check referMap_
        address _affAddr = referMap_[_affCode];

        // manage affiliate residuals
        // if no affiliate code was given, no new affiliate code was given, or the
        // player tried to use their own pID as an affiliate code, lolz
        if (_affAddr != 0 && _affAddr != plyrs_[_addr].laff && _affAddr != _addr)
        {
            // update last affiliate
            plyrs_[_addr].laff = _affAddr;
        } else if (_affAddr == _addr) {
            _affAddr = 0;
        }

        return (_isNewPlayer, _affAddr);
    }

}

//==============================================================================
//   __|_ _    __|_ _  .
//  _\ | | |_|(_ | _\  .
//==============================================================================
library Ddatasets {
    //compressedData key
    // [76-33][32][31][30][29][28-18][17][16-6][5-3][2][1][0]
    // 0 - new player (bool)
    // 1 - joined round (bool)
    // 2 - new  leader (bool)
    // 3-5 - air drop tracker (uint 0-999)
    // 6-16 - round end time
    // 17 - winnerTeam
    // 18 - 28 timestamp
    // 29 - team
    // 30 - 0 = reinvest (round), 1 = buy (round), 2 = buy (ico), 3 = reinvest (ico)
    // 31 - airdrop happened bool
    // 32 - airdrop tier
    // 33 - airdrop amount won
    //compressedIDs key
    // [77-52][51-26][25-0]
    // 0-25 - pID
    // 26-51 - winPID
    // 52-77 - rID
    struct EventReturns {
        uint256 compressedData;
        uint256 compressedIDs;
        uint256 potAmount;          // amount added to pot
    }
    struct Player {
        address addr;   // player address
        string name;      // player name
        uint256 win;    // winnings vault
        uint256 gen;    // general vault
        uint256 aff;    // affiliate vault
        address laff;   // last affiliate id that refer this player
        uint256 mask;
        uint256 keys;
        uint256[] est;
        uint256 eth;
        string referCode; // player's refer code that sent to other players
    }

}

//==============================================================================
//  |  _      _ _ | _  .
//  |<(/_\/  (_(_||(_  .
//=======/======================================================================
library DKeysCalc {
    using SafeMath for *;
    /**
     * @dev calculates number of keys received given X eth
     * @param _curEth current amount of eth in contract
     * @param _newEth eth being spent
     * @return amount of ticket purchased
     */
    function keysRec(uint256 _curEth, uint256 _newEth)
    internal
    pure
    returns (uint256)
    {
        return(keys((_curEth).add(_newEth)).sub(keys(_curEth)));
    }

    /**
     * @dev calculates amount of eth received if you sold X keys
     * @param _curKeys current amount of keys that exist
     * @param _sellKeys amount of keys you wish to sell
     * @return amount of eth received
     */
    function ethRec(uint256 _curKeys, uint256 _sellKeys)
    internal
    pure
    returns (uint256)
    {
        return((eth(_curKeys)).sub(eth(_curKeys.sub(_sellKeys))));
    }

    /**
     * @dev calculates how many keys would exist with given an amount of eth
     * @param _eth eth "in contract"
     * @return number of keys that would exist
     */
    function keys(uint256 _eth)
    internal
    pure
    returns(uint256)
    {
        return ((((((_eth).mul(1000000000000000000)).mul(312500000000000000000000000)).add(5624988281256103515625000000000000000000000000000000000000000000)).sqrt()).sub(74999921875000000000000000000000)) / (156250000);
    }

    /**
     * @dev calculates how much eth would be in contract given a number of keys
     * @param _keys number of keys "in contract"
     * @return eth that would exists
     */
    function eth(uint256 _keys)
    internal
    pure
    returns(uint256)
    {
        return ((78125000).mul(_keys.sq()).add(((149999843750000).mul(_keys.mul(1000000000000000000))) / (2))) / ((1000000000000000000).sq());
    }
}

/**
* @title -Name Filter- v0.1.9
* ┌┬┐┌─┐┌─┐┌┬┐   ╦╦ ╦╔═╗╔╦╗  ┌─┐┬─┐┌─┐┌─┐┌─┐┌┐┌┌┬┐┌─┐
*  │ ├┤ ├─┤│││   ║║ ║╚═╗ ║   ├─┘├┬┘├┤ └─┐├┤ │││ │ └─┐
*  ┴ └─┘┴ ┴┴ ┴  ╚╝╚═╝╚═╝ ╩   ┴  ┴└─└─┘└─┘└─┘┘└┘ ┴ └─┘
*                                  _____                      _____
*                                 (, /     /)       /) /)    (, /      /)          /)
*          ┌─┐                      /   _ (/_      // //       /  _   // _   __  _(/
*          ├─┤                  ___/___(/_/(__(_/_(/_(/_   ___/__/_)_(/_(_(_/ (_(_(_
*          ┴ ┴                /   /          .-/ _____   (__ /
*                            (__ /          (_/ (, /                                      /)™
*                                                 /  __  __ __ __  _   __ __  _  _/_ _  _(/
* ┌─┐┬─┐┌─┐┌┬┐┬ ┬┌─┐┌┬┐                          /__/ (_(__(_)/ (_/_)_(_)/ (_(_(_(__(/_(_(_
* ├─┘├┬┘│ │ │││ ││   │                      (__ /              .-/  © Jekyll Island Inc. 2018
* ┴  ┴└─└─┘─┴┘└─┘└─┘ ┴                                        (_/
*              _       __    _      ____      ____  _   _    _____  ____  ___
*=============| |\ |  / /\  | |\/| | |_ =====| |_  | | | |    | |  | |_  | |_)==============*
*=============|_| \| /_/--\ |_|  | |_|__=====|_|   |_| |_|__  |_|  |_|__ |_| \==============*
*
* ╔═╗┌─┐┌┐┌┌┬┐┬─┐┌─┐┌─┐┌┬┐  ╔═╗┌─┐┌┬┐┌─┐ ┌──────────┐
* ║  │ ││││ │ ├┬┘├─┤│   │   ║  │ │ ││├┤  │ Inventor │
* ╚═╝└─┘┘└┘ ┴ ┴└─┴ ┴└─┘ ┴   ╚═╝└─┘─┴┘└─┘ └──────────┘
*/

library NameFilter {
    /**
     * @dev filters name strings
     * -converts uppercase to lower case.
     * -makes sure it does not start/end with a space
     * -makes sure it does not contain multiple spaces in a row
     * -cannot be only numbers
     * -cannot start with 0x
     * -restricts characters to A-Z, a-z, 0-9, and space.
     * @return reprocessed string in bytes32 format
     */
    function nameFilter(string _input)
    internal
    pure
    returns(bytes32)
    {
        bytes memory _temp = bytes(_input);
        uint256 _length = _temp.length;

        //sorry limited to 32 characters
        require (_length <= 32 && _length > 0, "string must be between 1 and 32 characters");
        // make sure it doesnt start with or end with space
        require(_temp[0] != 0x20 && _temp[_length-1] != 0x20, "string cannot start or end with space");
        // make sure first two characters are not 0x
        if (_temp[0] == 0x30)
        {
            require(_temp[1] != 0x78, "string cannot start with 0x");
            require(_temp[1] != 0x58, "string cannot start with 0X");
        }

        // create a bool to track if we have a non number character
        bool _hasNonNumber;

        // convert & check
        for (uint256 i = 0; i < _length; i++)
        {
            // if its uppercase A-Z
            if (_temp[i] > 0x40 && _temp[i] < 0x5b)
            {
                // convert to lower case a-z
                _temp[i] = byte(uint(_temp[i]) + 32);

                // we have a non number
                if (_hasNonNumber == false)
                    _hasNonNumber = true;
            } else {
                require
                (
                // require character is a space
                    _temp[i] == 0x20 ||
                // OR lowercase a-z
                (_temp[i] > 0x60 && _temp[i] < 0x7b) ||
                // or 0-9
                (_temp[i] > 0x2f && _temp[i] < 0x3a),
                    "string contains invalid characters"
                );
                // make sure theres not 2x spaces in a row
                if (_temp[i] == 0x20)
                    require( _temp[i+1] != 0x20, "string cannot contain consecutive spaces");

                // see if we have a character other than a number
                if (_hasNonNumber == false && (_temp[i] < 0x30 || _temp[i] > 0x39))
                    _hasNonNumber = true;
            }
        }

        require(_hasNonNumber == true, "string cannot be only numbers");

        bytes32 _ret;
        assembly {
            _ret := mload(add(_temp, 32))
        }
        return (_ret);
    }
}

/**
 * @title SafeMath v0.1.9
 * @dev Math operations with safety checks that throw on error
 * change notes:  original SafeMath library from OpenZeppelin modified by Inventor
 * - added sqrt
 * - added sq
 * - added pwr
 * - changed asserts to requires with error log outputs
 * - removed div, its useless
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b, "SafeMath mul failed");
        return c;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b)
    internal
    pure
    returns (uint256)
    {
        require(b <= a, "SafeMath sub failed");
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b)
    internal
    pure
    returns (uint256 c)
    {
        c = a + b;
        require(c >= a, "SafeMath add failed");
        return c;
    }

    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
    internal
    pure
    returns (uint256 y)
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y)
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }

    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
    internal
    pure
    returns (uint256)
    {
        return (mul(x,x));
    }

    /**
     * @dev x to the power of y
     */
    function pwr(uint256 x, uint256 y)
    internal
    pure
    returns (uint256)
    {
        if (x==0)
            return (0);
        else if (y==0)
            return (1);
        else
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = mul(z,x);
            return (z);
        }
    }
}

