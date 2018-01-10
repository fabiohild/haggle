pragma solidity ^0.4.18;

//import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/MintableToken.sol";
import "zeppelin-solidity/contracts/token/MintableToken.sol";

/**
 * @title Haggle coin
 * @dev Very simple ERC20 Token that can be minted.
 */
contract HaggleCoin is MintableToken {

    string public constant name = "Haggle Coin";
    string public constant symbol = "HAGL";
    uint8 public constant decimals = 18;

}
