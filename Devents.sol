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
