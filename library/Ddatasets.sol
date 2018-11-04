pragma solidity ^0.4.24;
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
        uint256 eth;
        string referCode; // player's refer code that sent to other players
        PurchaseRecord[] records;
    }

    struct PurchaseRecord {
      address addr;
      uint256 est;
      uint256 time;
    }

}
