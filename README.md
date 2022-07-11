# EthernautDAO CTF - Foundry edition

## What is EthernautDAO CTF

[ΞthernautDAO](https://twitter.com/EthernautDAO) is common goods DAO aimed at transforming developers into Ethereum developers.

They started releasing CTF challenges on Twitter, so how couldn't I start solving them?

## Acknowledgements

- Created by [ΞthernautDAO](https://twitter.com/EthernautDAO)
- [ΞthernautDAO Discord](discord.gg/RQ5WYDxUF3)
- [Foundry](https://github.com/gakonst/foundry)
- [Foundry Book](https://book.getfoundry.sh/)

## How to play

### Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
```

### Update Foundry

```bash
foundryup
```

### Clone repo and install dependencies

```bash
git clone git@github.com:StErMi/ethernautdao-ctf.git
cd ethernautdao-ctf
git submodule update --init --recursive
```

### Get a Goerli RPC URL to fork the network

- Go to Alchemy or Infura
- Create an account
- Get an RPC URL for Goerli

### Run a solution

```bash
# example forge test --match-contract TestCoinFlip
forge test --match-contract <testname> --fork-url <your_rpc_url> --fork-block-number <blocknumber> -vv
```

Replace the following parameters

- `<testname>` with the name of your contract's name for the test
- `<your_rpc_url>` with the RPC URL you just grabbed from Alchemy or Infura
- `<blocknumber>` with a valid Goerli block number that allow you to run the test. Usually, a block after the deployment transaction block is fine

## Disclaimer

All Solidity code, practices and patterns in this repository are DAMN VULNERABLE and for educational purposes only.

I **do not give any warranties** and **will not be liable for any loss** incurred through any use of this codebase.

**DO NOT USE IN PRODUCTION**.
