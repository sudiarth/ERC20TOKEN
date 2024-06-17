// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "./ERC20DropVote.sol";

contract SudigitalLabsToken is ERC20DropVote {
      constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address _primarySaleRecipient
    )
        ERC20DropVote(
            _defaultAdmin,
            _name,
            _symbol,
            _primarySaleRecipient
        )
    {}
}