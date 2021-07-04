pragma solidity >=0.6.0 <0.7.0;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
//import "@openzeppelin/contracts/access/Ownable.sol";
//learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

// GET LISTED ON OPENSEA: https://testnets.opensea.io/get-listed/step-two

contract YourCollectible is ERC721, VRFConsumerBase {

    mapping (uint256 => address) public tokenRando;
    mapping (address => uint256) public bankLogic;

    bytes32 internal keyHash;
    uint256 internal fee;

    bool public diceRolled;
    uint256 public startingBlockNum = 0;
    uint256 public endingBlockNum = 10000;
    uint256 public totalTickets = 0;

    uint256 public randomResult;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    IERC20 private _token;

    event depositETH(address from, address to, uint256 amount);

    constructor (address token) public VRFConsumerBase(
      0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // VRF Coordinator
      0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // LINK Token
    )  ERC721("YourCollectible", "YCB") {
        _token = IERC20(token); // put in cETH contract address in deploy script
        _setBaseURI("https://ipfs.io/ipfs/");

        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }

  function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {
      require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
      return requestRandomness(keyHash, fee, userProvidedSeed);
  }

  function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
      randomResult = randomness;
    }

  function mintTickets() public virtual payable returns (uint256 _tokenId) {

    uint256 mintMultiplier = getMultiplier();
    require(block.number<endingBlockNum);
    require(bankLogic[msg.sender] != 1); // not sure if this is a valid check... assuming the address is unique it should never return 1 I think
    require(msg.value == 1 * 10 ** 18, "We only accept deposits of 1 ETH at this time");

    _token.mint(msg.value);

    for(uint256 i=0;i<mintMultiplier;i++){
      _tokenIds.increment();
      uint256 id = _tokenIds.current();
      tokenRando[id] = msg.sender;
    }

    bankLogic[msg.sender] = 1;  // sets a flag within bankLogic as false to signify that a deposit has been made

    emit depositETH(from, to, amount);

   }

  // Allows winner to claim ***Token URI fed in from the front end when clicking the button****
  function claimLottery(string memory tokenURI) public virtual returns (uint256) {  // NFT with "claim" button

    require(tokenRando[randomRoll] == msg.sender, ":( you did not win)");

    uint256 totalCETH = _token.balanceOf(address.this)
    _token.redeem(totalCETH);

    _tokenIds.increment();

    uint256 id = _tokenIds.current();
    _mint(msg.sender, id);
    _setTokenURI(id, tokenURI);

  }

  // Sets lottery ticket quantity
  function getMultiplier() public virtual view returns (uint256) {  // can be made more robust, not just static, but ok for now
      uint256 incrementMultipler = ((endingBlockNum - block.number) % 3000); // 5000 blocks a day; ~1 block mined every 15.5 seconds
      // run it for 3 days = 15000 blocks... set buckets of 3000 blocks

      if (incrementMultipler == 1) {  // elminates problems with deposits in the last bucket before the end of the lottery
        return 0;
      }
      return incrementMultipler;
  }

  // Dice roll
  function diceRoll() public virtual returns (uint256) {
    require(block.number > endingBlockNum, "Game not ended yet");
    require(diceRolled==false);
    diceRolled == true;

    uint256 randomRoll = uint256( (randomResult % totalTickets)+1 );
    return randomRoll;
  }

  function withdraw() public virtual returns (uint256) {
    require(block.number > endingBlockNum, "Game not ended yet");
    require(diceRolled == true);
    bankLogic[msg.sender] = 0;  // sets a flag within bankLogic as true to signify that a withdraw has been made
    transfer(msg.sender,1*10**18);

  }

}
