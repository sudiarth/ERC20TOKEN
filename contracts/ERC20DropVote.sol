// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author thirdweb

import "@thirdweb-dev/contracts/external-deps/openzeppelin/token/ERC20/extensions/ERC20Votes.sol";

import "@thirdweb-dev/contracts/extension/interface/IMintableERC20.sol";
import "@thirdweb-dev/contracts/extension/interface/IBurnableERC20.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import { SignatureMintERC20 } from "@thirdweb-dev/contracts/extension/SignatureMintERC20.sol";

import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/Ownable.sol";
import "@thirdweb-dev/contracts/extension/PrimarySale.sol";
import "@thirdweb-dev/contracts/extension/DropSinglePhase.sol";

import { CurrencyTransferLib } from "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

/**
 *      BASE:      ERC20Votes
 *      EXTENSION: DropSinglePhase
 *
 *  The `ERC20Drop` contract uses the `DropSinglePhase` extensions, along with `ERC20Votes`.
 *  It implements the ERC20 standard, along with the following additions to standard ERC20 logic:
 *
 *      - Ownership of the contract, with the ability to restrict certain functions to
 *        only be called by the contract's owner.
 *
 *      - Multicall capability to perform multiple actions atomically
 *
 *      - EIP 2612 compliance: See {ERC20-permit} method, which can be used to change an account's ERC20 allowance by
 *                             presenting a message signed by the account.
 *
 *  The `drop` mechanism in the `DropSinglePhase` extension is a distribution mechanism tokens. It lets
 *  you set restrictions such as a price to charge, an allowlist etc. when an address atttempts to mint tokens.
 *
 */

contract ERC20DropVote is 
    ContractMetadata, 
    Multicall, 
    Ownable, 
    ERC20Votes, 
    IMintableERC20,
    IBurnableERC20,
    PermissionsEnumerable,
    SignatureMintERC20,
    PrimarySale, 
    DropSinglePhase {
    /*//////////////////////////////////////////////////////////////
                            Constructor
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address _primarySaleRecipient
    ) ERC20Permit(_name, _symbol) {
        _setupOwner(_defaultAdmin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupPrimarySaleRecipient(_primarySaleRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                            Minting logic
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice          Lets an authorized address mint tokens to a recipient.
     *  @dev             The logic in the `_canMint` function determines whether the caller is authorized to mint tokens.
     *
     *  @param _to       The recipient of the tokens to mint.
     *  @param _amount   Quantity of tokens to mint.
     */
    function mintTo(address _to, uint256 _amount) public virtual {
        require(_canMint(), "Not authorized to mint.");
        require(_amount != 0, "Minting zero tokens.");

        _mint(_to, _amount);
    }

    /**
     *  @notice          Lets an owner a given amount of their tokens.
     *  @dev             Caller should own the `_amount` of tokens.
     *
     *  @param _amount   The number of tokens to burn.
     */
    function burn(uint256 _amount) external virtual {
        require(balanceOf(msg.sender) >= _amount, "not enough balance");
        _burn(msg.sender, _amount);
    }

    /**
     *  @notice          Lets an owner burn a given amount of an account's tokens.
     *  @dev             `_account` should own the `_amount` of tokens.
     *
     *  @param _account  The account to burn tokens from.
     *  @param _amount   The number of tokens to burn.
     */
    function burnFrom(address _account, uint256 _amount) external virtual override {
        require(_canBurn(), "Not authorized to burn.");
        require(balanceOf(_account) >= _amount, "not enough balance");
        uint256 decreasedAllowance = allowance(_account, msg.sender) - _amount;
        _approve(_account, msg.sender, 0);
        _approve(_account, msg.sender, decreasedAllowance);
        _burn(_account, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                        Signature minting logic
    //////////////////////////////////////////////////////////////*/

    /**
     *  @notice           Mints tokens according to the provided mint request.
     *
     *  @param _req       The payload / mint request.
     *  @param _signature The signature produced by an account signing the mint request.
     */
    function mintWithSignature(
        MintRequest calldata _req,
        bytes calldata _signature
    ) external payable virtual returns (address signer) {
        require(_req.quantity > 0, "Minting zero tokens.");

        // Verify and process payload.
        signer = _processRequest(_req, _signature);

        address receiver = _req.to;

        // Collect price
        _collectPriceOnClaim(_req.primarySaleRecipient, _req.currency, _req.price);

        // Mint tokens.
        _mint(receiver, _req.quantity);

        emit TokensMintedWithSignature(signer, receiver, _req);
    }

    /*//////////////////////////////////////////////////////////////
                        Internal (overrideable) functions
    //////////////////////////////////////////////////////////////*/

    /// @dev Returns whether a given address is authorized to sign mint requests.
    function _canSignMintRequest(address _signer) internal view virtual override returns (bool) {
        return _signer == owner();
    }

    /// @dev Collects and distributes the primary sale value of tokens being claimed.
    function _collectPriceOnClaim(address _primarySaleRecipient, address _currency, uint256 _price) internal virtual {
        if (_price == 0) {
            require(msg.value == 0, "!Value");
            return;
        }

        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            require(msg.value == _price, "Must send total price.");
        } else {
            require(msg.value == 0, "msg value not zero");
        }

        address saleRecipient = _primarySaleRecipient == address(0) ? primarySaleRecipient() : _primarySaleRecipient;
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, saleRecipient, _price);
    }

    /// @dev Collects and distributes the primary sale value of tokens being claimed.
    function _collectPriceOnClaim(
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    ) internal virtual override {
        if (_pricePerToken == 0) {
            require(msg.value == 0, "!Value");
            return;
        }

        uint256 totalPrice = (_quantityToClaim * _pricePerToken) / 1 ether;
        require(totalPrice > 0, "quantity too low");

        bool validMsgValue;
        if (_currency == CurrencyTransferLib.NATIVE_TOKEN) {
            validMsgValue = msg.value == totalPrice;
        } else {
            validMsgValue = msg.value == 0;
        }
        require(validMsgValue, "Invalid msg value");

        address saleRecipient = _primarySaleRecipient == address(0) ? primarySaleRecipient() : _primarySaleRecipient;
        CurrencyTransferLib.transferCurrency(_currency, msg.sender, saleRecipient, totalPrice);
    }

    /// @dev Transfers the tokens being claimed.
    function _transferTokensOnClaim(
        address _to,
        uint256 _quantityBeingClaimed
    ) internal virtual override returns (uint256) {
        _mint(_to, _quantityBeingClaimed);
        return 0;
    }

    /// @dev Checks whether platform fee info can be set in the given execution context.
    function _canSetClaimConditions() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns whether contract metadata can be set in the given execution context.
    function _canSetContractURI() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns whether tokens can be minted in the given execution context.
    function _canMint() internal view virtual returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns whether tokens can be burned in the given execution context.
    function _canBurn() internal view virtual returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns whether owner can be set in the given execution context.
    function _canSetOwner() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    /// @dev Returns whether primary sale recipient can be set in the given execution context.
    function _canSetPrimarySaleRecipient() internal view virtual override returns (bool) {
        return msg.sender == owner();
    }

    /// @notice Returns the sender in the given execution context.
    function _msgSender() internal view override(Multicall, Context) returns (address) {
        return msg.sender;
    }
}