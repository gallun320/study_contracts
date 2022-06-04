import { ethers } from "hardhat";
import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';
import { randomBytes } from 'crypto';
import { Wallet } from 'ethers';

async function main() {
    const [signer] = await ethers.getSigners();

    const randomUsers = new Array(1024)
      .fill(0)
      .map(() => JSON.stringify({address: new Wallet(randomBytes(32).toString('hex')).address, tokens: 1}));

      const merkleTree = new MerkleTree(
        randomUsers.concat(JSON.stringify({ address: signer.address, tokens: 1 })),
        keccak256,
        { hashLeaves: true, sortPairs: true }
      );

    const root = merkleTree.getHexRoot();
    const proof = merkleTree.getHexProof(keccak256(JSON.stringify({ address: signer.address, tokens: 1 })));

    console.log(proof);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
