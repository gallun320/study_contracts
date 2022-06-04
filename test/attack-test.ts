import { expect } from "chai";
import { ethers } from "hardhat";
import { solidity } from "ethereum-waffle";
import InputDataDecoder from "ethereum-input-data-decoder";

const decoder = new InputDataDecoder(`${__dirname}/artifacts/build-info/1404f6fb4d939ad98a598cb019027658.json`);

chai.use(solidity);

describe("Tests for attcking on contract", function() {
    it("ReEntrency attack", async function() {
        const [owner, accountAttacker] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("TokenWithVotingValnurable");
        const Attack = await ethers.getContractFactory("TokenAttacker");

        const token = await Token.deploy(10000, 5);
        await token.deployed();
        const attack = await Attack.deploy();
        await attack.deployed();

        const transactionHash = await owner.sendTransaction({
            to: token.address,
            value: ethers.utils.parseEther("2.0"),
        });

        const provider = ethers.getDefaultProvider();
        const beforeBalance = await provider.getBalance(accountAttacker.address);

        const options = {value: ethers.utils.parseEther("0.00000000000000001")};
        const result = await attack.connect(accountAttacker).attack(token.address, options);
        await result.wait();

        const balance = await provider.getBalance(accountAttacker.address);
        expect(balance).not.eq(beforeBalance);
    });
    it("DOS attack", async function() {
        const [owner, accountAttacker] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("TokenWithVotingValnurable");
        const token = await Token.deploy(10000, 5);
        await token.deployed();
        const addresses = await ethers.getSigners();
        const halfAddresses = addresses.slice(0, (addresses.length / 2) - 1);

        const tx = await token.connect(accountAttacker.address).setBlacklist(halfAddresses);
        await tx.wait();

        expect(await token.transferFrom(accountAttacker.address, 1)).to.be.reverted;
    });
    it("Frontrunning attack", async function() {
        const [owner, accountAttacker] = await ethers.getSigners();
        const Token = await ethers.getContractFactory("TokenWithVotingValnurable");
        const token = await Token.deploy(10000, 5);
        await token.deployed();

        const provider = ethers.getDefaultProvider();

        provider.on("pending", async (txHash) => {
            const tx = await provider.getTransaction(txHash)
            if (!tx || !tx.to) return;

            const result = decoder.decodeData(tx.data);
            if(result.method == "vote") {
                const options = {value: ethers.utils.parseEther("1.0")}; 
                await token.connect(accountAttacker.address).endVoting(options);
            }
        });

        const tx = await token.connect(owner.address).vote(false);
        expect(await tx.wait()).to.be.reverted;
    });
});