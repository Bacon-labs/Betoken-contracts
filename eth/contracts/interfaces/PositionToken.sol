pragma solidity 0.5.8;

// Fulcrum position token
interface PositionToken {
  function mintWithToken(
    address receiver,
    address depositTokenAddress,
    uint256 depositAmount)
    external
    returns (uint256);

  function burnToToken(
    address receiver,
    address burnTokenAddress,
    uint256 burnAmount)
    external
    returns (uint256);

  function tokenPrice()
   external
   view
   returns (uint256 price);

  function liquidationPrice()
   external
   view
   returns (uint256 price);

  function currentLeverage()
    external
    view
    returns (uint256 leverage);
}