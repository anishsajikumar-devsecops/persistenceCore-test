The Dexter team is proposing the code storage for its smart contracts in a permissionless manner from a specific whitelisted team address to be approved by the Persistence governance. 

Currently, the Persistence Core-1 chain runs the wasm module in a permissioned manner to avoid code storage/instantiation related spam. Each smart contract code requires a proposal to be passed by the chain governance in this setup. Hence, the Dexter team would need to put up separate proposals for each of its smart contracts, slowing down the overall deployment and upgrade process.

To bypass this hurdle, the Dexter team explored multiple approaches. One of those options was from a recent change to the wasm module, particularly in v0.29, which gives a set of addresses the permission to upload/instantiate code to the chain without the need for individual governance proposals for each smart contract.

After careful consideration & weighing out all options, the Dexter team proposes `wasm` module configuration change in the Persistence Core-1 chain that maintains a balance between decentralisation and an efficient way for validators and delegators to support Dexter’s deployment.

As a result, the full process of deploying Dexter on the Persistence Core-1 chain would only require the following 2 proposals:

**Proposal 1**: Change wasm module parameters to `AnyOfAddresses` for `uploadAccess` and `instantiateAccess` whitelisting Dexter team’s address

**Proposal 2**: Change the instantiation config of LP Token and Pools (Weighted and Stableswap) code to allow them to be instantiated using Vault Contract.

This proposal is the first of the above two and whitelists the Dexter team's address to store and instantiate code. The second proposal will be raised subject to the first proposal being passed by the Persistence governance. 

### Governance Votes

The following items summarize the voting options and what it means for this proposal.

**YES**: You approve the proposal statements and agree to provide permission to store and instantiate code for Dexter to the following whitelisted address.
`persistence1eld9dngatavy9nqu9j0d5ratjvp2887zsnqp6x`

**NO**: The NO vote is a request for improvements or adjustments. You agree that this proposal’s motivation is valuable and that the team should create a follow-up proposal once the amendments are included.

**NO (VETO)**: You veto the entire motivation for the proposal, and the proposers will not create a follow-up proposal.

**ABSTAIN**: You are impartial to the outcome of the proposal.
