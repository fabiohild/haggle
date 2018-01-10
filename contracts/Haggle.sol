pragma solidity ^0.4.18;

import "./AccessControl.sol";

/// @title Haggle Sale contract, governs the sale process with escrow.
contract HaggleSale {
  uint public DIN;
  uint public price;
  uint public quantity;
  address public buyer;
  address public seller;
  address public coinContract;
  uint public status = 0;
  // 0 - sale contract created
  // 1 - sale contract confirmed by seller
  // 2 - item shipped
  // 3 - item delivered
  // 4 - return requested
  // 5 - final
  // 6 - cancelled

  // events
  event LogSaleEvent(string description, uint status, uint timestamp);

  // Constructor
  function HaggleSale(
      uint _DIN,
      uint _price, // ETH
      uint _quantity,
      address _buyer,
      address _seller,
      address _coinContract
  ) public {
      DIN = _DIN;
      price = _price;
      quantity = _quantity;
      buyer = _buyer;
      seller = _seller;
      coinContract = _coinContract;
  }

  // Change status to Confirmed
  function ConfirmOrder() public {
    require(msg.sender == seller);
    ERC20 tokenContract = ERC20(coinContract);
    require(this.balance > (price * 9)/10 || tokenContract.balanceOf(this) > (price * 9)/10 );

    // update status
    status = 1;
  }

  // Change status to Shipped
  function ShippedOrder() public {
    require(msg.sender == seller);
    require(status == 1);

    // update status
    status = 2;
  }

  // Change status to Delivered
  function DeliveredOrder() public {
    require(msg.sender == seller);
    require(status == 2);
    // update status
    status = 3;
  }

  // Change status to Returned
  function ReturnedOrder() public {
    require(msg.sender == buyer);
    require(status == 1 || status == 2);
    // update status
    status = 4;
  }

  // Change status to Final
  function FinishOrder() public {
    require(status == 4 || status == 3 || status == 2);
    if(msg.sender == buyer && (status == 2 || status == 3))
        // sends balance to to seller
        _DrainBalance(seller);
    if(msg.sender == seller && (status == 2 || status == 3))
        // sends balance to to buyer
        _DrainBalance(buyer);

  }

  function _DrainBalance(address _dest) private {
      status = 5;
      if(this.balance > 0)
        _dest.transfer(this.balance);

        ERC20 tokenContract = ERC20(coinContract);
        tokenContract.transfer(_dest, tokenContract.balanceOf(this));

  }

  // Cancel sale (only buyer if not confirmed, seller if not shipped, refunds user)
  function CancelOrder() public {
    require(msg.sender == buyer && status == 0);
    require(msg.sender == seller);

    // refunds buyer
    _DrainBalance(buyer);

    // update status
    status = 6;
  }

}

/// @title Haggle Item contract, creates sales contracts when deals are met.
contract HaggleItem{
  uint public DIN;
  uint public price;
  uint public quantity;
  address public owner;
  address public haggleAddress;

  event LogSale(address saleContract, uint DIN, uint price, address buyer, address seller, uint timestamp);

  // Constructor
  function HaggleItem(
      uint _DIN,
      uint _price, // ETH
      uint _quantity,
      address _retailer
  ) public {
      DIN = _DIN;
      price = _price;
      quantity = _quantity;
      owner = _retailer;
      haggleAddress = msg.sender;
  }

  // Buy Boosters with eth
  function buyItemEth(uint _orderQuantity) public payable {
      require(_orderQuantity >= quantity);
      require(msg.value == _orderQuantity * price);

      // creates sale contract and transfers value to it
      address saleAddress = _createSaleContract(_orderQuantity);
      saleAddress.transfer(msg.value);
  }

  // Buy Items with HAGL
  // Caller needs to approve transfer previously in coin's contract
  function buyItemHagl(uint _orderQuantity) public {
      // gets hagglerate and HAGL address from Haggle contract
      Haggle haggleContract = Haggle(haggleAddress);

      // checks if there is approval and transfer items;
      address coinContract = haggleContract.haggleCoinAddress();
      uint haglRate = haggleContract.haggleRate();

      ERC20 tokenContract = ERC20(coinContract);
      require(tokenContract.transferFrom(msg.sender, address(this), price * _orderQuantity * haglRate ));

      // creates sale contract and transfers value to it
      address saleAddress = _createSaleContract(_orderQuantity);
      tokenContract.transfer(saleAddress, price * _orderQuantity * haglRate);
  }

  // internal function to create sale contract
  function _createSaleContract(uint _orderQuantity) private returns ( address contractAddress ){
      Haggle haggleContract = Haggle(haggleAddress);
      address coinContract = haggleContract.haggleCoinAddress();
      address saleAddress = new HaggleSale(DIN, price, _orderQuantity, msg.sender, owner, coinContract);
      LogSale(saleAddress, DIN, price, msg.sender, owner, now);
      return saleAddress;
  }

  // haggle functions

}

/// @title Haggle main contract, creates items/sale contracts upon request.
contract Haggle is AccessControl {

    uint public haggleRate = 1000; // 0.001 ETH, bit less then 5 USD
    address public haggleCoinAddress;

    /// @dev Emited when an Item is created
    event LogHaggleItem(uint DIN, uint price, uint quantity, address owner, address itemAddress, uint timestamp);

    // fallback function, will run if ETH is sent to the contract
    // will send back boosterCoin to msg.sender
    // ensure conract owns enough HAGL
    function() public payable {
        require(msg.value > 0);

        // send back Haggle tokens
        ERC20 CoinContract = ERC20(haggleCoinAddress);
        uint coinAmount = msg.value  * haggleRate;
        CoinContract.transfer(msg.sender, coinAmount);
    }

    // Creates a new HaggleItem smart contract
    function createItemContract(uint _din, uint _price, uint _quantity) internal returns (HaggleItem) {
        address itemAddress = new HaggleItem(_din, _price, _quantity, msg.sender);
        // event
        LogHaggleItem(_din, _price, _quantity, msg.sender, itemAddress, now);
    }

    function changeCoinAddress ( address _newAddress ) public canAccess("changeCoinAddress") {
        haggleCoinAddress = _newAddress;
    }

    function changeHaglRate ( uint _newRate ) public canAccess("changeHAGLPrice") {
        haggleRate = _newRate;
    }
}
