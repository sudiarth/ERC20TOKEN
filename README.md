## Getting Started

Clone

```bash
git clone https://github.com/sudiarth/ERC20Token.git
```

You can start editing the page by modifying `contracts/Contract.sol`.

```solidity
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
```

Change `SudigitalLabsToken` to the name of your contract.

## Building the project

Install dependencies

```bash
pnpm install
```

After any changes to the contract, run:

Build the project

```bash
npx thirdweb build
```

to compile your contracts. This will also detect the [Contracts Extensions Docs](https://portal.thirdweb.com/contractkit) detected on your contract.

## Deploying Contracts

When you're ready to deploy your contracts, just run one of the following command to deploy you're contracts:

```bash
npx thirdweb deploy
```

## Releasing Contracts

If you want to release a version of your contracts publicly, you can use one of the followings command:

```bash
npx thirdweb release
```

## Join our Discord!
For any questions, suggestions, join our discord at

- Sudigital Labs: [https://discord.gg/xQsCkUnYxk](https://discord.gg/xQsCkUnYxk)
- ThirdWeb: [https://discord.gg/thirdweb](https://discord.gg/thirdweb)
