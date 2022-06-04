import { ethers } from "hardhat";
import keccak256 from 'keccak256';
import { MerkleTree } from 'merkletreejs';
import { randomBytes } from 'crypto';
import { Wallet } from 'ethers';
import { expect, use } from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);

describe("Vesting tests", function() {
    it("Testin merkle root claim validation", async function() {
        const [signer] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("VestingToken");
        const Vesting = await ethers.getContractFactory("Vesting");
        const token = await Token.deploy();
        await token.deployed();

        const randomUsers = new Array(1024)
            .fill(0)
            .map(() => JSON.stringify({address: new Wallet(randomBytes(32).toString('hex')).address, tokens: 1}));

        const merkleTree = new MerkleTree(
            randomUsers.concat(JSON.stringify({ address: signer.address, tokens: 1 })),
            keccak256,
            { hashLeaves: true, sortPairs: true }
        );

        const root = merkleTree.getHexRoot();

        const vesting = await Vesting.deploy(token.address, root, 200000, 1);
        await vesting.deployed();

        const proof = merkleTree.getHexProof(keccak256(JSON.stringify({ address: signer.address, tokens: 1 })));

        expect(await vesting.checkClaim(proof)).to.equal(true);

        const claimTx = await vesting.claim(proof);

        expect(await claimTx.wait()).to.reverted;

        const wrongProof = merkleTree.getHexProof(keccak256(JSON.stringify({ address: new Wallet(randomBytes(32).toString('hex')).address, tokens: 1 })));

        expect(await vesting.checkClaim(wrongProof)).to.equal(false);
    });

    it("VestingVerify tests", async function() {
        const [user, signer] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("VestingToken");
        const Vesting = await ethers.getContractFactory("VestingVerify");
        const token = await Token.deploy();
        await token.deployed();

        const vesting = await Vesting.deploy(token.address, 200000, 1);
        await vesting.deployed();

        const nonce = new Date().getMilliseconds();

        const hash = keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint256", "uin256"], [ user.address, 1, nonce ]));

        const sign = signer.signMessage(hash);

        expect(await vesting.connect(user.address).checkClaim(signer.address, 1, nonce, sign)).to.equal(true);
    });
});