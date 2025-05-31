RoyaltyFlow
===========

* * * * *

Overview
--------

I've designed **RoyaltyFlow** as an automated digital asset royalty system, specifically built to manage royalty distributions for NFT sales on the Stacks blockchain. This Clarity smart contract ensures that creators receive automatic payments whenever their NFTs are resold. It's built to be flexible, supporting multiple royalty beneficiaries with configurable percentages, and I've incorporated security features to mitigate common vulnerabilities.

Features
--------

-   **Automated Royalty Distribution**: Creators automatically receive a portion of the sale price on secondary NFT sales.
-   **Configurable Royalty Percentages**: The original creator can set a specific royalty percentage for their NFTs.
-   **Multiple Beneficiaries (Royalty Splits)**: Supports advanced royalty distribution schemes, allowing a creator to split royalties among various recipients with defined percentages.
-   **Security & Access Control**:
    -   Only the **contract owner** can pause/resume the contract.
    -   Only the **NFT creator** can set, update, or deactivate their NFT's royalty configuration and manage royalty splits.
    -   Input validations prevent invalid percentages or zero-value sales.
-   **Transparency**: All sales and royalty distributions are recorded on-chain and are publicly queryable.
-   **Error Handling**: Comprehensive error codes provide clear feedback for failed transactions.

Contract Details
----------------

### Constants

-   `CONTRACT-OWNER`: The deployer of the contract.
-   `ERR-NOT-AUTHORIZED (u100)`: Sender is not authorized for the action.
-   `ERR-INVALID-PERCENTAGE (u101)`: Royalty or split percentage is invalid (e.g., exceeds `MAX-ROYALTY-PERCENTAGE` or `BASIS-POINTS`).
-   `ERR-NFT-NOT-FOUND (u102)`: NFT royalty configuration does not exist.
-   `ERR-INSUFFICIENT-FUNDS (u103)`: Insufficient funds for transfer (though `stx-transfer?` typically handles this, it's a useful general error).
-   `ERR-ALREADY-EXISTS (u104)`: Royalty configuration for the NFT already exists.
-   `ERR-INVALID-RECIPIENT (u105)`: Invalid principal address for a recipient.
-   `ERR-TRANSFER-FAILED (u106)`: STX transfer failed.
-   `ERR-INVALID-PRICE (u107)`: Sale price is zero or negative.
-   `MAX-ROYALTY-PERCENTAGE (u1000)`: Maximum allowed royalty percentage (10% in basis points).
-   `BASIS-POINTS (u10000)`: Represents 100% in basis points.

### Data Maps and Variables

-   `contract-paused`: A boolean variable indicating if the contract is paused.
-   `total-royalties-distributed`: A `uint` tracking the total STX distributed as royalties.
-   `nft-royalties`: Maps `nft-id` to its royalty configuration, including `creator`, `royalty-percentage`, `is-active`, and `created-at`.
-   `nft-sales`: Maps `nft-id` and `sale-id` to sale details like `seller`, `buyer`, `sale-price`, `royalty-paid`, and `sale-timestamp`.
-   `nft-sale-counter`: Maps `nft-id` to a `counter` for tracking unique `sale-id`s.
-   `secondary-recipients`: Maps `nft-id` and `recipient` (principal) to their `percentage` of the royalty.

### Public Functions

-   `set-nft-royalty (nft-id uint, creator principal, royalty-percentage uint)`: Initializes the royalty configuration for a new NFT.
-   `process-nft-sale (nft-id uint, seller principal, buyer principal, sale-price uint)`: Records an NFT sale and distributes royalties to the creator (and secondary recipients if configured).
-   `update-royalty-percentage (nft-id uint, new-percentage uint)`: Allows the NFT creator to update their royalty percentage.
-   `deactivate-royalty (nft-id uint)`: Allows the NFT creator to deactivate royalty collection for their NFT.
-   `pause-contract ()`: Pauses the contract (owner only).
-   `resume-contract ()`: Resumes the contract (owner only).
-   `configure-royalty-splits (nft-id uint, recipients (list 10 { recipient: principal, split-percentage: uint }))`: Allows the NFT creator to set up or update how royalties are split among multiple beneficiaries.

### Read-Only Functions

-   `get-nft-royalty (nft-id uint)`: Retrieves the royalty configuration for a given NFT.
-   `get-sale-info (nft-id uint, sale-id uint)`: Retrieves details of a specific NFT sale.
-   `get-total-royalties-distributed ()`: Returns the cumulative amount of STX distributed as royalties by the contract.
-   `is-paused ()`: Checks if the contract is currently paused.

How to Use
----------

### For NFT Creators

1.  **Set Royalty**: Use `set-nft-royalty` to define the initial creator and royalty percentage for your NFT.
2.  **Update Royalty**: If needed, use `update-royalty-percentage` to change the royalty percentage.
3.  **Configure Splits**: If you want to share royalties with other parties, use `configure-royalty-splits` to define secondary recipients and their respective percentages.
4.  **Deactivate Royalty**: If you no longer wish to collect royalties for an NFT, use `deactivate-royalty`.

### For Marketplaces / Integrators

1.  **Process Sales**: When an NFT is resold, call `process-nft-sale` with the NFT ID, seller, buyer, and sale price. The contract will automatically calculate and distribute the royalties.
2.  **Query Data**: Utilize read-only functions like `get-nft-royalty` and `get-sale-info` to fetch information about NFT royalty configurations and past sales.

Deployment
----------

This contract is designed to be deployed on the Stacks blockchain. You will need a Stacks development environment (e.g., Clarity Playground, `clarity-cli`, or a web IDE like the Stacks.js console) to compile and deploy it.

Contribution
------------

I welcome contributions to RoyaltyFlow! If you have suggestions for improvements, find bugs, or would like to add new features, please feel free to:

2.  Fork the repository.

4.  Create a new branch for your feature or bug fix.
5.  Submit a pull request with a clear description of your changes.

License
-------

This project is open-sourced under the MIT License. I believe in open-source collaboration for the benefit of the Stacks ecosystem.

Related Projects
----------------

-   [Stacks.js](https://stacks.js.org/): A JavaScript library for interacting with the Stacks blockchain.
-   [Clarity Language](https://www.google.com/search?q=https://docs.stacks.co/write-smart-contracts/clarity-language): Official documentation for the Clarity smart contract language.
